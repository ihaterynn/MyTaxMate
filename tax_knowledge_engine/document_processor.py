import os
import PyPDF2
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.embeddings import HuggingFaceEmbeddings 
from langchain_community.vectorstores import FAISS 
from langchain.docstore.document import Document 

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
VECTOR_STORE_DIR = os.path.join(os.path.dirname(__file__), 'vector_store')
EMBEDDING_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

def load_documents():
    """Loads documents from the data directory."""
    print(f"Looking for PDF documents in: {DATA_DIR}")
    pdf_files = [f for f in os.listdir(DATA_DIR) if f.endswith(".pdf")]
    
    all_docs = []
    for pdf_file in pdf_files:
        pdf_path = os.path.join(DATA_DIR, pdf_file)
        print(f"Processing PDF: {pdf_path}")
        try:
            with open(pdf_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                num_pages = len(reader.pages)
                print(f"  Found {num_pages} pages.")
                for page_num in range(num_pages):
                    page = reader.pages[page_num]
                    text = page.extract_text()
                    if text: 
                        # Create a Langchain Document object
                        all_docs.append(Document(page_content=text, metadata={"source": pdf_file, "page": page_num + 1}))
                    else:
                        print(f"  Warning: No text extracted from page {page_num + 1} of {pdf_file}")
        except Exception as e:
            print(f"Error processing {pdf_file}: {e}")
    print(f"Loaded {len(all_docs)} document pages in total.")
    return all_docs

def chunk_text(documents, chunk_size=1000, chunk_overlap=200):
    """Chunks list of Langchain Document objects into smaller pieces."""
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size, 
        chunk_overlap=chunk_overlap,
        length_function=len
    )
    chunks = text_splitter.split_documents(documents) # split_documents for list of Document objects
    print(f"Chunked {len(documents)} documents into {len(chunks)} text chunks.")
    return chunks

def create_vector_store(chunks):
    """Creates and saves a vector store from text chunks."""
    if not chunks:
        print("No chunks to process. Skipping vector store creation.")
        return

    # Initialize embeddings model
    print(f"Initializing embedding model: {EMBEDDING_MODEL_NAME}")
    embeddings = HuggingFaceEmbeddings(model_name=EMBEDDING_MODEL_NAME)
    
    if not os.path.exists(VECTOR_STORE_DIR):
        os.makedirs(VECTOR_STORE_DIR)
    
    print(f"Creating FAISS vector store in: {VECTOR_STORE_DIR}")
    try:
        vector_store = FAISS.from_documents(chunks, embeddings)
        vector_store_path = os.path.join(VECTOR_STORE_DIR, "faiss_index")
        vector_store.save_local(vector_store_path)
        print(f"Vector store created and saved to {vector_store_path}")
    except Exception as e:
        print(f"Error creating or saving vector store: {e}")

def process_and_store_documents():
    """Main function to load, process, and store documents."""
    documents = load_documents()
    if documents:
        chunks = chunk_text(documents)
        create_vector_store(chunks)
        print("Document processing and vector store creation complete.")
    else:
        print("No documents found to process.")

if __name__ == '__main__':
    process_and_store_documents()
    print("Tax knowledge engine: Document processing script finished.")