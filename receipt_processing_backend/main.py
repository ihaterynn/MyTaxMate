import os
import base64
import json
import logging
from dotenv import load_dotenv
import requests
import urllib3
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Suppress SSL warnings for development
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Setup logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# --- Configuration ---
# Try different environment variable names that might be used
MODEL_STUDIO_API_KEY = os.getenv("MODEL_STUDIO_API_KEY") or os.getenv("DASHSCOPE_API_KEY")
QWEN_OCR_MODEL_ID = os.getenv("QWEN_OCR_MODEL_ID") or "Qwen-VL"

# SSL verification (set to False for development/testing)
SSL_VERIFY = False

# Region for aliyun SDK
REGION = os.getenv("ALIYUN_REGION") or "cn-shanghai"

app = FastAPI(
    title="Receipt Processing API",
    description="Processes receipts using Alibaba Cloud OCR.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For production, restrict this to your frontend's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def call_ocr_api_dashscope(image_bytes):
    """
    Call OCR using DashScope SDK approach
    """
    # Base64 encode the image
    image_b64 = base64.b64encode(image_bytes).decode('utf-8')
    
    # Prepare the API request
    headers = {
        "Authorization": f"Bearer {MODEL_STUDIO_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Standard DashScope Vision API endpoint
    endpoint = "https://dashscope.aliyuncs.com/api/v1/services/vision/ocr/general"
    
    payload = {
        "model": QWEN_OCR_MODEL_ID,
        "input": {
            "image": f"data:image/jpeg;base64,{image_b64}"
        }
    }
    
    # Create a session for connection reuse
    session = requests.Session()
    session.verify = SSL_VERIFY
    
    try:
        logger.info(f"Calling DashScope OCR API")
        response = session.post(endpoint, headers=headers, json=payload, timeout=30)
        
        if response.status_code == 200:
            logger.info(f"Successfully called DashScope OCR API")
            return response.json()
        else:
            logger.warning(f"DashScope OCR API call failed with status {response.status_code}: {response.text}")
            return None
    except Exception as e:
        logger.warning(f"DashScope OCR API call exception: {str(e)}")
        return None

def call_ocr_api_aliyun_sdk(image_bytes):
    """
    Call OCR using the aliyun SDK approach as shown in docs
    """
    try:
        # Try to import aliyun SDK components - You'll need to install these first if using this method
        from aliyunsdkcore import client
        from aliyunsdkgreen.request.v20180509 import ImageSyncScanRequest
        import uuid
        
        # The aliyun SDK uses a different API key format (AccessKey ID and Secret)
        access_key_id = os.getenv("ALIBABA_CLOUD_ACCESS_KEY_ID")
        access_key_secret = os.getenv("ALIBABA_CLOUD_ACCESS_KEY_SECRET")
        
        if not access_key_id or not access_key_secret:
            logger.warning("Aliyun SDK credentials not found in environment variables")
            return None
        
        # Create ACS client
        clt = client.AcsClient(access_key_id, access_key_secret, REGION)
        
        # Create request
        request = ImageSyncScanRequest.ImageSyncScanRequest()
        request.set_accept_format('JSON')
        
        # If you have a URL for the image:
        # task = {"dataId": str(uuid.uuid1()), "url": "https://example.com/test.jpg"}
        
        # For directly uploaded binary image:
        image_b64 = base64.b64encode(image_bytes).decode('utf-8')
        task = {"dataId": str(uuid.uuid1()), "imageBase64": image_b64}
        
        # Set OCR scene
        request.set_content(json.dumps({"tasks": [task], "scenes": ["ocr"]}))
        
        # Send request
        response = clt.do_action_with_exception(request)
        
        # Parse response
        result = json.loads(response)
        
        if 200 == result.get("code"):
            return result
        else:
            logger.warning(f"Aliyun SDK OCR API call failed: {result}")
            return None
            
    except ImportError:
        logger.warning("Aliyun SDK not installed. Cannot use this method.")
        return None
    except Exception as e:
        logger.warning(f"Aliyun SDK OCR API call exception: {str(e)}")
        return None

def extract_receipt_data(ocr_results):
    """
    Extract structured data from OCR results.
    """
    # Default extracted data
    extracted_data = {
        "date": "",
        "merchant": "",
        "amount": "",
        "category": "Other",
        "is_deductible": False
    }
    
    try:
        # Extract text from OCR results - this will depend on the format of the OCR results
        all_text = ""
        
        # Try to extract text based on different possible response formats
        # DashScope format
        if isinstance(ocr_results, dict):
            if "output" in ocr_results and "text" in ocr_results["output"]:
                all_text = ocr_results["output"]["text"]
            elif "output" in ocr_results and "regions" in ocr_results["output"]:
                for region in ocr_results["output"]["regions"]:
                    if "text" in region:
                        all_text += region["text"] + " "
            # Aliyun SDK format
            elif "data" in ocr_results:
                for task_result in ocr_results["data"]:
                    if "results" in task_result:
                        for scene_result in task_result["results"]:
                            if "suggestion" in scene_result and "ocrData" in scene_result:
                                ocr_data = scene_result["ocrData"]
                                if isinstance(ocr_data, list):
                                    for item in ocr_data:
                                        if "text" in item:
                                            all_text += item["text"] + " "
        
        # Simple extraction based on text patterns
        lines = all_text.split("\n")
        
        for line in lines:
            line = line.strip()
            # Look for date patterns
            if any(date_key in line.lower() for date_key in ["date:", "date", "issued", "purchase"]):
                extracted_data["date"] = line
            
            # Look for merchant info
            if any(merchant_key in line.lower() for merchant_key in ["store:", "merchant:", "business:", "company:"]):
                extracted_data["merchant"] = line
            
            # Look for amount
            if any(amount_key in line.lower() for amount_key in ["total:", "amount:", "sum:", "price:"]):
                # Extract numbers from the line
                import re
                amounts = re.findall(r'\d+\.\d+', line)
                if amounts:
                    extracted_data["amount"] = amounts[-1]  # Take the last number as total
        
    except Exception as e:
        logger.error(f"Error extracting receipt data: {str(e)}")
    
    return extracted_data

@app.post("/process-receipt")
async def process_receipt(file: UploadFile = File(...)):
    """
    Accepts a receipt image, sends it to Alibaba Cloud OCR,
    and returns the extracted information.
    """
    if not MODEL_STUDIO_API_KEY:
        logging.error("API key not configured. Please set MODEL_STUDIO_API_KEY or DASHSCOPE_API_KEY env var.")
        raise HTTPException(status_code=500, detail="API key not configured.")

    try:
        contents = await file.read()
        
        # Try both API approaches
        ocr_results = None
        
        # First try DashScope SDK approach
        ocr_results = call_ocr_api_dashscope(contents)
        
        # If that failed, try Aliyun SDK approach
        if not ocr_results:
            ocr_results = call_ocr_api_aliyun_sdk(contents)
            
        if not ocr_results:
            raise Exception("All OCR API call attempts failed. Check your API key and network connection.")
        
        # Extract structured data
        extracted_data = extract_receipt_data(ocr_results)
        
        # Return combined results
        return JSONResponse(content={
            "filename": file.filename, 
            "ocr_output": ocr_results,
            **extracted_data
        })
            
    except Exception as e:
        logging.error(f"Error processing receipt: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing receipt: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "Receipt Processing API is running. Use the /process-receipt endpoint to upload receipts.",
        "status": "API keys configured" if MODEL_STUDIO_API_KEY else "Missing API keys - please set environment variables"
    }

if __name__ == "__main__":
    # Print environment variables status (not the actual keys for security)
    print("\n--- Environment Configuration ---")
    print(f"MODEL_STUDIO_API_KEY/DASHSCOPE_API_KEY: {'Configured' if MODEL_STUDIO_API_KEY else 'NOT CONFIGURED'}")
    print(f"ALIBABA_CLOUD_ACCESS_KEY_ID: {'Configured' if os.getenv('ALIBABA_CLOUD_ACCESS_KEY_ID') else 'NOT CONFIGURED'}")
    print(f"ALIBABA_CLOUD_ACCESS_KEY_SECRET: {'Configured' if os.getenv('ALIBABA_CLOUD_ACCESS_KEY_SECRET') else 'NOT CONFIGURED'}")
    print(f"QWEN_OCR_MODEL_ID: {QWEN_OCR_MODEL_ID}")
    print(f"SSL Verification: {'Enabled' if SSL_VERIFY else 'Disabled (insecure)'}")
    print("--------------------------------\n")

    uvicorn.run(app, host="0.0.0.0", port=8001)