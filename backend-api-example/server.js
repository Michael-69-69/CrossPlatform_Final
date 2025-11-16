// Simple Node.js/Express backend API for MongoDB
// This allows the Flutter web app to access MongoDB via HTTP

const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB connection
let db;
const MONGODB_URI = process.env.MONGODB_URI || 
  'mongodb+srv://starboy_user:55359279@cluster0.qnn7pyq.mongodb.net/GoogleClarroom?retryWrites=true&w=majority';

MongoClient.connect(MONGODB_URI)
  .then(client => {
    db = client.db();
    console.log('Connected to MongoDB');
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });

// Helper to convert ObjectId to string in response
function sanitizeObject(obj) {
  if (obj === null || obj === undefined) return obj;
  if (obj instanceof ObjectId) return obj.toString();
  if (Array.isArray(obj)) return obj.map(sanitizeObject);
  if (typeof obj === 'object') {
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
      result[key] = sanitizeObject(value);
    }
    return result;
  }
  return obj;
}

// Helper to convert string IDs to ObjectId in query
function prepareQuery(filter) {
  if (!filter || typeof filter !== 'object') return filter;
  const result = {};
  for (const [key, value] of Object.entries(filter)) {
    if (key === '_id' || key.endsWith('Id')) {
      if (typeof value === 'string' && ObjectId.isValid(value)) {
        result[key] = new ObjectId(value);
      } else {
        result[key] = value;
      }
    } else if (typeof value === 'object' && !Array.isArray(value) && value !== null) {
      result[key] = prepareQuery(value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

// Routes
app.post('/api/find', async (req, res) => {
  try {
    const { collection, filter, sort, limit, skip } = req.body;
    if (!collection) {
      return res.status(400).json({ error: 'Collection name required' });
    }

    let query = db.collection(collection).find(prepareQuery(filter || {}));
    
    if (sort) {
      query = query.sort(sort);
    }
    if (skip) {
      query = query.skip(skip);
    }
    if (limit) {
      query = query.limit(limit);
    }

    const results = await query.toArray();
    res.json({ data: sanitizeObject(results) });
  } catch (error) {
    console.error('Find error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/findOne', async (req, res) => {
  try {
    const { collection, filter } = req.body;
    if (!collection) {
      return res.status(400).json({ error: 'Collection name required' });
    }

    const result = await db.collection(collection).findOne(prepareQuery(filter || {}));
    res.json({ data: sanitizeObject(result) });
  } catch (error) {
    console.error('FindOne error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/insertOne', async (req, res) => {
  try {
    const { collection, document } = req.body;
    if (!collection || !document) {
      return res.status(400).json({ error: 'Collection name and document required' });
    }

    // Convert string IDs to ObjectId
    const preparedDoc = prepareQuery(document);
    
    const result = await db.collection(collection).insertOne(preparedDoc);
    res.json({ id: result.insertedId.toString() });
  } catch (error) {
    console.error('InsertOne error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/updateOne', async (req, res) => {
  try {
    const { collection, id, update } = req.body;
    if (!collection || !id || !update) {
      return res.status(400).json({ error: 'Collection name, id, and update required' });
    }

    const preparedUpdate = prepareQuery(update);
    const result = await db.collection(collection).updateOne(
      { _id: new ObjectId(id) },
      { $set: preparedUpdate }
    );

    res.json({ 
      success: true, 
      matchedCount: result.matchedCount, 
      modifiedCount: result.modifiedCount 
    });
  } catch (error) {
    console.error('UpdateOne error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/deleteOne', async (req, res) => {
  try {
    const { collection, id } = req.body;
    if (!collection || !id) {
      return res.status(400).json({ error: 'Collection name and id required' });
    }

    const result = await db.collection(collection).deleteOne({ _id: new ObjectId(id) });
    res.json({ 
      success: true, 
      deletedCount: result.deletedCount 
    });
  } catch (error) {
    console.error('DeleteOne error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/count', async (req, res) => {
  try {
    const { collection, filter } = req.body;
    if (!collection) {
      return res.status(400).json({ error: 'Collection name required' });
    }

    const count = await db.collection(collection).countDocuments(prepareQuery(filter || {}));
    res.json({ count });
  } catch (error) {
    console.error('Count error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', db: db ? 'connected' : 'disconnected' });
});

app.listen(PORT, () => {
  console.log(`API server running on http://localhost:${PORT}`);
  console.log(`API base URL: http://localhost:${PORT}/api`);
});

