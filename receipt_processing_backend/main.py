import os
import base64
from dotenv import load_dotenv  
from openai import OpenAI
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import re
import mimetypes # Add this import

# Load environment variables from .env file
load_dotenv()  # Add this line to load variables from .env

# --- Configuration ---
# Using the exact same approach as your working code
API_KEY = os.getenv("DASHSCOPE_API_KEY")
BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1" # Changed to -intl endpoint
MODEL_NAME = "qwen-vl-plus"  # Using a less expensive model

app = FastAPI(
    title="Receipt Processing API",
    description="Processes receipts using Alibaba Cloud OCR.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SUPPORTED_IMAGE_MIMETYPES = ["image/jpeg", "image/png", "image/webp", "image/bmp"]

def extract_receipt_data_from_text(text):
    """
    Extract structured data from OCR text
    """
    # Default extracted data
    extracted_data = {
        "date": "",
        "merchant": "",
        "amount": 0.0,
        "category": "Other",
        "is_deductible": False
    }
    
    if not text:
        return extracted_data
    
    try:
        # Look for structured output sections
        date_section = re.search(r'Date(?:\s+of\s+purchase)?[:\s]+(.+)', text, re.IGNORECASE)
        merchant_section = re.search(r'Merchant(?:/store)?(?:\s+name)?[:\s]+(.+)', text, re.IGNORECASE)
        amount_section = re.search(r'Total(?:\s+amount)?[:\s]+([^a-zA-Z\n]+)', text, re.IGNORECASE)
        category_section = re.search(r'Category[:\s]+(.+)', text, re.IGNORECASE)
        deductible_section = re.search(r'(?:tax\s+)?deductible[?]?[:\s]+(\w+)', text, re.IGNORECASE)
        
        # Extract date
        if date_section:
            extracted_data["date"] = date_section.group(1).strip()
        
        # Extract merchant
        if merchant_section:
            extracted_data["merchant"] = merchant_section.group(1).strip()
        
        # Extract amount
        if amount_section:
            amount_text = amount_section.group(1).strip()
            # Remove currency symbols and convert to float
            amount_matches = re.findall(r'\$?(\d+(?:[.,]\d+)?)', amount_text)
            if amount_matches:
                try:
                    # Handle comma as decimal separator if needed
                    amount_str = amount_matches[-1].replace(',', '.')
                    extracted_data["amount"] = float(amount_str)
                except ValueError:
                    pass
        
        # Extract category
        if category_section:
            category = category_section.group(1).strip()
            extracted_data["category"] = category.title()
        
        # Extract tax deductible status
        if deductible_section:
            deductible_text = deductible_section.group(1).lower().strip()
            if re.search(r'yes|likely|probably|true', deductible_text, re.IGNORECASE):
                extracted_data["is_deductible"] = True
        
    except Exception as e:
        print(f"Error extracting receipt data: {e}")
    
    return extracted_data

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...)):
    """
    Accepts a receipt image, processes it with Qwen-VL, and returns the extracted information.
    """
    if not API_KEY:
        print("API key not configured. Please set DASHSCOPE_API_KEY env var.")
        raise HTTPException(status_code=500, detail="API key not configured.")

    file_content_type = file.content_type
    if file_content_type not in SUPPORTED_IMAGE_MIMETYPES:
        # Try to infer from filename if content_type is generic or missing
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
        else: # No filename and no supported content_type
             raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {file_content_type or 'unknown'}. Please upload a JPG, PNG, WEBP, or BMP image."
            )

    try:
        # Read the image file
        contents = await file.read()
        image_b64 = base64.b64encode(contents).decode('utf-8')
        
        # Initialize OpenAI client exactly like your working example
        client = OpenAI(
            api_key=API_KEY,
            base_url=BASE_URL,
        )
        
        # Create the messages payload exactly like your successful code
        messages = [
            {
                "role": "system",
                "content": "You are an OCR assistant that accurately extracts text from receipt images. Extract all text from the receipt and organize the information to identify the date, merchant name, total amount, and categorize the expense."
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        # Simplified prompt
                        "text": "Extract information from this receipt: date, merchant, total amount, category, and if it's tax deductible. Provide the response in a clear, organized format."
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{file_content_type};base64,{image_b64}" # Use validated file_content_type
                        }
                    }
                ]
            }
        ]
        
        # Create the completion request exactly like your chat assistant
        print(f"Sending request to Qwen model ('{MODEL_NAME}') with MIME type: {file_content_type}...") # Log the MIME type
        completion = client.chat.completions.create(
            model=MODEL_NAME,
            messages=messages,
        )
        
        # Extract the response content
        if completion.choices and completion.choices[0].message:
            extracted_text = completion.choices[0].message.content
            
            # Extract structured data from the OCR text
            extracted_data = extract_receipt_data_from_text(extracted_text)
            
            # Return results
            response_data = {
                "filename": file.filename, 
                "ocr_text": extracted_text,
                **extracted_data
            }
            return JSONResponse(content=response_data)
        else:
            raise HTTPException(status_code=500, detail="Model returned an empty response")
            
    except Exception as e:
        print(f"Error processing receipt: {e}")
        # Return a cleaner error message to the client
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
    # Print environment variables status (not the actual keys for security)
    print("\n--- Environment Configuration ---")
    print(f"DASHSCOPE_API_KEY: {'Configured' if API_KEY else 'NOT CONFIGURED'}")
    print(f"MODEL_NAME: {MODEL_NAME}")
    print(f"BASE_URL: {BASE_URL}")
    print("--------------------------------\n")

    uvicorn.run(app, host="0.0.0.0", port=8001)