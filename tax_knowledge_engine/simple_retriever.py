import os
from langchain_community.embeddings import HuggingFaceEmbeddings 
from langchain_community.vectorstores import FAISS

VECTOR_STORE_DIR = os.path.join(os.path.dirname(__file__), 'vector_store', 'faiss_index') 
EMBEDDING_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2" 

class TaxGuidelineRetriever:
    def __init__(self):
        self.vector_store = None
        self.embeddings = None
        self._load_dependencies()

    def _load_dependencies(self):
        """Loads embeddings and the vector store."""
        try:
            print(f"Initializing embedding model: {EMBEDDING_MODEL_NAME}")
            self.embeddings = HuggingFaceEmbeddings(model_name=EMBEDDING_MODEL_NAME)
            print("Embedding model initialized.")

            if os.path.exists(VECTOR_STORE_DIR) and os.path.exists(os.path.join(VECTOR_STORE_DIR, "index.faiss")):
                print(f"Loading vector store from: {VECTOR_STORE_DIR}")
                self.vector_store = FAISS.load_local(
                    VECTOR_STORE_DIR, 
                    self.embeddings, 
                    allow_dangerous_deserialization=True 
                )
                print("Vector store loaded successfully.")
            else:
                print(f"Warning: Vector store not found at {VECTOR_STORE_DIR}. Run document_processor.py first.")
                print(f"Expected 'index.faiss' and 'index.pkl' in {VECTOR_STORE_DIR}")
        except Exception as e:
            print(f"Error during dependency loading: {e}")
            self.vector_store = None 

    async def search_guidelines(self, query_text, top_k=3):
        """Searches for relevant guidelines in the vector store."""
        if not self.vector_store:
            print("Vector store not loaded. Cannot perform search.")
            # Attempt to reload if it wasn't loaded initially
            print("Attempting to reload dependencies...")
            self._load_dependencies()
            if not self.vector_store:
                 return ["Error: Vector store not available. Please process documents and ensure retriever is correctly initialized."]
        
        try:
            print(f"Performing similarity search for: '{query_text}', top_k={top_k}")
            docs = self.vector_store.similarity_search(query_text, k=top_k)
            print(f"Found {len(docs)} relevant documents.")
            return [doc.page_content for doc in docs]
        except Exception as e:
            print(f"Error during similarity search: {e}")
            return [f"Error during search: {e}"]

async def main():
    print("Testing TaxGuidelineRetriever...")
    retriever_instance = TaxGuidelineRetriever()
    
    if retriever_instance.vector_store:
        queries = [
            "office rent deductibility", 
            "medical expenses for parents",
            "software development costs"
        ]
        for query in queries:
            print(f"\nSearching for: '{query}'")
            results = await retriever_instance.search_guidelines(query)
            print(f"Search results for '{query}':")
            if results:
                for i, res in enumerate(results):
                    print(f"  Result {i+1}: {res[:200]}...") # print first 200 chars
            else:
                print("  No results found or error occurred.")
    else:
        print("Retriever's vector store not loaded. Cannot run example main().")

if __name__ == '__main__':
    import asyncio
    print("Running TaxGuidelineRetriever main test...")
    asyncio.run(main())
    print("Tax knowledge engine: Retriever setup and test complete.")