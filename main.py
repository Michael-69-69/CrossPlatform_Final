from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from bson import ObjectId
import os
from dotenv import load_dotenv
import resend  # ✅ USE RESEND

load_dotenv()

app = FastAPI(title="MongoDB API for Flutter")

# CORS - Allow your Flutter web app to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter web domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
MONGODB_USERNAME = os.getenv("MONGODB_USERNAME")
MONGODB_PASSWORD = os.getenv("MONGODB_PASSWORD")
MONGODB_CLUSTER = os.getenv("MONGODB_CLUSTER")
DATABASE_NAME = os.getenv("DATABASE_NAME")

# ✅ RESEND configuration
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
EMAIL_SENDER_NAME = os.getenv("EMAIL_SENDER_NAME", "LMS")
EMAIL_FROM = os.getenv("EMAIL_FROM", "onboarding@resend.dev")  # Use your verified domain or resend.dev

# Set Resend API key
if RESEND_API_KEY:
    resend.api_key = RESEND_API_KEY
else:
    print("⚠️ WARNING: RESEND_API_KEY not configured")

MONGO_URL = f"mongodb+srv://{MONGODB_USERNAME}:{MONGODB_PASSWORD}@{MONGODB_CLUSTER}/{DATABASE_NAME}?retryWrites=true&w=majority"

client = AsyncIOMotorClient(MONGO_URL)
db = client[DATABASE_NAME]

# ✅ Helper function to convert ObjectId to string (RECURSIVE)
def serialize_doc(doc):
    """Recursively convert all ObjectId instances to strings"""
    if doc is None:
        return None
    if isinstance(doc, ObjectId):
        return str(doc)
    if isinstance(doc, list):
        return [serialize_doc(item) for item in doc]
    if isinstance(doc, dict):
        return {key: serialize_doc(value) for key, value in doc.items()}
    return doc

# ✅ Helper to convert string IDs to ObjectId for queries
def prepare_filter(filter_dict):
    """Convert string IDs to ObjectId in filter queries"""
    if not filter_dict:
        return {}
    
    result = {}
    for key, value in filter_dict.items():
        if key == "_id" and isinstance(value, str) and len(value) == 24:
            try:
                result[key] = ObjectId(value)
            except:
                result[key] = value
        elif key in ['courseId', 'semesterId', 'instructorId', 'quizId', 'assignmentId', 'studentId']:
            if isinstance(value, str) and len(value) == 24:
                try:
                    result[key] = ObjectId(value)
                except:
                    result[key] = value
            else:
                result[key] = value
        elif isinstance(value, dict):
            result[key] = prepare_filter(value)
        else:
            result[key] = value
    
    return result

# ✅ Helper to prepare documents for insertion
def prepare_document_for_insert(doc: dict) -> dict:
    """Convert string IDs to ObjectId for fields that should be ObjectId"""
    result = {}
    for key, value in doc.items():
        if key in ['courseId', 'semesterId', 'instructorId', 'quizId', 'assignmentId', 'studentId']:
            if isinstance(value, str) and len(value) == 24:
                try:
                    result[key] = ObjectId(value)
                except:
                    result[key] = value
            else:
                result[key] = value
        elif key in ['studentIds', 'groupIds', 'courseIds']:
            if isinstance(value, list):
                result[key] = [
                    ObjectId(item) if isinstance(item, str) and len(item) == 24 else item
                    for item in value
                ]
            else:
                result[key] = value
        else:
            result[key] = value
    
    return result

# ✅ Helper to prepare update documents
def prepare_update(update_dict: dict) -> dict:
    """Convert string IDs to ObjectId in update operations"""
    result = {}
    for key, value in update_dict.items():
        if key in ['courseId', 'semesterId', 'instructorId', 'quizId', 'assignmentId', 'studentId']:
            if isinstance(value, str) and len(value) == 24:
                try:
                    result[key] = ObjectId(value)
                except:
                    result[key] = value
            else:
                result[key] = value
        elif key in ['studentIds', 'groupIds', 'courseIds']:
            if isinstance(value, list):
                result[key] = [
                    ObjectId(item) if isinstance(item, str) and len(item) == 24 else item
                    for item in value
                ]
            else:
                result[key] = value
        else:
            result[key] = value
    
    return result

# Request models
class FindRequest(BaseModel):
    collection: str
    filter: Optional[Dict[str, Any]] = {}
    sort: Optional[Dict[str, Any]] = None
    limit: Optional[int] = None
    skip: Optional[int] = None

class FindOneRequest(BaseModel):
    collection: str
    filter: Optional[Dict[str, Any]] = {}

class InsertOneRequest(BaseModel):
    collection: str
    document: Dict[str, Any]

class InsertManyRequest(BaseModel):
    collection: str
    documents: List[Dict[str, Any]]

class UpdateOneRequest(BaseModel):
    collection: str
    id: str
    update: Dict[str, Any]

class DeleteOneRequest(BaseModel):
    collection: str
    id: str

class CountRequest(BaseModel):
    collection: str
    filter: Optional[Dict[str, Any]] = {}

# ✅ Email request model
class EmailRequest(BaseModel):
    to: str
    name: str
    subject: str
    html: str
    text: Optional[str] = None

# Root endpoint
@app.get("/")
async def root():
    return {
        "message": "MongoDB API is running",
        "database": DATABASE_NAME,
        "status": "healthy",
        "email_service": "resend" if RESEND_API_KEY else "not_configured"
    }

# Health check
@app.get("/health")
async def health_check():
    try:
        await client.admin.command('ping')
        return {
            "status": "healthy",
            "database": "connected",
            "email_configured": bool(RESEND_API_KEY)
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

# ✅ SEND EMAIL WITH RESEND
@app.post("/api/send-email")
async def send_email(request: EmailRequest):
    """
    Send email via Resend API
    Much more reliable than SMTP, especially on platforms like Render
    """
    try:
        print(f"📧 Sending email to: {request.to}")
        print(f"   Subject: {request.subject}")
        
        # Check if Resend is configured
        if not RESEND_API_KEY:
            print("❌ RESEND_API_KEY not configured")
            raise HTTPException(
                status_code=503,
                detail="Email service not configured. Set RESEND_API_KEY in environment variables."
            )
        
        # Send email using Resend
        params = {
            "from": f"{EMAIL_SENDER_NAME} <{EMAIL_FROM}>",
            "to": [request.to],
            "subject": request.subject,
            "html": request.html,
        }
        
        # Add plain text if provided
        if request.text:
            params["text"] = request.text
        
        # Send via Resend
        email = resend.Emails.send(params)
        
        print(f"✅ Email sent successfully!")
        print(f"   Email ID: {email.get('id', 'N/A')}")
        
        return {
            "success": True,
            "message": f"Email sent to {request.to}",
            "id": email.get('id')
        }
        
    except Exception as e:
        print(f"❌ Email error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send email: {str(e)}"
        )

# Find multiple documents
@app.post("/api/find")
async def find_documents(request: FindRequest):
    try:
        collection = db[request.collection]
        filter_query = prepare_filter(request.filter)
        cursor = collection.find(filter_query)
        
        if request.sort:
            cursor = cursor.sort(list(request.sort.items()))
        if request.skip:
            cursor = cursor.skip(request.skip)
        if request.limit:
            cursor = cursor.limit(request.limit)
        
        documents = await cursor.to_list(length=None)
        return {"data": serialize_doc(documents)}
    except Exception as e:
        print(f"Error in find_documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Find one document
@app.post("/api/findOne")
async def find_one_document(request: FindOneRequest):
    try:
        collection = db[request.collection]
        filter_query = prepare_filter(request.filter)
        document = await collection.find_one(filter_query)
        return {"data": serialize_doc(document)}
    except Exception as e:
        print(f"Error in find_one_document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Insert one document
@app.post("/api/insertOne")
async def insert_one_document(request: InsertOneRequest):
    try:
        collection = db[request.collection]
        document = prepare_document_for_insert(request.document)
        result = await collection.insert_one(document)
        return {"insertedId": str(result.inserted_id)}
    except Exception as e:
        print(f"Error in insert_one_document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Insert many documents
@app.post("/api/insertMany")
async def insert_many_documents(request: InsertManyRequest):
    try:
        collection = db[request.collection]
        documents = [prepare_document_for_insert(doc) for doc in request.documents]
        result = await collection.insert_many(documents)
        return {"insertedIds": [str(id) for id in result.inserted_ids]}
    except Exception as e:
        print(f"Error in insert_many_documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Update one document
@app.post("/api/updateOne")
async def update_one_document(request: UpdateOneRequest):
    try:
        collection = db[request.collection]
        object_id = ObjectId(request.id)
        update_data = prepare_update(request.update)
        update_doc = {"$set": update_data}
        result = await collection.update_one({"_id": object_id}, update_doc)
        return {
            "matchedCount": result.matched_count,
            "modifiedCount": result.modified_count
        }
    except Exception as e:
        print(f"Error in update_one_document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Delete one document
@app.post("/api/deleteOne")
async def delete_one_document(request: DeleteOneRequest):
    try:
        collection = db[request.collection]
        object_id = ObjectId(request.id)
        result = await collection.delete_one({"_id": object_id})
        return {"deletedCount": result.deleted_count}
    except Exception as e:
        print(f"Error in delete_one_document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Count documents
@app.post("/api/count")
async def count_documents(request: CountRequest):
    try:
        collection = db[request.collection]
        filter_query = prepare_filter(request.filter)
        count = await collection.count_documents(filter_query)
        return {"count": count}
    except Exception as e:
        print(f"Error in count_documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Run with: uvicorn main:app --reload
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
