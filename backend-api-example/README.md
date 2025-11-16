# Backend API Server for Flutter Web

This is a simple Node.js/Express server that provides HTTP API access to MongoDB for the Flutter web application.

## Setup

1. **Install Node.js** (if not already installed)
   - Download from https://nodejs.org/

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   Create a `.env` file in this directory:
   ```
   MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/database?retryWrites=true&w=majority
   PORT=3000
   ```

4. **Start the server**
   ```bash
   npm start
   ```
   
   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

5. **Update Flutter app `.env` file**
   Add the API base URL to your Flutter app's `.env` file:
   ```
   API_BASE_URL=http://localhost:3000/api
   ```

## API Endpoints

All endpoints are prefixed with `/api`:

- `POST /api/find` - Find multiple documents
- `POST /api/findOne` - Find one document
- `POST /api/insertOne` - Insert one document
- `PUT /api/updateOne` - Update one document
- `DELETE /api/deleteOne` - Delete one document
- `POST /api/count` - Count documents
- `GET /api/health` - Health check

## Deployment

For production, you can deploy this server to:
- Heroku
- Railway
- Render
- AWS EC2
- Google Cloud Run
- Any Node.js hosting service

Make sure to:
1. Set the `MONGODB_URI` environment variable
2. Set the `PORT` environment variable (or use the default 3000)
3. Update the Flutter app's `.env` with the production API URL
4. Enable CORS for your Flutter web app's domain

## Security Notes

⚠️ **Important**: This is a basic implementation. For production, you should:
- Add authentication/authorization
- Add rate limiting
- Validate and sanitize inputs
- Use HTTPS
- Add request logging
- Implement proper error handling

