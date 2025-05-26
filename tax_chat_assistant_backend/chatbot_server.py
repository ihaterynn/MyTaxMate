import os
import logging
import logging.handlers
from huggingface_hub import InferenceClient
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uvicorn
from dotenv import load_dotenv
import json
import traceback
import sys

# --- Setup Logging --- 
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)
log_file_path = os.path.join(LOG_DIR, 'chatbot_kag.log')
log_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
file_handler = logging.handlers.RotatingFileHandler(log_file_path, maxBytes=10*1024*1024, backupCount=5)
file_handler.setFormatter(log_formatter)
root_logger = logging.getLogger()
root_logger.setLevel(logging.DEBUG)
root_logger.addHandler(file_handler)
console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)
console_handler.setLevel(logging.INFO)
root_logger.addHandler(console_handler)
logger = logging.getLogger(__name__) 
# --- End Logging Setup ---

# --- Tax Knowledge Engine Imports ---
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
sys.path.append(os.path.join(project_root, 'tax_knowledge_engine'))
from kg_retriever import KnowledgeGraphAgenticRetriever # <-- ADD THIS

load_dotenv()

# --- Configuration --- 
HUGGING_FACE_API_TOKEN = os.getenv("HUGGING_FACE_API_TOKEN") 
MISTRAL_MODEL_ID = "mistralai/Mistral-7B-Instruct-v0.3" 

# --- Global Initializations ---
hf_client = None
if HUGGING_FACE_API_TOKEN:
    try:
        hf_client = InferenceClient(model=MISTRAL_MODEL_ID, token=HUGGING_FACE_API_TOKEN)
        logger.info(f"Hugging Face InferenceClient initialized globally for model: {MISTRAL_MODEL_ID}.")
    except Exception as e:
        logger.error(f"Error initializing Hugging Face InferenceClient globally: {e}", exc_info=True)
        # Depending on the application's needs, you might want to raise an error here or exit
else:
    logger.warning("HUGGING_FACE_API_TOKEN not found. Hugging Face client not initialized.")

# Initialize the KnowledgeGraphAgenticRetriever globally
tax_retriever = None
try:
    tax_retriever = KnowledgeGraphAgenticRetriever()
    logger.info("KnowledgeGraphAgenticRetriever initialized globally.")
except Exception as e:
    logger.error(f"Error initializing KnowledgeGraphAgenticRetriever globally: {e}", exc_info=True)
    # Decide how to handle this - server might not be able to run if KAG is critical

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Define Pydantic models for request and response data structures
class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    history: List[Message] = Field(default_factory=list)
    expenses: Optional[List[Dict[str, Any]]] = Field(default_factory=list)
    is_smart_assistant_query: Optional[bool] = False

async def chat_with_assistant(user_message: str, chat_history: List[Message], is_smart_assistant_query: bool, expenses: Optional[List[Dict[str, Any]]]):
    """Handles the chat logic with the assistant, incorporating KAG and using Mistral model."""
    if not hf_client:
        logger.error("hf_client not initialized in chat_with_assistant")
        raise HTTPException(status_code=500, detail="LLM client not initialized.")
    if not tax_retriever:
        logger.error("tax_retriever (KAG) not initialized in chat_with_assistant")
        raise HTTPException(status_code=500, detail="Knowledge retrieval service not initialized.")

    retrieved_context_str = ""
    # For KAG, the retrieved information is a formulated answer/context rather than raw guidelines.
    # We'll call it `kag_response_content` to distinguish.
    kag_response_content = ""
    insights_for_response = [] # This will hold the KAG response if applicable

    if user_message:
        query_for_retrieval = user_message
        if is_smart_assistant_query and expenses:
            expense_summary_for_query = "User has provided expense data. "
            query_for_retrieval = expense_summary_for_query + user_message
        elif is_smart_assistant_query and not expenses:
            query_for_retrieval = "General Malaysian tax tips or financial advice. " + user_message
        
        try:
            logger.info(f"Retrieving context from KAG for query: {query_for_retrieval[:100]}...")
            # Use the KAG retriever's retrieve method
            # The KAG retriever's `retrieve` method is async as per kg_retriever.py
            kag_response_content = await tax_retriever.retrieve(natural_language_query=query_for_retrieval)
            
            if kag_response_content and isinstance(kag_response_content, str):
                retrieved_context_str = f"\n\nRelevant Information from Knowledge Base (for assistant's reference only, do not directly quote to user unless asked):\n{kag_response_content}\n"
                logger.info(f"KAG Retrieved context: {retrieved_context_str[:300]}...")
                # For now, let's assume the KAG response itself can be an "insight"
                # This might need adjustment based on how KAG's response is structured
                insights_for_response = [kag_response_content] 
            elif kag_response_content: # If it's not a string but something was returned
                logger.warning(f"KAG returned non-string content: {type(kag_response_content)}. Converting to string.")
                retrieved_context_str = f"\n\nRelevant Information from Knowledge Base (for assistant's reference only, do not directly quote to user unless asked):\n{str(kag_response_content)}\n"
                insights_for_response = [str(kag_response_content)]
            else:
                logger.info("No relevant information found by KAG for the query.")
        except Exception as e:
            logger.error(f"Error during KAG retrieval: {e}", exc_info=True)
            # Fallback or error message if KAG fails
            retrieved_context_str = "\n\nNote: There was an issue retrieving detailed information from the knowledge base.\n"
            insights_for_response = ["Error retrieving detailed knowledge."]
    else:
        logger.info("No user message provided for KAG retrieval.")

    system_instruction = ""
    if is_smart_assistant_query:
        system_instruction = (
            "You are MyTaxMate AI, an AI assistant providing concise financial insights based on Malaysian taxation context and user expenses (if any). "
            "Your goal is to offer 2-3 short, actionable, and distinct points. Each point should be a complete sentence. "
            "Format your entire response as a JSON list of strings, where each string is a separate insight. Example: [\"Insight 1 about expenses.\", \"Insight 2 about tax deduction.\"]. "
            "Focus on potential savings, tax deductions, or spending patterns. Do not greet or use conversational fillers. Only provide the JSON list. "
            "If no expenses are provided, offer general Malaysian tax tips or financial advice suitable for a broad audience."
        )
    else:
        system_instruction = (
            "You are MyTaxMate AI, an AI assistant specializing in Malaysian taxation. Provide accurate, concise, and helpful information. "
            "Base your answers on the retrieved information if provided. "
            "MANDATORY Single Paragraph Summaries: For ALL general queries about tax concepts, reliefs, deductions, eligible items, or categories of these, you MUST provide your answer as a single, concise, flowing, narrative paragraph. "
            "Only use lists/bullet points if the user EXPLICITLY asks for them (e.g., 'list the types of...')."
        )

    if retrieved_context_str: # This now comes from KAG
        system_instruction += f"\n\nUse the following retrieved information to inform your answer:\n{retrieved_context_str}"

    full_conversation_text = ""
    for msg in chat_history:
        if msg.role == 'user':
            full_conversation_text += f"User: {msg.content}\n"
        elif msg.role == 'assistant':
            full_conversation_text += f"Assistant: {msg.content}\n"
    full_conversation_text += f"User: {user_message}"

    final_prompt = f"[INST] {system_instruction}\n\nConversation History and Current Question:\n{full_conversation_text}\n\nAssistant: [/INST]"

    logger.info(f"Sending prompt to Mistral. Smart assistant: {is_smart_assistant_query}. Model: {MISTRAL_MODEL_ID}")

    try:
        completion = hf_client.text_generation(
            prompt=final_prompt,
            max_new_tokens=500 if not is_smart_assistant_query else 150, 
            temperature=0.7 if not is_smart_assistant_query else 0.2, 
            do_sample=True, 
            return_full_text=False 
        )
        response_content = completion.strip()
        logger.info(f"Mistral Raw Response: {response_content}")
        # insights_for_response now contains the KAG response string as a list item
        return response_content, insights_for_response 

    except Exception as e:
        logger.error(f"Error during Hugging Face LLM call: {e}", exc_info=True)
        error_message = f"Error communicating with the AI model: {str(e)}"
        if is_smart_assistant_query:
            return json.dumps([error_message]), insights_for_response # Return KAG insights even if LLM fails
        else:
            return error_message, insights_for_response

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    """Endpoint to receive chat messages and return assistant's response."""
    if not HUGGING_FACE_API_TOKEN or not hf_client:
        logger.error("HUGGING_FACE_API_TOKEN not set or hf_client not initialized in chat_endpoint.")
        raise HTTPException(status_code=500, detail="AI service not configured.")
    if not tax_retriever: # Check for KAG retriever
        logger.error("tax_retriever (KAG) not initialized in chat_endpoint.")
        raise HTTPException(status_code=500, detail="Knowledge retrieval service not configured.")

    user_query_to_send = request.message
    if not user_query_to_send:
        if request.is_smart_assistant_query and request.expenses:
            user_query_to_send = "Provide financial insights based on my expenses."
        elif request.is_smart_assistant_query and not request.expenses:
            user_query_to_send = "Provide general financial insights or tax tips for Malaysians."
        else:
            raise HTTPException(status_code=422, detail="No query provided for chat.")

    try:
        response_content, insights_from_kag = await chat_with_assistant(
            user_query_to_send, 
            request.history, 
            request.is_smart_assistant_query, 
            request.expenses
        )
        
        if request.is_smart_assistant_query:
            try:
                insights = json.loads(response_content)
                if not isinstance(insights, list) or not all(isinstance(item, str) for item in insights):
                    logger.warning(f"LLM response for smart assistant is not a list of strings: {response_content}")
                    insights = ["Received non-standard insight format. Please try refreshing.", response_content]
                return JSONResponse(content=insights)
            except json.JSONDecodeError:
                logger.warning(f"Failed to decode LLM response as JSON for smart assistant: {response_content}")
                if response_content.startswith('[') and response_content.endswith(']'):
                    try:
                        cleaned_response = response_content.replace("'", "\"")
                        insights = json.loads(cleaned_response)
                        if isinstance(insights, list) and all(isinstance(item, str) for item in insights):
                            return JSONResponse(content=insights)
                    except Exception as parse_err:
                        logger.error(f"Could not manually parse cleaned smart assistant response: {parse_err}")
                return JSONResponse(content=["AI response was not valid JSON. Raw: " + response_content])
        else:
            # For regular chat, include KAG insights (which is the KAG response string in a list)
            return JSONResponse(content={"assistant_reply": response_content, "retrieved_info_snippets": insights_from_kag})

    except HTTPException as http_exc: 
        raise http_exc
    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"An error occurred: {str(e)}")

if __name__ == "__main__":
    if not hf_client or not tax_retriever:
        logger.critical("One or more critical services (HF Client, KAG Retriever) failed to initialize. Server cannot start.")
        sys.exit(1) # Exit if critical components are not ready
    uvicorn.run(app, host="0.0.0.0", port=8003)
