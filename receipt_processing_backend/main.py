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

load_dotenv()

# --- Configuration ---
API_KEY = os.getenv("DASHSCOPE_API_KEY")
BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
MODEL_NAME_VL = "qwen-vl-plus"  # For image and initial text extraction
MODEL_NAME_TEXT = "qwen-turbo" # For structured data extraction from text (can also be qwen-vl-plus)

app = FastAPI(
    title="Receipt Processing API",
    description="Processes receipts using Alibaba Cloud OCR and LLM structuring.",
    version="0.2.0", 
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SUPPORTED_IMAGE_MIMETYPES = ["image/jpeg", "image/png", "image/webp", "image/bmp"]

def parse_llm_json_output(llm_json_text):
    """
    Parses the JSON output from the second LLM call.
    Handles potential markdown code block ```json ... ```
    """
    try:
        # Remove markdown code block fences if present
        if llm_json_text.strip().startswith("```json"):
            llm_json_text = llm_json_text.strip()[7:] 
            if llm_json_text.strip().endswith("```"):
                llm_json_text = llm_json_text.strip()[:-3] 

        data = json.loads(llm_json_text)
        # Validate and sanitize data
        return {
            "date": str(data.get("date", "")),
            "merchant": str(data.get("merchant", "")),
            "amount": float(data.get("amount", 0.0)),
            "category": str(data.get("category", "Other")),
            "is_deductible": bool(data.get("is_deductible", False))
        }
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from LLM: {e}")
        print(f"Problematic JSON string: {llm_json_text}")
        # Return default structure on error
        return {
            "date": "", "merchant": "", "amount": 0.0,
            "category": "Other", "is_deductible": False
        }
    except Exception as e:
        print(f"Unexpected error parsing LLM JSON output: {e}")
        return {
            "date": "", "merchant": "", "amount": 0.0,
            "category": "Other", "is_deductible": False
        }

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...)):
    if not API_KEY:
        print("API key not configured. Please set DASHSCOPE_API_KEY env var.")
        raise HTTPException(status_code=500, detail="API key not configured.")

    file_content_type = file.content_type
    if file_content_type not in SUPPORTED_IMAGE_MIMETYPES:
        guessed_type = None
        if file.filename:
            guessed_type, _ = mimetypes.guess_type(file.filename)
            if guessed_type in SUPPORTED_IMAGE_MIMETYPES:
                file_content_type = guessed_type
            else:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unsupported file type: {file_content_type or guessed_type or 'unknown'}. Please upload a JPG, PNG, WEBP, or BMP image."
                )
        else: 
             raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file_content_type or 'unknown'}. Please upload a JPG, PNG, WEBP, or BMP image."
            )

    try:
        contents = await file.read()
        image_b64 = base64.b64encode(contents).decode('utf-8')
        
        client = OpenAI(api_key=API_KEY, base_url=BASE_URL)
        
        # --- Step 1: Extract text from image using Vision LLM ---
        print(f"Step 1: Sending request to Vision LLM ('{MODEL_NAME_VL}') for initial text extraction...")
        vision_messages = [
            {
                "role": "system",
                "content": "You are an OCR assistant. Extract all text from the receipt image. Organize the extracted information clearly, detailing items, prices, merchant information, date, and any summary totals."
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Extract all information from this receipt."},
                    {"type": "image_url", "image_url": {"url": f"data:{file_content_type};base64,{image_b64}"}}
                ]
            }
        ]
        
        completion_vision = client.chat.completions.create(model=MODEL_NAME_VL, messages=vision_messages)
        
        if not (completion_vision.choices and completion_vision.choices[0].message and completion_vision.choices[0].message.content):
            raise HTTPException(status_code=500, detail="Vision model returned an empty or invalid response.")
        
        extracted_text_from_vision = completion_vision.choices[0].message.content
        print(f"\n--- LLM Vision Extracted Text --- \n{extracted_text_from_vision}\n---------------------------------")

        # --- Step 2: Extract structured data from the text using another LLM call ---
        print(f"Step 2: Sending request to Text LLM ('{MODEL_NAME_TEXT}') for structured data extraction...")
        
        # Ensure the prompt clearly asks for JSON output.
        text_prompt = f"""
Based on the following text extracted from a receipt, please extract the specified information and provide it strictly in JSON format.
The JSON object should have these exact keys: "date" (string, format MM/DD/YYYY or YYYY-MM-DD), "merchant" (string), "amount" (float, the final total amount paid), "category" (string, e.g., "Food", "Office Supplies", "Travel"), and "is_deductible" (boolean, true if the expense seems tax-deductible for business purposes, otherwise false).

Extracted text:
---
{extracted_text_from_vision}
---

JSON Output:
"""
        
        text_messages = [
            {"role": "system", "content": "You are an expert data extraction assistant. Your task is to extract specific fields from the provided text and return them ONLY as a valid JSON object."},
            {"role": "user", "content": text_prompt}
        ]
        
        completion_text = client.chat.completions.create(model=MODEL_NAME_TEXT, messages=text_messages)

        if not (completion_text.choices and completion_text.choices[0].message and completion_text.choices[0].message.content):
            raise HTTPException(status_code=500, detail="Text structuring model returned an empty or invalid response.")

        structured_data_json_text = completion_text.choices[0].message.content
        print(f"\n--- LLM Text Structured JSON Output --- \n{structured_data_json_text}\n---------------------------------------")
        
        # Parse the JSON output from the second LLM
        final_extracted_data = parse_llm_json_output(structured_data_json_text)
        print(f"--- Parsed Structured Data (2-step LLM) --- \n{final_extracted_data}\n-----------------------------------------")
            
        response_data = {
            "filename": file.filename,
            "ocr_text": extracted_text_from_vision, # Original OCR text
            **final_extracted_data # Structured data from 2nd LLM
        }
        return JSONResponse(content=response_data)
            
    except Exception as e:
        print(f"Error processing receipt: {e}")
        error_message = str(e)
        if "401" in error_message:
            raise HTTPException(status_code=401, detail="Authentication failed. Please verify your API key.")
        else:
            raise HTTPException(status_code=500, detail=f"Error processing receipt: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "Receipt Processing API is running. Use the /process-receipt endpoint to upload receipts.",
        "status": "API keys configured" if API_KEY else "Missing API keys - please set environment variables"
    }

if __name__ == "__main__":    
    print("\n--- Environment Configuration ---")
    print(f"DASHSCOPE_API_KEY: {'Configured' if API_KEY else 'NOT CONFIGURED'}")
    print(f"BASE_URL: {BASE_URL}")
    print(f"MODEL_NAME_VL (Vision): {MODEL_NAME_VL}")
    print(f"MODEL_NAME_TEXT (Text Structuring): {MODEL_NAME_TEXT}")
    print("--------------------------------\n")

    uvicorn.run(app, host="0.0.0.0", port=8001)