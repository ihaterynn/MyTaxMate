import os
import base64
from dotenv import load_dotenv
from openai import OpenAI

# Load environment variables
load_dotenv()

# Test to check if API key is correctly set
API_KEY = os.getenv("DASHSCOPE_API_KEY")
print(f"API Key loaded: {'Yes (with length ' + str(len(API_KEY)) + ')' if API_KEY else 'No'}")

# Create a minimal 1x1 pixel base64 image for testing
minimal_image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg=="

# Try different models and endpoints
models_to_try = [
    "qwen-vl-chat",
    "qwen-vl", 
    "qwen-vl-lite"
]

endpoints_to_try = [
    "https://dashscope.aliyuncs.com/compatible-mode/v1",
    "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
]

for endpoint in endpoints_to_try:
    print(f"\nTrying endpoint: {endpoint}")
    client = OpenAI(
        api_key=API_KEY,
        base_url=endpoint,
    )
    
    # First test a simple non-vision request to check if API key works at all
    try:
        print("\nTesting regular text completion...")
        completion = client.chat.completions.create(
            model="qwen-turbo",
            messages=[
                {"role": "user", "content": "Hello, how are you?"}
            ]
        )
        print("✓ SUCCESS! Text API call worked")
        print(f"Response: {completion.choices[0].message.content[:50]}...")
    except Exception as e:
        print(f"✗ ERROR with text completion: {e}")
    
    # Now try each vision model
    for model in models_to_try:
        print(f"\nTesting vision model: {model}")
        try:
            completion = client.chat.completions.create(
                model=model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{minimal_image_base64}"
                                }
                            },
                            {
                                "type": "text", 
                                "text": "What's in this image?"
                            }
                        ]
                    }
                ]
            )
            print("✓ SUCCESS! Vision API call worked")
            print(f"Response: {completion.choices[0].message.content[:50]}...")
            # Found a working combination! Print the details
            print("\n=== SOLUTION FOUND ===")
            print(f"Working Model: {model}")
            print(f"Working Endpoint: {endpoint}")
            exit(0)  # Exit on success
        except Exception as e:
            print(f"✗ ERROR: {e}")

print("\nNo working configuration found. Please check your API key and subscription.")