from langchain_community.document_loaders import PyPDFLoader, TextLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
import os

# === 1. Load documents from KB folder ===
docs = []
for file in os.listdir("KB"):
    path = os.path.join("KB", file)
    if file.endswith(".pdf"):
        docs += PyPDFLoader(path).load()
    elif file.endswith(".txt"):
        docs += TextLoader(path, encoding="utf-8").load()

# === 2. chunks ===
splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
splitted_docs = splitter.split_documents(docs)

# === 3. embeddings and FAISS DB creation ===
embedding = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
vectordb = FAISS.from_documents(splitted_docs, embedding)

# === 4. store FAISS in folder ===
vectordb.save_local("./faiss_store")

print("Knowledge Base created and saved at ./faiss_store")
