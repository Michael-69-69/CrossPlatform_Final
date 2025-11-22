from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from bson import ObjectId
import os
from dotenv import load_dotenv
import smtplib  # ✅ ADD
from email.mime.text import MIMEText  # ✅ ADD
from email.mime.multipart import MIMEMultipart  # ✅ ADD

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

# ✅ ADD: Email configuration
EMAIL_USER = os.getenv("EMAIL_USER")
EMAIL_PASS = os.getenv("EMAIL_PASS")
EMAIL_SENDER_NAME = os.getenv("EMAIL_SENDER_NAME", "LMS")

MONGO_URL = f"mongodb+srv://{MONGODB_USERNAME}:{MONGODB_PASSWORD}@{MONGODB_CLUSTER}/{DATABASE_NAME}?retryWrites=true&w=majority"

client = AsyncIOMotorClient(MONGO_URL)
db = client[DATABASE_NAME]

# ✅ IMPROVED: Helper function to convert ObjectId to string (RECURSIVE)
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
            # Handle nested queries like $in, $or, etc.
            result[key] = prepare_filter(value)
        else:
            result[key] = value
    
    return result

# ✅ Helper to prepare documents for insertion
def prepare_document_for_insert(doc: dict) -> dict:
    """Convert string IDs to ObjectId for fields that should be ObjectId"""
    result = {}
    for key, value in doc.items():
        # Convert single ID fields to ObjectId
        if key in ['courseId', 'semesterId', 'instructorId', 'quizId', 'assignmentId', 'studentId']:
            if isinstance(value, str) and len(value) == 24:
                try:
                    result[key] = ObjectId(value)
                except:
                    result[key] = value
            else:
                result[key] = value
        # Convert array ID fields to ObjectId arrays
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
        # Handle single ID fields
        if key in ['courseId', 'semesterId', 'instructorId', 'quizId', 'assignmentId', 'studentId']:
            if isinstance(value, str) and len(value) == 24:
                try:
                    result[key] = ObjectId(value)
                except:
                    result[key] = value
            else:
                result[key] = value
        # Handle array ID fields
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

# ✅ ADD: Email request model
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
        "status": "healthy"
    }

# Health check
@app.get("/health")
async def health_check():
    try:
        await client.admin.command('ping')
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

# ✅ ADD: Email endpoint
@app.post("/api/send-email")
async def send_email(request: EmailRequest):
    """Send email via SMTP"""
    try:
        # Check if email is configured
        if not EMAIL_USER or not EMAIL_PASS:
            raise HTTPException(
                status_code=503,
                detail="Email service not configured"
            )
        
        # Create message
        msg = MIMEMultipart('alternative')
        msg['Subject'] = request.subject
        msg['From'] = f"{EMAIL_SENDER_NAME} <{EMAIL_USER}>"
        msg['To'] = request.to
        
        # Add text and HTML parts
        if request.text:
            msg.attach(MIMEText(request.text, 'plain'))
        msg.attach(MIMEText(request.html, 'html'))
        
        # Send via Gmail SMTP
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.starttls()
            server.login(EMAIL_USER, EMAIL_PASS)
            server.send_message(msg)
        
        print(f"✅ Email sent to {request.to}")
        return {
            "success": True,
            "message": f"Email sent to {request.to}"
        }
    
    except smtplib.SMTPAuthenticationError:
        print("❌ SMTP authentication failed - check EMAIL_USER and EMAIL_PASS")
        raise HTTPException(
            status_code=401,
            detail="Email authentication failed"
        )
    except Exception as e:
        print(f"❌ Error sending email: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send email: {str(e)}"
        )

# Find multiple documents
@app.post("/api/find")
async def find_documents(request: FindRequest):
    try:
        collection = db[request.collection]
        
        # ✅ FIXED: Prepare filter with ObjectId conversion
        filter_query = prepare_filter(request.filter)
        
        # Build query
        cursor = collection.find(filter_query)
        
        # Apply sort
        if request.sort:
            cursor = cursor.sort(list(request.sort.items()))
        
        # Apply skip
        if request.skip:
            cursor = cursor.skip(request.skip)
        
        # Apply limit
        if request.limit:
            cursor = cursor.limit(request.limit)
        
        # Execute query and serialize
        documents = await cursor.to_list(length=None)
        
        # ✅ CRITICAL: Serialize ALL ObjectIds to strings
        return {"data": serialize_doc(documents)}
    except Exception as e:
        print(f"Error in find_documents: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Find one document
@app.post("/api/findOne")
async def find_one_document(request: FindOneRequest):
    try:
        collection = db[request.collection]
        
        # ✅ FIXED: Prepare filter with ObjectId conversion
        filter_query = prepare_filter(request.filter)
        
        document = await collection.find_one(filter_query)
        
        # ✅ CRITICAL: Serialize ALL ObjectIds to strings
        return {"data": serialize_doc(document)}
    except Exception as e:
        print(f"Error in find_one_document: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Insert one document
@app.post("/api/insertOne")
async def insert_one_document(request: InsertOneRequest):
    try:
        collection = db[request.collection]
        
        # ✅ Convert string IDs to ObjectId
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
        
        # ✅ Convert string IDs to ObjectId for all documents
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
        
        # Convert id string to ObjectId
        object_id = ObjectId(request.id)
        
        # ✅ Prepare update with ObjectId conversion
        update_data = prepare_update(request.update)
        update_doc = {"$set": update_data}
        
        result = await collection.update_one(
            {"_id": object_id},
            update_doc
        )
        
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
        
        # Convert id string to ObjectId
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
        
        # ✅ FIXED: Prepare filter with ObjectId conversion
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