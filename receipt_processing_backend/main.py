import os
import base64
from dotenv import load_dotenv
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import re
import mimetypes
import json
from datetime import datetime
from paddleocr import PaddleOCR
from huggingface_hub import InferenceClient
import cv2 
import numpy as np 

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ENV_PATH = os.path.join(PROJECT_ROOT, '.env')

if os.path.exists(ENV_PATH):
    load_dotenv(dotenv_path=ENV_PATH)
    print(f"Loaded .env file from: {ENV_PATH}")
else:
    print(f".env file not found at: {ENV_PATH}. Please ensure it exists.")
   

# --- Configuration --- 
HUGGING_FACE_API_TOKEN = os.getenv("HUGGING_FACE_API_TOKEN")
# Ensure the model is available for serverless inference on Hugging Face
MISTRAL_MODEL_ID = "mistralai/Mistral-7B-Instruct-v0.3"

app = FastAPI(
    title="Receipt Processing API with PaddleOCR & Mistral",
    description="Processes receipts using PaddleOCR for text extraction and a Mistral LLM (via Hugging Face API) for structuring.",
    version="0.3.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SUPPORTED_IMAGE_MIMETYPES = ["image/jpeg", "image/png", "image/webp", "image/bmp"]

print("Initializing PaddleOCR...")
try:
    ocr_engine = PaddleOCR(use_textline_orientation=True, lang='en')
    print("PaddleOCR initialized successfully.")
except Exception as e:
    print(f"Error initializing PaddleOCR: {e}")
    ocr_engine = None 

# Initialize Hugging Face Inference Client
hf_client = None
if HUGGING_FACE_API_TOKEN:
    hf_client = InferenceClient(model=MISTRAL_MODEL_ID, token=HUGGING_FACE_API_TOKEN)
    print(f"Hugging Face InferenceClient initialized for model: {MISTRAL_MODEL_ID}.")
else:
    print("HUGGING_FACE_API_TOKEN not found. Hugging Face client not initialized.")

def parse_llm_json_output(llm_json_text):
    """
    Parses the JSON output from the second LLM call.
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
        elif llm_json_text.strip().startswith("```"):
             llm_json_text = llm_json_text.strip()[3:]
             if llm_json_text.strip().endswith("```"):
                llm_json_text = llm_json_text.strip()[:-3]

        raw_data = json.loads(llm_json_text)
        
        date_str = str(raw_data.get("date", ""))
        formatted_date = ""
        if date_str:
            parsed_successfully = False
            try:
                datetime.strptime(date_str, "%Y-%m-%d") 
                formatted_date = date_str
                parsed_successfully = True
            except ValueError:
                pass

            if not parsed_successfully:
                try:
                    dt_obj = datetime.strptime(date_str, "%m/%d/%Y")
                    formatted_date = dt_obj.strftime("%Y-%m-%d")
                    parsed_successfully = True
                except ValueError:
                    pass
        
            if not parsed_successfully:
                try:
                    dt_obj = datetime.strptime(date_str, "%d/%m/%Y")
                    formatted_date = dt_obj.strftime("%Y-%m-%d")
                    parsed_successfully = True
                except ValueError:
                    pass

            # Attempt 4: MM/DD/YY (Common short form with 2-digit year)
            if not parsed_successfully:
                try:
                    dt_obj = datetime.strptime(date_str, "%m/%d/%y")
                    formatted_date = dt_obj.strftime("%Y-%m-%d")
                    parsed_successfully = True
                except ValueError:
                    pass

            # Attempt 5: DD/MM/YY (Alternative short form with 2-digit year)
            if not parsed_successfully:
                try:
                    dt_obj = datetime.strptime(date_str, "%d/%m/%y")
                    formatted_date = dt_obj.strftime("%Y-%m-%d")
                    parsed_successfully = True
                except ValueError:
                    pass

            # Attempt 6: Final regex check if it looks like YYYY-MM-DD but strptime failed earlier
            if not parsed_successfully and re.match(r"^\d{4}-\d{2}-\d{2}$", date_str):
                formatted_date = date_str
                parsed_successfully = True
            
            if not parsed_successfully:
                print(f"Warning: Date '{date_str}' from LLM is not in a recognized format (YYYY-MM-DD, MM/DD/YYYY, DD/MM/YYYY, MM/DD/YY, DD/MM/YY). Leaving as is or empty.")
                formatted_date = date_str 

        return {
            "date": formatted_date,
            "merchant": str(raw_data.get("merchant", "")),
            "amount": float(raw_data.get("amount", 0.0)),
            "category": str(raw_data.get("category", "Other")),
            "is_deductible": bool(raw_data.get("is_deductible", False))
        }
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from LLM: {e}")
        print(f"Problematic JSON string: {llm_json_text}")
        return {
            "date": "", "merchant": "", "amount": 0.0,
            "category": "Other", "is_deductible": False
        }
    except Exception as e:
        print(f"Unexpected error parsing LLM JSON output: {e}. Raw data: {raw_data}")
        return {
            "date": "", "merchant": "", "amount": 0.0,
            "category": "Other", "is_deductible": False
        }

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...)):
    if not ocr_engine:
        raise HTTPException(status_code=500, detail="PaddleOCR engine not initialized. Check server logs.")
    if not hf_client:
        raise HTTPException(status_code=500, detail="Hugging Face client not initialized. Check HUGGING_FACE_API_TOKEN.")

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
        
        # Extract text from image using PaddleOCR --- 
        print("Step 1: Extracting text with PaddleOCR...")

        # Convert image bytes to NumPy array for PaddleOCR
        nparr = np.frombuffer(contents, np.uint8)
        img_np = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img_np is None:
            raise HTTPException(status_code=400, detail="Could not decode image. The file may be corrupted or in an unsupported format.")

        ocr_result = ocr_engine.predict(img_np)
        print(f"\n--- RAW PaddleOCR Result --- \n{ocr_result}\n--------------------------")
        extracted_text = ""
        lines = []

        if ocr_result and isinstance(ocr_result, list) and len(ocr_result) > 0:
            image_result = ocr_result[0]
            
            if isinstance(image_result, dict) and 'rec_texts' in image_result:
                for text_line in image_result['rec_texts']:
                    lines.append(text_line)
            # Fallback for the previously assumed structure (less likely now)
            elif isinstance(image_result, dict) and 'rec_res' in image_result:
                for text_info in image_result['rec_res']:
                    if isinstance(text_info, tuple) and len(text_info) == 2:
                        lines.append(text_info[0])
            elif isinstance(image_result, list):
                if isinstance(image_result[0], list): 
                    for line_group in image_result: 
                        if line_group and isinstance(line_group, list):
                             for line_info in line_group: 
                                if isinstance(line_info, tuple) and len(line_info) == 2 and isinstance(line_info[1], tuple) and len(line_info[1]) == 2:
                                    lines.append(line_info[1][0])
                                elif isinstance(line_info, list) and len(line_info) == 2 and isinstance(line_info[1], tuple) and len(line_info[1]) == 2:
                                     lines.append(line_info[1][0])
                elif isinstance(image_result[0], tuple) and len(image_result[0]) == 2 and isinstance(image_result[0][1], tuple):
                    for line_info in image_result: 
                        lines.append(line_info[1][0])

        extracted_text = "\n".join(lines)
        print(f"\n--- PaddleOCR Extracted Text --- \n{extracted_text}\n---------------------------------")

        if not extracted_text.strip():
            # Handle cases where OCR might not find any text
            print("Warning: PaddleOCR did not extract any text from the image.")
        # Extract structured data from the text using Mistral LLM via Hugging Face --- 
        print(f"Step 2: Sending request to Mistral LLM ('{MISTRAL_MODEL_ID}') for structured data extraction...")
        
        # --- Malaysian Tax Deduction Guidelines (Simplified Example - REPLACE with actual key points) ---
        malaysian_tax_guidelines = """
Key Malaysian Tax Deduction Guidelines for Businesses:
- Office rent, utilities (electricity, water, internet for business premises) are generally deductible.
- Staff salaries and EPF/SOCSO contributions are deductible.
- Purchase of office supplies (stationery, software subscriptions for business use) is deductible.
- Business travel expenses (flights, accommodation, meals for business trips) are deductible.
- Client entertainment specifically for business promotion may be partially deductible (e.g., 50%), subject to conditions. Personal meals are not.
- Medical expenses for employees might be deductible under certain schemes.
- Donations to approved institutions are deductible.
- Capital expenditures (e.g., purchase of machinery, office building) are claimed via capital allowances, not direct deduction against income.
- Fines and penalties are generally not deductible.
- Personal expenses (e.g., personal groceries, personal entertainment) are NOT deductible.
""" 

        text_prompt = f"""
Based on the following text extracted from a receipt, please perform the following tasks:
1. Determine the most appropriate expense category based on the primary items listed. For example, if the main item is 'spaghetti', the category should be 'Food'; if it's 'beer', the category should be 'Beverage'. If items are clearly for a specific business purpose (e.g., 'Books for research', 'Software license'), use a category that reflects that purpose (e.g., 'Books', 'Software'). If no specific item stands out or the purpose is unclear, use a general category like 'Groceries', 'Utilities', 'Transportation', 'Office Supplies', 'Travel', 'Healthcare', or 'Other'.
2. Extract the merchant name.
3. Extract the total amount.
4. Extract the date (format YYYY-MM-DD if possible, otherwise MM/DD/YYYY).

Using the Malaysian Tax Deduction Guidelines provided below, determine if the expense seems tax-deductible for business purposes (is_deductible: true/false).

Malaysian Tax Deduction Guidelines:
--- Start Guidelines ---
{malaysian_tax_guidelines}
--- End Guidelines ---

Please provide the output strictly in JSON format with the keys: "category", "merchant", "amount", "date", and "is_deductible".
Do NOT include any explanatory text or markdown before or after the JSON object.

Extracted text:
---
{extracted_text}
---

JSON Output:
"""
        
        try:
            full_prompt_for_text_generation = f"[INST] {text_prompt} [/INST]"

            response = hf_client.text_generation(
                prompt=full_prompt_for_text_generation,
                max_new_tokens=500, 
                temperature=0.1,
                do_sample=True, 
                return_full_text=False 
            )
            
            if response:
                structured_data_json_text = response
            else:
                raise HTTPException(status_code=500, detail="Mistral LLM returned an empty or invalid response.")

        except Exception as llm_e:
            print(f"Error calling Hugging Face Inference API: {llm_e}")
            raise HTTPException(status_code=503, detail=f"Error communicating with LLM service: {str(llm_e)}")

        print(f"\n--- Mistral LLM Structured JSON Output --- \n{structured_data_json_text}\n--------------------------------------- ")
        
        final_extracted_data = parse_llm_json_output(structured_data_json_text)
        print(f"--- Parsed Structured Data (PaddleOCR + Mistral) --- \n{final_extracted_data}\n-----------------------------------------")
            
        response_data = {
            "filename": file.filename,
            "ocr_text": extracted_text,
            **final_extracted_data
        }
        return JSONResponse(content=response_data)
            
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        print(f"Error processing receipt: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error processing receipt: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "Receipt Processing API (PaddleOCR + Mistral) is running.",
        "status": "PaddleOCR & Hugging Face Client Initialized" if ocr_engine and hf_client else "One or more services failed to initialize. Check logs.",
        "hugging_face_token_status": "Configured" if HUGGING_FACE_API_TOKEN else "NOT CONFIGURED - Mistral LLM will not work"
    }

if __name__ == "__main__":    
    print("\n--- Environment Configuration ---")
    print(f"HUGGING_FACE_API_TOKEN: {'Configured' if HUGGING_FACE_API_TOKEN else 'NOT CONFIGURED'}")
    print(f"MISTRAL_MODEL_ID: {MISTRAL_MODEL_ID}")
    print(f"PaddleOCR Engine: {'Initialized' if ocr_engine else 'Failed to initialize'}")
    print("--------------------------------\n")

    uvicorn.run(app, host="0.0.0.0", port=8002)