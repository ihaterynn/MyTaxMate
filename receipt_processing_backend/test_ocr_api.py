import os
import base64
import json
import sys
import requests
from dotenv import load_dotenv
import argparse
import ssl
import urllib3
import glob

# Suppress InsecureRequestWarning for the test
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def test_dashscope_direct_api(image_path=None, api_key=None, model_id=None, disable_ssl_verify=True):
    """
    Test the DashScope OCR API directly with a local image file.
    
    Args:
        image_path: Path to the image file (optional, will find one automatically if not provided)
        api_key: DashScope API key (optional, can use env var)
        model_id: OCR model ID (optional, can use env var)
        disable_ssl_verify: Whether to disable SSL verification (for testing only)
    """
    # Print current working directory to help with debugging path issues
    current_dir = os.getcwd()
    print(f"Current working directory: {current_dir}")
    
    # Load environment variables if needed
    load_dotenv()
    
    # Get API key and model ID from args or env vars
    api_key = api_key or os.getenv("MODEL_STUDIO_API_KEY")
    model_id = model_id or os.getenv("QWEN_OCR_MODEL_ID") or "Qwen-VL"
    
    if not api_key:
        print("ERROR: API key not provided. Please set MODEL_STUDIO_API_KEY env var or pass --api-key.")
        return False
    
    # If no image_path provided, try to find test images automatically
    if not image_path:
        # HARDCODED PATH - Edit this if needed for your specific project
        specific_path = "c:/Users/User/OneDrive/Desktop/Alibaba Cloud Hackathon/MyTaxMate/receipt_processing_backend/test_images/batch1-0001.jpg"
        if os.path.exists(specific_path):
            image_path = specific_path
            print(f"Using hardcoded test image path: {image_path}")
        else:
            # Look for test images in common locations with more variations
            script_dir = os.path.dirname(os.path.abspath(__file__))
            test_dirs = [
                "test_images",
                "./test_images",
                "../test_images",
                "images",
                "./images",
                "../images",
                os.path.join(script_dir, "test_images"),
                os.path.join(script_dir, "../test_images"),
                os.path.join(current_dir, "test_images"),
                os.path.join(current_dir, "../test_images"),
                os.path.join(os.path.dirname(current_dir), "test_images")
            ]
            
            print("Searching for test images in the following directories:")
            for test_dir in test_dirs:
                print(f"  - {test_dir}")
                if os.path.exists(test_dir):
                    print(f"    Directory exists: {test_dir}")
                    image_files = (
                        glob.glob(os.path.join(test_dir, "*.jpg")) + 
                        glob.glob(os.path.join(test_dir, "*.jpeg")) + 
                        glob.glob(os.path.join(test_dir, "*.png"))
                    )
                    if image_files:
                        print(f"    Found {len(image_files)} images: {image_files}")
                        image_path = image_files[0]
                        print(f"Automatically selected test image: {image_path}")
                        break
            
            if not image_path:
                print("ERROR: No test image provided and couldn't find any automatically.")
                print("Please specify an image path or place test images in a 'test_images' folder.")
                # Prompt user to enter a path directly
                user_path = input("Enter the full path to a test image: ")
                if user_path and os.path.exists(user_path):
                    image_path = user_path
                else:
                    return False
    
    # Read the image file
    try:
        with open(image_path, "rb") as f:
            image_bytes = f.read()
            file_size_kb = len(image_bytes) / 1024
            print(f"Successfully read image file ({file_size_kb:.2f} KB)")
    except Exception as e:
        print(f"ERROR: Failed to read image file: {str(e)}")
        return False
    
    # Base64 encode the image
    image_b64 = base64.b64encode(image_bytes).decode('utf-8')
    
    # Prepare the API request
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    # Try different API endpoints and payload formats
    endpoints = [
        # Standard OCR endpoint
        "https://dashscope.aliyuncs.com/api/v1/services/vision/ocr/general",
        # Vision model endpoints
        "https://dashscope.aliyuncs.com/api/v1/services/vision/image-understanding/general",
        # Direct model endpoints
        f"https://dashscope.aliyuncs.com/api/v1/models/{model_id}",
        # Alternative base URL
        "https://api.dashscope.aliyuncs.com/api/v1/services/vision/ocr/general"
    ]
    
    payloads = [
        # Format 1: Standard format
        {
            "model": model_id,
            "input": {
                "image": f"data:image/jpeg;base64,{image_b64}"
            }
        },
        # Format 2: Alternative format with parameters
        {
            "model": model_id,
            "parameters": {},
            "input": {
                "image": f"data:image/jpeg;base64,{image_b64}"
            }
        },
        # Format 3: Simple format
        {
            "model": model_id,
            "image": f"data:image/jpeg;base64,{image_b64}"
        }
    ]
    
    # Create a request session to reuse for all requests
    session = requests.Session()
    
    # Configure session for SSL issues - default to disabled for testing
    if disable_ssl_verify:
        print("WARNING: SSL verification is disabled. This should only be used for testing.")
        session.verify = False
    
    # Try all combinations of endpoints and payloads
    success = False
    
    for endpoint in endpoints:
        for i, payload in enumerate(payloads):
            print(f"\nTrying endpoint: {endpoint}")
            print(f"Payload format #{i+1}")
            
            try:
                # Always try with SSL verification disabled for testing
                response = session.post(endpoint, headers=headers, json=payload, timeout=30)
                
                print(f"Response status code: {response.status_code}")
                
                if response.status_code == 200:
                    print("SUCCESS! API call successful.")
                    print("\nResponse content:")
                    
                    response_json = response.json()
                    print(json.dumps(response_json, indent=2))
                    
                    print("\nUseful information for your code:")
                    print(f"- Successful endpoint: {endpoint}")
                    print(f"- Successful payload format: {i+1}")
                    print(f"- Model ID used: {model_id}")
                    
                    success = True
                    break
                else:
                    print(f"Error response: {response.text}")
            except Exception as e:
                print(f"Exception during API call: {str(e)}")
                
                # If it's a connection error, provide more helpful info
                if "ConnectionError" in str(e) or "SSLError" in str(e):
                    print("Network connection issues detected. Possible solutions:")
                    print("1. Check your internet connection")
                    print("2. Check if you're behind a proxy or firewall")
                    print("3. Try updating your Python packages: pip install --upgrade requests urllib3 pyOpenSSL")
                    print("4. Make sure your API key is correct")
        
        if success:
            break
    
    if not success:
        print("\nAll API call attempts failed. Please check:")
        print("1. Your API key (make sure it's valid and has the correct permissions)")
        print("2. The model ID (make sure it exists and supports OCR)")
        print("3. Your network connection (proxy, firewall)")
        print("4. Check the Alibaba Cloud DashScope documentation for the correct API endpoints")
        print("\nIf you're getting SSL errors, it might be that:")
        print("- You're behind a corporate firewall or proxy")
        print("- Your network is blocking certain SSL connections")
        print("- You need to update your OpenSSL or Python packages")
    
    return success

if __name__ == "__main__":
    try:
        # Check if running with command-line arguments
        parser = argparse.ArgumentParser(description="Test DashScope OCR API directly")
        parser.add_argument("image_path", nargs="?", help="Path to the image file to test (optional)")
        parser.add_argument("--api-key", help="DashScope API key (optional, can use env var)")
        parser.add_argument("--model-id", help="OCR model ID (optional, can use env var)")
        parser.add_argument("--ssl-verify", dest="ssl_verify", action="store_true", help="Enable SSL verification")
        parser.add_argument("--no-ssl-verify", dest="ssl_verify", action="store_false", help="Disable SSL verification")
        parser.set_defaults(ssl_verify=False)  # Default to SSL verification disabled for testing
        
        args = parser.parse_args()
        
        # Run the test with provided or auto-detected image
        test_dashscope_direct_api(args.image_path, args.api_key, args.model_id, not args.ssl_verify)
    except Exception as e:
        print(f"Error running test script: {str(e)}")
        # If error occurs, try to run with auto-detection and default settings
        print("\nTrying again with default settings...")
        test_dashscope_direct_api()