import os
import sys
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
if PROJECT_ROOT not in sys.path:
    sys.path.append(PROJECT_ROOT)

from tax_knowledge_engine.simple_retriever import TaxGuidelineRetriever

ENV_PATH = os.path.join(PROJECT_ROOT, '.env')

if os.path.exists(ENV_PATH):
    load_dotenv(dotenv_path=ENV_PATH)
    print(f"Loaded .env file from: {ENV_PATH}")
else:
    print(f".env file not found at: {ENV_PATH}. Please ensure it exists.")

# --- Configuration ---
HUGGING_FACE_API_TOKEN = os.getenv("HUGGING_FACE_API_TOKEN")
MISTRAL_MODEL_ID = "mistralai/Mistral-7B-Instruct-v0.3"

app = FastAPI(
    title="Receipt Processing API with PaddleOCR, Mistral & RAG",
    description="Processes receipts using PaddleOCR for text extraction, a Mistral LLM for structuring, and a RAG system for tax deductibility assessment based on the Malaysian Income Tax Act 1967.",
    version="0.8.0", 
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
    ocr_engine = PaddleOCR(use_angle_cls=True, lang='en')
    print("PaddleOCR initialized successfully.")
except Exception as e:
    print(f"Error initializing PaddleOCR: {e}")
    ocr_engine = None

hf_client = None
if HUGGING_FACE_API_TOKEN:
    try:
        hf_client = InferenceClient(model=MISTRAL_MODEL_ID, token=HUGGING_FACE_API_TOKEN)
        print(f"Hugging Face InferenceClient initialized for model: {MISTRAL_MODEL_ID}.")
    except Exception as e:
        print(f"Error initializing Hugging Face InferenceClient: {e}")
        hf_client = None
else:
    print("HUGGING_FACE_API_TOKEN not found. Hugging Face client not initialized.")

EXPECTED_FAISS_INDEX_DIR = os.path.join(PROJECT_ROOT, "tax_knowledge_engine", "vector_store", "faiss_index")
retriever = None
if os.path.isdir(EXPECTED_FAISS_INDEX_DIR) and os.path.exists(os.path.join(EXPECTED_FAISS_INDEX_DIR, "index.faiss")):
    try:
        retriever = TaxGuidelineRetriever()
        print(f"TaxGuidelineRetriever initialized successfully. Loading from: {EXPECTED_FAISS_INDEX_DIR}")
    except Exception as e:
        print(f"Error initializing TaxGuidelineRetriever: {e}")
        retriever = None
else:
    print(f"Vector store not found at {EXPECTED_FAISS_INDEX_DIR}. TaxGuidelineRetriever not initialized. Ensure 'document_processor.py' has run.")

def parse_llm_json_output(llm_json_text, pre_determined_category=None):
    raw_data = {}
    default_response = {
        "date": "", "merchant": "", "amount": 0.0,
        "category": pre_determined_category if pre_determined_category else "Other",
        "is_deductible": False, "deduction_type": "N/A", "deduction_details": "N/A"
    }

    try:
        match = re.search(r"```(?:json)?\s*(.*?)\s*```", llm_json_text, re.DOTALL | re.IGNORECASE)
        if match:
            cleaned_json_text = match.group(1).strip()
        else:
            cleaned_json_text = llm_json_text.strip()
        
        if not cleaned_json_text:
             print("Warning: LLM returned empty JSON content for parsing.")
             return default_response

        raw_data = json.loads(cleaned_json_text)
        
        final_category = pre_determined_category if pre_determined_category else str(raw_data.get("category", "Other"))

        date_str = str(raw_data.get("date", "")).strip()
        formatted_date = default_response["date"]
        if date_str and date_str.lower() not in ["not provided", "not specified", "n/a", ""]:
            parsed_successfully = False
            date_formats_to_try = [
                "%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y", "%m-%d-%Y", "%d-%m-%Y",
                "%Y/%m/%d", "%m/%d/%y", "%d/%m/%y", "%d %b %Y", "%d %B %Y",
                "%b %d, %Y", "%B %d, %Y", "%Y%m%d", "%d.%m.%Y",
                "%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S",
            ]
            for fmt in date_formats_to_try:
                try:
                    dt_obj = datetime.strptime(date_str, fmt)
                    formatted_date = dt_obj.strftime("%Y-%m-%d")
                    parsed_successfully = True
                    break
                except ValueError:
                    continue
            if not parsed_successfully:
                print(f"Warning: Date '{date_str}' from LLM is not in a recognized format. Leaving as original string.")
                formatted_date = date_str

        amount_val = raw_data.get("amount")
        parsed_amount = default_response["amount"]
        if isinstance(amount_val, (int, float)):
            parsed_amount = float(amount_val)
        elif isinstance(amount_val, str):
            amount_str_cleaned = amount_val.lower().strip()
            if amount_str_cleaned not in ["not provided", "not specified", "n/a", ""]:
                try:
                    cleaned_amount_str_for_float = re.sub(r"[^\d.]", "", amount_str_cleaned)
                    if cleaned_amount_str_for_float and cleaned_amount_str_for_float != ".":
                        parsed_amount = float(cleaned_amount_str_for_float)
                    else:
                        print(f"Warning: Amount string '{amount_val}' became empty or invalid for float conversion after cleaning.")
                except ValueError:
                    print(f"Warning: Could not convert amount string '{amount_val}' to float.")
        elif amount_val is not None:
             print(f"Warning: Amount '{amount_val}' is of unexpected type {type(amount_val)}. Using default.")

        is_deductible_val = raw_data.get("is_deductible", default_response["is_deductible"])
        parsed_is_deductible = default_response["is_deductible"]
        if isinstance(is_deductible_val, bool):
            parsed_is_deductible = is_deductible_val
        elif isinstance(is_deductible_val, str):
            if is_deductible_val.lower() == "true":
                parsed_is_deductible = True
            elif is_deductible_val.lower() == "false":
                parsed_is_deductible = False
            else:
                print(f"Warning: 'is_deductible' string value '{is_deductible_val}' is not 'true' or 'false'. Defaulting to False.")
        
        return {
            "date": formatted_date,
            "merchant": str(raw_data.get("merchant", default_response["merchant"])).strip(),
            "amount": parsed_amount,
            "category": final_category,
            "is_deductible": parsed_is_deductible,
            "deduction_type": str(raw_data.get("deduction_type", default_response["deduction_type"])).strip(),
            "deduction_details": str(raw_data.get("deduction_details", default_response["deduction_details"])).strip()
        }
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from LLM: {e}")
        print(f"Problematic JSON string: >>>{llm_json_text}<<<")
        return default_response
    except Exception as e:
        print(f"Unexpected error parsing LLM JSON output: {e}. Raw data: {raw_data if raw_data else 'not loaded'}")
        return default_response

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...)):
    if not ocr_engine:
        raise HTTPException(status_code=500, detail="PaddleOCR engine not initialized. Check server logs.")
    if not hf_client:
        raise HTTPException(status_code=500, detail="Hugging Face client not initialized. Check HUGGING_FACE_API_TOKEN.")
    if not retriever:
        raise HTTPException(status_code=500, detail="TaxGuidelineRetriever not initialized. Check vector store path and server logs.")

    file_content_type = file.content_type
    if file_content_type not in SUPPORTED_IMAGE_MIMETYPES:
        guessed_type, _ = mimetypes.guess_type(file.filename) if file.filename else (None, None)
        if guessed_type in SUPPORTED_IMAGE_MIMETYPES:
            file_content_type = guessed_type
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file_content_type or guessed_type or 'unknown'}. Please upload a JPG, PNG, WEBP, or BMP image."
            )

    extracted_text = "" 
    extracted_category_from_llm = "Other" 
    llm_response_data = {} 

    try:
        contents = await file.read()
        
        # --- Step 1: Extracting text with PaddleOCR ---
        print("Step 1: Extracting text with PaddleOCR...")
        nparr = np.frombuffer(contents, np.uint8)
        img_np = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img_np is None:
            raise HTTPException(status_code=400, detail="Could not decode image. File might be corrupted or an unsupported format.")

        ocr_result_raw = ocr_engine.predict(img_np)
        
        lines = []
        if ocr_result_raw and isinstance(ocr_result_raw, list) and len(ocr_result_raw) > 0:
            image_data_level = ocr_result_raw[0] 
            
            if isinstance(image_data_level, list) and \
               all(isinstance(line_item, list) and len(line_item) == 2 and isinstance(line_item[1], tuple) and len(line_item[1]) == 2 for line_item in image_data_level if line_item):
                for line_item in image_data_level:
                    if line_item: lines.append(line_item[1][0])
            elif isinstance(image_data_level, dict) and 'rec_texts' in image_data_level: 
                if isinstance(image_data_level['rec_texts'], list):
                    lines.extend(image_data_level['rec_texts'])
            elif isinstance(image_data_level, dict) and 'rec_res' in image_data_level: 
                for text_info_outer in image_data_level['rec_res']:
                    if isinstance(text_info_outer, tuple) and len(text_info_outer) > 0 and isinstance(text_info_outer[0], str):
                        lines.append(text_info_outer[0])
            else: 
                try:
                    for item in image_data_level: 
                        if isinstance(item, str):
                            lines.append(item)
                        elif isinstance(item, (list, tuple)) and len(item) > 0 and isinstance(item[0], str):
                             lines.append(item[0]) 
                        elif isinstance(item, (list, tuple)) and len(item) > 1 and isinstance(item[1], str):
                             lines.append(item[1]) 
                except TypeError: 
                    print(f"Warning: Unexpected OCR result structure from predict(): {type(image_data_level)}")

        extracted_text = "\n".join(lines)
        print(f"\n--- PaddleOCR Extracted Text --- \n'{extracted_text}'\n---------------------------------")

        if not extracted_text.strip():
            print("Warning: PaddleOCR did not extract any meaningful text.")
            return JSONResponse(content={
                "filename": file.filename, "ocr_text": extracted_text,
                "date": "", "merchant": "", "amount": 0.0, "category": "Other",
                "is_deductible": False, "deduction_type": "N/A",
                "deduction_details": "OCR failed to extract text or text was empty."
            })

        # --- Step 2a: First LLM call to determine category ---
        print(f"Step 2a: Sending request to Mistral LLM ('{MISTRAL_MODEL_ID}') for category extraction...")
        category_prompt_text = f"""
        Based on the following text extracted from a receipt, determine the most appropriate primary expense category.
        Focus on the main items or services purchased.
        Consider categories like: 'Books & Publications', 'Computer & IT Equipment', 'Software & Subscriptions', 'Groceries', 'Meals & Entertainment', 'Utilities (Electricity, Water, Internet)', 'Transportation (Fuel, Parking, Public Transport)', 'Office Supplies & Stationery', 'Travel (Flights, Accommodation)', 'Healthcare & Medical', 'Professional Fees (Legal, Accounting)', 'Education & Training', 'Charitable Contributions', 'Repairs & Maintenance', 'Rentals', 'Financial Costs (Bank Charges)', 'Insurance', 'Gifts & Donations (Non-charitable)', 'Personal Care', 'Clothing & Apparel', 'Home & Furnishing', 'Other'.
        If the text is unclear, very short, or nonsensical, output 'Other'.
        Provide only the category name as a single string.

        Extracted text:
        ---
        {extracted_text}
        ---
        
        Category:
        """
        
        extracted_category_from_llm = "Other" 
        try:
            category_prompt_full = f"[INST] {category_prompt_text.strip()} [/INST]"
            category_response_raw = hf_client.text_generation(
                prompt=category_prompt_full, max_new_tokens=30, 
                temperature=0.1, do_sample=False, return_full_text=False
            )
            category_response = category_response_raw.strip().replace('"', '') if category_response_raw else ""
            
            if category_response:
                extracted_category_from_llm = category_response
            else:
                 print("Warning: LLM returned an empty category. Defaulting to 'Other'.")
            print(f"--- LLM Extracted Category: {extracted_category_from_llm} ---")

        except Exception as cat_llm_e:
            print(f"Error calling Hugging Face Inference API for category extraction: {cat_llm_e}")
            print("Warning: Defaulting to category 'Other' due to LLM error for category extraction.")
        
        # --- Step 2b: Formulate RAG query using the extracted category ---
        print(f"Step 2b: Formulating RAG query with category: {extracted_category_from_llm}...")
        
        if extracted_category_from_llm.lower() == "other" or not extracted_category_from_llm:
            rag_query = f"General tax deductibility guidelines for personal or business expenses in Malaysia under Income Tax Act 1967, for items such as: {extracted_text[:100]}"
        else:
            rag_query = f"Tax deductibility guidelines for '{extracted_category_from_llm}' expenses for individuals or businesses in Malaysia under the Income Tax Act 1967."

        # --- Step 2c: Retrieve relevant tax guidelines ---
        print(f"Step 2c: Retrieving tax guidelines with RAG query: '{rag_query}'...")
        dynamic_malaysian_tax_guidelines = "No specific guidelines retrieved from the Income Tax Act 1967. The LLM should indicate if deductibility cannot be determined based on provided guidelines."
        try:
            if retriever:
                relevant_guidelines = await retriever.search_guidelines(rag_query, top_k=3) 
                if relevant_guidelines and not any("Error: Vector store not available" in guideline for guideline in relevant_guidelines):
                    dynamic_malaysian_tax_guidelines = "\n\n".join(relevant_guidelines) 
                else:
                    dynamic_malaysian_tax_guidelines = f"No specific guidelines found for the category '{extracted_category_from_llm}' in the Income Tax Act 1967. The LLM should indicate if deductibility cannot be determined from these guidelines."
                print(f"\n--- Retrieved Tax Guidelines for RAG ---\n{dynamic_malaysian_tax_guidelines}\n-----------------------------------------")
            else:
                print("Warning: TaxGuidelineRetriever was not initialized. Using fallback guidelines message.")
        except Exception as e:
            print(f"Error retrieving guidelines: {e}")
        
        # --- Step 3: Second LLM call for full structured data extraction and deductibility ---
        print(f"Step 3: Sending request to Mistral LLM ('{MISTRAL_MODEL_ID}') for full structured data extraction and deductibility assessment...")
        
        text_prompt_final = f"""
        You are an AI assistant processing a receipt.
        The expense category for this receipt has been pre-determined as: '{extracted_category_from_llm}'.

        From the "Extracted text" of the receipt provided below, please:
        1. Extract the merchant name (string, or "N/A" if not found).
        2. Extract the final total amount payable, often labeled as 'Gross Amount', 'Total', or 'Grand Total' (float, or 0.0 if not found/parsable).
        3. Extract the date (string, format as<y_bin_46>-MM-DD if possible; otherwise, use original format or "N/A" if not found).

        Then, using EXCLUSIVELY the "Malaysian Tax Deduction Guidelines (from the Income Tax Act 1967)" provided below:
        a. Determine if an expense of category '{extracted_category_from_llm}' is potentially tax-deductible under these specific guidelines (is_deductible: true or false).
        b. If deductible, specify if it's generally considered a 'personal relief', 'business expense', or 'capital allowance for business' based on the provided guidelines (deduction_type: "personal relief", "business expense", "capital allowance for business", "N/A" if not deductible, or "unclear from guidelines" if guidelines are ambiguous on type).
        c. Briefly state the main conditions, limits, or relevant section (e.g., "Section 46(1)(p) for lifestyle relief up to RM2500 for personal computers" or "Schedule 3 for plant and machinery used in business") for the deduction if explicitly mentioned in the provided guidelines (deduction_details: "string" or "N/A"). If not deductible or no specific details are found in the provided guidelines, use "Not deductible based on provided guidelines" or "No specific conditions/details found in provided guidelines."

        IMPORTANT: Base your tax deductibility assessment (is_deductible, deduction_type, deduction_details) *solely and strictly* on the "Malaysian Tax Deduction Guidelines (from the Income Tax Act 1967)" provided below. Do NOT use any external knowledge or general assumptions about tax laws. If the provided guidelines are insufficient, unclear, or do not cover this category for deductibility, then 'is_deductible' should be false, and 'deduction_details' should reflect this lack of information from the provided guidelines.

        Malaysian Tax Deduction Guidelines (from the Income Tax Act 1967):
        --- Start Guidelines ---
        {dynamic_malaysian_tax_guidelines}
        --- End Guidelines ---

        Extracted text:
        ---
        {extracted_text}
        ---

        Provide the output STRICTLY in JSON format with ONLY the following keys: "category", "merchant", "amount", "date", "is_deductible", "deduction_type", "deduction_details".
        The "category" in the JSON output MUST be "{extracted_category_from_llm}".
        The "amount" MUST be a float (e.g., 123.45 or 0.0 if not found/parsable), representing the final total/gross amount.
        The "is_deductible" MUST be a boolean (true or false).
        Do NOT include any explanatory text, apologies, or markdown code fences (```json ... ```) before or after the JSON object itself. Ensure the JSON is valid.

        JSON Output:
        """
        
        structured_data_json_text = ""
        try:
            full_prompt_for_text_generation = f"[INST] {text_prompt_final.strip()} [/INST]"
            response_raw = hf_client.text_generation(
                prompt=full_prompt_for_text_generation, max_new_tokens=600, 
                temperature=0.05, do_sample=False, return_full_text=False
            )
            structured_data_json_text = response_raw.strip() if response_raw else ""
            
            if not structured_data_json_text:
                print("Warning: Mistral LLM returned an empty response for full extraction.")
                llm_response_data = parse_llm_json_output("{}", pre_determined_category=extracted_category_from_llm)
            else:
                llm_response_data = parse_llm_json_output(structured_data_json_text, pre_determined_category=extracted_category_from_llm)

        except Exception as llm_e:
            print(f"Error calling Hugging Face Inference API for full extraction: {llm_e}")
            llm_response_data = parse_llm_json_output("{}", pre_determined_category=extracted_category_from_llm)

        print(f"\n--- Mistral LLM Structured JSON Output (Raw) --- \n{structured_data_json_text}\n--------------------------------------- ")
        print(f"--- Parsed LLM Data (After RAG) --- \n{llm_response_data}\n-----------------------------------------")
                
        response_data = {
            "filename": file.filename,
            "ocr_text": extracted_text,
            **llm_response_data
        }
        return JSONResponse(content=response_data)
            
    except HTTPException as http_exc:
        raise http_exc 
    except Exception as e:
        print(f"Critical error processing receipt: {e}")
        import traceback
        traceback.print_exc()
        default_error_response = {
            "filename": file.filename if file and hasattr(file, 'filename') else "N/A",
            "ocr_text": extracted_text,
            "date": "", "merchant": "", "amount": 0.0,
            "category": extracted_category_from_llm,
            "is_deductible": False,
            "deduction_type": "N/A",
            "deduction_details": f"Internal server error: {str(e)}"
        }
        return JSONResponse(status_code=500, content=default_error_response)

@app.get("/")
async def root():
    return {
        "message": "Receipt Processing API (PaddleOCR + Mistral + RAG) is running.",
        "ocr_engine_status": "Initialized" if ocr_engine else "Failed to initialize",
        "hf_client_status": "Initialized" if hf_client else "Failed to initialize (Check HUGGING_FACE_API_TOKEN)",
        "retriever_status": "Initialized" if retriever else "Failed to initialize (Check vector store)"
    }

if __name__ == "__main__":    
    print("\n--- Environment Configuration ---")
    print(f"HUGGING_FACE_API_TOKEN: {'Configured' if HUGGING_FACE_API_TOKEN else 'NOT CONFIGURED'}")
    print(f"MISTRAL_MODEL_ID: {MISTRAL_MODEL_ID}")
    print(f"PaddleOCR Engine: {'Initialized' if ocr_engine else 'Failed to initialize'}")
    print(f"TaxGuidelineRetriever: {'Initialized' if retriever else 'Failed to initialize'}")
    print("--------------------------------\n")

    uvicorn.run(app, host="0.0.0.0", port=8002)