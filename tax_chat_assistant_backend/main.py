import os
import requests
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# --- Configuration ---
MODEL_STUDIO_API_KEY = os.getenv("MODEL_STUDIO_API_KEY", "YOUR_MODEL_STUDIO_API_KEY")
# Replace with the specific Qwen NLP model ID from Model Studio (e.g., qwen-plus, qwen-turbo)
QWEN_NLP_MODEL_ID = os.getenv("QWEN_NLP_MODEL_ID", "YOUR_QWEN_NLP_MODEL_ID") 
# Example DashScope API URL for Qwen chat models. Verify the correct one.
MODEL_STUDIO_CHAT_API_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"

app = FastAPI(
    title="Tax Chat Assistant API",
    description="Provides tax advice using Alibaba Cloud Model Studio Qwen NLP.",
    version="0.1.0",
)

class ChatMessage(BaseModel):
    message: str
    history: list = [] # To maintain conversation history if needed

@app.post("/chat/")
async def chat_with_assistant(chat_message: ChatMessage):
    """
    Accepts a user message, sends it to the Model Studio Qwen NLP model,
    and returns the assistant's response.
    """
    if not MODEL_STUDIO_API_KEY or MODEL_STUDIO_API_KEY == "YOUR_MODEL_STUDIO_API_KEY":
        raise HTTPException(status_code=500, detail="API key not configured.")
    if not QWEN_NLP_MODEL_ID or QWEN_NLP_MODEL_ID == "YOUR_QWEN_NLP_MODEL_ID":
        raise HTTPException(status_code=500, detail="Qwen NLP Model ID not configured.")

    try:
        headers = {
            "Authorization": f"Bearer {MODEL_STUDIO_API_KEY}",
            "Content-Type": "application/json",
        }

        # --- Model Studio API Call ---
        # The payload structure will depend on the Model Studio API documentation
        # for the chosen Qwen NLP model. This is a general example for DashScope.
        payload = {
            "model": QWEN_NLP_MODEL_ID, # e.g., "qwen-turbo", "qwen-plus"
            "input": {
                "messages": [
                    # {"role": "system", "content": "You are a helpful assistant specializing in Malaysian tax law."},
                    # Add previous messages from chat_message.history if you want to maintain context
                    {"role": "user", "content": chat_message.message}
                ]
            },
            "parameters": {
                # "result_format": "message", # or "text"
                # Add other parameters like temperature, top_p, etc.
            }
        }
        
        # Include history if provided
        if chat_message.history:
            payload["input"]["messages"] = chat_message.history + [{"role": "user", "content": chat_message.message}]


        response = requests.post(MODEL_STUDIO_CHAT_API_URL, headers=headers, json=payload)
        response.raise_for_status()  # Raises an exception for HTTP errors
        
        api_response_data = response.json()
        
        # --- Process Results ---
        # The structure of api_response_data will depend on the Model Studio API.
        # For DashScope Qwen models, it's typically in output.choices[0].message.content or output.text
        assistant_reply = "Sorry, I could not process that." # Default reply
        if api_response_data.get("output"):
            if api_response_data["output"].get("choices"):
                assistant_reply = api_response_data["output"]["choices"][0]["message"]["content"]
            elif api_response_data["output"].get("text"): # For some models
                 assistant_reply = api_response_data["output"]["text"]


        return JSONResponse(content={"user_message": chat_message.message, "assistant_response": assistant_reply})

    except requests.exceptions.RequestException as e:
        # Log the full error from Model Studio if possible
        error_detail = f"Model Studio API request failed: {e}"
        if e.response is not None:
            error_detail += f" - Response: {e.response.text}"
        raise HTTPException(status_code=503, detail=error_detail)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")

@app.get("/")
async def root():
    return {"message": "Tax Chat Assistant API is running. Use the /chat endpoint to interact."}

if __name__ == "__main__":
    # Set environment variables before running
    if not os.getenv("MODEL_STUDIO_API_KEY"):
        print("Warning: MODEL_STUDIO_API_KEY environment variable not set.")
    if not os.getenv("QWEN_NLP_MODEL_ID"):
        print("Warning: QWEN_NLP_MODEL_ID environment variable not set (e.g., qwen-turbo).")
        
    uvicorn.run(app, host="0.0.0.0", port=8002)