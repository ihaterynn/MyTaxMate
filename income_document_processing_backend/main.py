import os
import base64
from dotenv import load_dotenv
from openai import OpenAI
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import re
import mimetypes
import json 
from datetime import datetime 

load_dotenv()

# --- Configuration ---
API_KEY = os.getenv("DASHSCOPE_API_KEY")
BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
MODEL_NAME_VL = "qwen-vl-plus"  # For image and initial text extraction
MODEL_NAME_TEXT = "qwen-turbo" # For structured data extraction from text (can also be qwen-vl-plus)

app = FastAPI(
    title="Income Document Processing API",
    description="Processes income documents (invoices, payslips, etc.) using Alibaba Cloud OCR and LLM structuring.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SUPPORTED_IMAGE_MIMETYPES = ["image/jpeg", "image/png", "image/webp", "image/bmp", "application/pdf"] # Added PDF

def parse_llm_json_output(llm_json_text: str):
    """
    Parses the JSON output from the second LLM call for income documents.
    Handles potential markdown code block ```json ... ```
    Ensures date is in YYYY-MM-DD format.
    """
    raw_data = {}
    try:
        # Remove markdown code block fences if present
        if llm_json_text.strip().startswith("```json"):
            llm_json_text = llm_json_text.strip()[7:]
            if llm_json_text.strip().endswith("```"):
                llm_json_text = llm_json_text.strip()[:-3]

        raw_data = json.loads(llm_json_text)
        
        # Date formatting
        date_str = str(raw_data.get("date", ""))
        formatted_date = ""
        if date_str:
            try:
                # Attempt to parse common date formats
                common_formats = ["%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d", 
                                  "%m-%d-%Y", "%d-%m-%Y", "%Y-%d-%m", # Added YYYY-DD-MM
                                  "%b %d, %Y", "%d %b %Y",
                                  "%B %d, %Y", "%d %B %Y",
                                  "%Y%m%d"] # Added YYYYMMDD
                parsed = False
                for fmt in common_formats:
                    try:
                        dt_obj = datetime.strptime(date_str, fmt)
                        formatted_date = dt_obj.strftime("%Y-%m-%d")
                        parsed = True
                        break
                    except ValueError:
                        continue
                if not parsed and re.match(r"^\\d{4}-\\d{2}-\\d{2}$", date_str): # Already YYYY-MM-DD
                    formatted_date = date_str
                elif not parsed:
                    # Try to infer if it's a less common but valid date string the LLM might produce
                    # This part can be expanded with more complex date inference if needed
                    print(f"Warning: Date '{date_str}' from LLM could not be parsed with common formats. Leaving as is or empty.")
                    formatted_date = date_str # Or set to "" if strict YYYY-MM-DD is required

            except Exception as date_e:
                print(f"Error parsing date string '{date_str}': {date_e}")
                formatted_date = date_str # Fallback to original string if complex parsing fails

        return {
            "date": formatted_date,
            "source": str(raw_data.get("source", "")), # e.g., Client Name, Employer
            "amount": float(raw_data.get("amount", 0.0)),
            "type": str(raw_data.get("type", "Other Income")), # e.g., Salary, Freelance, Sales
            "description": str(raw_data.get("description", "")), # Optional
            "document_reference": str(raw_data.get("document_reference", "")) # Optional, e.g., Invoice ID
        }
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from LLM: {e}")
        print(f"Problematic JSON string: {llm_json_text}")
        return {
            "date": "", "source": "", "amount": 0.0,
            "type": "Other Income", "description": "", "document_reference": ""
        }
    except Exception as e:
        print(f"Unexpected error parsing LLM JSON output: {e}. Raw data: {raw_data}")
        return {
            "date": "", "source": "", "amount": 0.0,
            "type": "Other Income", "description": "", "document_reference": ""
        }

@app.post("/process-income-document")
async def process_income_document(file: UploadFile = File(...)):
    if not API_KEY:
        print("API key not configured. Please set DASHSCOPE_API_KEY env var.")
        raise HTTPException(status_code=500, detail="API key not configured.")

    file_content_type = file.content_type
    # Basic validation for PDFs and images
    if not (file_content_type in SUPPORTED_IMAGE_MIMETYPES or (file.filename and file.filename.lower().endswith('.pdf'))):
        guessed_type, _ = mimetypes.guess_type(file.filename) if file.filename else (None, None)
        if not (guessed_type in SUPPORTED_IMAGE_MIMETYPES): # Check if guessed type is supported
             raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file_content_type or guessed_type or 'unknown'}. Please upload a JPG, PNG, WEBP, BMP image, or a PDF document."
            )
        file_content_type = guessed_type # Trust guessed type if it's supported and original was not

    try:
        contents = await file.read()
        image_b64 = base64.b64encode(contents).decode('utf-8')
        
        client = OpenAI(api_key=API_KEY, base_url=BASE_URL)
        
        # --- Step 1: Extract text from document image/pdf using Vision LLM ---
        print(f"Step 1: Sending request to Vision LLM ('{MODEL_NAME_VL}') for initial text extraction from income document...")
        
        vision_user_prompt_text = "Extract all relevant text from this income document (e.g., invoice, payslip, bank statement, payment confirmation, sales receipt). Focus on details like names, dates, amounts, services or goods provided, payment terms, and any reference numbers."
        
        vision_messages = [
            {
                "role": "system",
                "content": "You are an OCR assistant specialized in extracting text from various financial documents. Organize the extracted information clearly."
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": vision_user_prompt_text},
                    {"type": "image_url", "image_url": {"url": f"data:{file_content_type};base64,{image_b64}"}}
                ]
            }
        ]
        
        completion_vision = client.chat.completions.create(model=MODEL_NAME_VL, messages=vision_messages, timeout=85.0) 
        
        if not (completion_vision.choices and completion_vision.choices[0].message and completion_vision.choices[0].message.content):
            raise HTTPException(status_code=500, detail="Vision model returned an empty or invalid response for income document.")
        
        extracted_text_from_vision = completion_vision.choices[0].message.content
        print(f"\\n--- LLM Vision Extracted Text (Income Document) --- \\n{extracted_text_from_vision}\\n---------------------------------")

        # --- Step 2: Extract structured data from the text using another LLM call ---
        print(f"Step 2: Sending request to Text LLM ('{MODEL_NAME_TEXT}') for structured income data extraction...")
        
        text_prompt = f"""
Based on the following text extracted from an income document, please extract the specified information and provide it strictly in JSON format.
The JSON object should have these exact keys: 
- "date" (string, format YYYY-MM-DD ONLY. If multiple dates, use the primary income date like invoice date, payment received date, or payslip period end date.)
- "source" (string, the name of the client, employer, platform, or payer who provided the income. E.g., "Acme Corp", "John Doe", "Upwork", "Google AdSense")
- "amount" (float, the final total income amount received or invoiced. This should be the net amount if applicable, or gross if net is not specified.)
- "type" (string, categorize the income. Examples: "Salary", "Freelance Project", "Sales Revenue", "Consulting Fee", "Dividend", "Rental Income", "Interest Income", "Royalty", "Commission", "Government Benefit", "Other Income")
- "description" (string, a brief description of the income, service provided, product sold, or nature of payment. E.g., "Payment for web design services", "Monthly Salary - May 2025", "Sales of Product X", "Interest on savings account". Optional, use empty string if not clear.)
- "document_reference" (string, any reference number like Invoice ID, Payslip ID, Transaction ID, Contract Number, or Cheque Number. Optional, use empty string if not found.)

Extracted text:
---
{extracted_text_from_vision}
---

JSON Output (ensure valid JSON, do not add any text before or after the JSON object itself):
"""
        
        text_messages = [
            {"role": "system", "content": "You are an expert data extraction assistant. Your task is to extract specific fields from the provided text and return them ONLY as a valid JSON object according to the user's specified schema."},
            {"role": "user", "content": text_prompt}
        ]
        
        completion_text = client.chat.completions.create(model=MODEL_NAME_TEXT, messages=text_messages, timeout=85.0)

        if not (completion_text.choices and completion_text.choices[0].message and completion_text.choices[0].message.content):
            raise HTTPException(status_code=500, detail="Text structuring model returned an empty or invalid response for income data.")

        structured_data_json_text = completion_text.choices[0].message.content
        print(f"\n--- LLM Text Structured JSON Output (Income) --- \n{structured_data_json_text}\n---------------------------------------")
        
        final_extracted_data = parse_llm_json_output(structured_data_json_text)
        print(f"--- Parsed Structured Income Data --- \n{final_extracted_data}\n-----------------------------------------")
            
        response_data = {
            "filename": file.filename,
            "ocr_text": extracted_text_from_vision,
            **final_extracted_data
        }
        return JSONResponse(content=response_data)
            
    except Exception as e:
        print(f"Error processing income document: {e}")
        error_message = str(e)
        if "401" in error_message: 
            raise HTTPException(status_code=401, detail="Authentication failed. Please verify your API key for DashScope.")
        raise HTTPException(status_code=500, detail=f"Error processing income document: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "Income Document Processing API is running. Use the /process-income-document endpoint to upload documents.",
        "status": "API keys configured" if API_KEY else "Missing API keys - please set DASHSCOPE_API_KEY environment variable"
    }

if __name__ == "__main__":    
    print("\\n--- Income Document Processing Backend Configuration ---")
    print(f"DASHSCOPE_API_KEY: {'Configured' if API_KEY else 'NOT CONFIGURED - Please set this environment variable!'}")
    print(f"BASE_URL: {BASE_URL}")
    print(f"MODEL_NAME_VL (Vision): {MODEL_NAME_VL}")
    print(f"MODEL_NAME_TEXT (Text Structuring): {MODEL_NAME_TEXT}")
    print("----------------------------------------------------\\n")

    uvicorn.run(app, host="0.0.0.0", port=8003)