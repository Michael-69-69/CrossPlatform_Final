# 📚 GGClassroom - Cross-Platform E-Learning Application

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?logo=mongodb)
![Gemini](https://img.shields.io/badge/Gemini-AI-4285F4?logo=google)
![License](https://img.shields.io/badge/License-MIT-green)

**A comprehensive Learning Management System (LMS) built with Flutter**

[Features](#-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Screenshots](#-screenshots) • [AI Features](#-ai-features)

</div>

---

## 📋 Project Overview

**GGClassroom** is a cross-platform E-Learning application inspired by Google Classroom, designed for educational institutions. It supports two user roles: **Instructors** and **Students**, with comprehensive features for course management, assignments, quizzes, and AI-powered learning assistance.

### 🎯 Key Highlights

- 🌐 **Cross-Platform**: Android, iOS, Windows, macOS, Linux, Web
- 🤖 **AI-Powered**: Gemini AI integration for quiz generation, material summarization, and learning assistance
- 📱 **Offline Support**: Local caching with automatic sync
- 🌍 **Bilingual**: Full Vietnamese and English support
- 🎨 **Modern UI**: Material Design 3 with dark mode support
- 📧 **Notifications**: Email and in-app notification system

---

## ✨ Features

### 👨‍🏫 Instructor Features

| Feature | Description |
|---------|-------------|
| **Semester Management** | Create, edit, delete semesters with active/inactive status |
| **Course Management** | Full CRUD with semester linking, session scheduling |
| **Group Management** | Create groups, assign students (one student per course rule) |
| **Student Management** | CRUD operations, CSV import, profile management |
| **Announcements** | Rich text, file attachments, group scoping, comments, view tracking |
| **Assignments** | Deadlines, late submissions, max attempts, file attachments, grading |
| **Quiz System** | Question bank, difficulty levels, auto/manual question selection |
| **Materials** | File/link attachments, view/download tracking |
| **Forum** | Discussion topics, threaded replies, file attachments |
| **Messaging** | Private inbox with students |
| **Dashboard** | Course statistics, submission tracking, grading overview |
| **Email Notifications** | Assignment reminders, grade notifications via EmailJS |

### 👨‍🎓 Student Features

| Feature | Description |
|---------|-------------|
| **Course View** | Browse enrolled courses by semester |
| **Classwork** | View assignments, quizzes, materials |
| **Assignment Submission** | File upload, multiple attempts, late submission support |
| **Quiz Taking** | Timed quizzes, instant scoring, attempt tracking |
| **Announcements** | View announcements, add comments |
| **Forum** | Participate in discussions |
| **Messaging** | Private inbox with instructors |
| **Notifications** | In-app and email notifications |
| **Dashboard** | Personal progress, upcoming deadlines |
| **Profile** | Edit profile, change avatar |

### 🤖 AI Features (Gemini Integration)

| Feature | Description |
|---------|-------------|
| **AI Learning Assistant** | Context-aware chatbot with full LMS data access |
| **AI Quiz Generator** | Auto-generate quizzes from materials with difficulty control |
| **Material Summarizer** | AI-powered document summarization with key points extraction |
| **File Text Extraction** | PDF, DOCX, TXT, MD, HTML, JSON, CSV support |
| **Drag & Drop** | Drop files directly into AI chat or summarizer |

---

## 🛠 Technology Stack

### Frontend
- **Flutter 3.x** - Cross-platform UI framework
- **Riverpod** - State management
- **go_router** - Navigation and routing
- **flutter_markdown** - Markdown rendering
- **desktop_drop** - Drag & drop file support

### Backend & Database
- **MongoDB Atlas** - Cloud database
- **mongo_dart** - Direct MongoDB connection (native platforms)
- **HTTP API** - Web platform support

### AI & Services
- **Google Gemini AI** - Quiz generation, summarization, chatbot
- **Syncfusion PDF** - PDF text extraction
- **EmailJS** - Email notification service

### Storage & Caching
- **Hive** - Local caching and offline support
- **SharedPreferences** - User preferences

### Localization
- **flutter_localizations** - i18n support
- **Vietnamese & English** - Full bilingual support

---

## 📦 Installation

### Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- MongoDB Atlas account
- Gemini API key (for AI features)

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/ggclassroom.git
cd ggclassroom
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Environment

Create a `.env` file in the project root:
```env
# MongoDB Atlas Configuration
MONGODB_USERNAME=your_username
MONGODB_PASSWORD=your_password
MONGODB_CLUSTER=cluster0.xxxxx.mongodb.net
DATABASE_NAME=GoogleClassroom

# Gemini AI (for AI features)
GEMINI_API_KEY=your_gemini_api_key

# EmailJS (for email notifications)
EMAILJS_SERVICE_ID=your_service_id
EMAILJS_TEMPLATE_ID=your_template_id
EMAILJS_PUBLIC_KEY=your_public_key

# Backend API (for web platform)
API_BASE_URL=http://localhost:3000/api
```

### 4. Run the Application
```bash
# Android/iOS
flutter run

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

---

## 🌐 Web Platform Setup

The web platform requires a backend API server due to MongoDB connection limitations in browsers.

### Backend Setup
```bash
cd backend-api-example
npm install
cp .env.example .env
# Edit .env with your MongoDB URI
npm start
```

See `backend-api-example/README.md` for detailed instructions.

---

## 🏗 Architecture

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── routes/
│   └── app_router.dart          # Navigation configuration
├── models/                      # Data models
│   ├── user.dart
│   ├── semester.dart
│   ├── course.dart
│   ├── group.dart
│   ├── assignment.dart
│   ├── announcement.dart
│   ├── quiz.dart
│   ├── question.dart
│   ├── material.dart
│   └── ...
├── providers/                   # Riverpod state management
│   ├── auth_provider.dart
│   ├── course_provider.dart
│   ├── assignment_provider.dart
│   ├── quiz_provider.dart
│   └── ...
├── services/                    # Business logic & APIs
│   ├── database_service.dart
│   ├── ai_service.dart
│   ├── cache_service.dart
│   ├── email_service.dart
│   ├── file_text_extractor.dart
│   └── network_service.dart
├── screens/                     # UI screens
│   ├── login_screen.dart
│   ├── instructor/
│   │   ├── home_instructor.dart
│   │   ├── course_detail_screen.dart
│   │   ├── assignments_tab.dart
│   │   ├── quiz_tab.dart
│   │   ├── ai_quiz_generator_screen.dart
│   │   ├── material_summarizer_screen.dart
│   │   └── ...
│   ├── student/
│   │   ├── student_home_screen.dart
│   │   ├── student_course_detail_screen.dart
│   │   ├── student_assignment_detail.dart
│   │   ├── student_quiz_take.dart
│   │   └── ...
│   └── shared/
│       ├── ai_chatbot_screen.dart
│       ├── inbox_screen.dart
│       └── ...
├── widgets/                     # Reusable widgets
├── theme/                       # App theming
│   └── app_theme.dart
└── utils/                       # Utilities
    ├── file_upload_helper.dart
    └── file_download_helper.dart
```

### State Management Flow
```
UI (Screens) 
    ↓ read/watch
Providers (Riverpod StateNotifiers)
    ↓ call
Services (Database, AI, Cache)
    ↓ store/fetch
MongoDB Atlas / Local Cache (Hive)
```

---

## 🤖 AI Features

### AI Learning Assistant

The AI chatbot has access to all LMS data including:
- Courses, groups, and students
- Assignments and submissions
- Quiz results and statistics

**Example queries:**
- "How many ungraded submissions are there?"
- "Who submitted late for Assignment 1?"
- "Show me statistics for WEB102"
- "List students in Group A"

### AI Quiz Generator

Generate quizzes automatically from any material:
1. Paste content or drag & drop files (PDF, DOCX, TXT)
2. Set difficulty distribution (Easy/Medium/Hard)
3. AI generates questions with explanations
4. Review and edit before saving

### Material Summarizer

Summarize documents with AI:
- **Summary**: Concise overview
- **Key Points**: Main takeaways
- **Concepts**: Terms and definitions
- **Review Questions**: Auto-generated questions
- **Study Tips**: Learning suggestions

### Supported File Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| PDF | `.pdf` | Full text extraction |
| Word | `.docx` | Modern Word format |
| Text | `.txt`, `.md` | Plain text and Markdown |
| HTML | `.html`, `.htm` | Web pages |
| JSON | `.json` | Structured data |
| CSV | `.csv` | Spreadsheet data |

---

## 🔐 Default Credentials

| Role | Username | Password |
|------|----------|----------|
| Instructor | `admin` | `admin` |
| Student | (varies) | (varies) |

---

## 📱 Build Instructions

### Android APK
```bash
flutter build apk --release --target-platform android-arm64
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Windows Executable
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### Web Deployment
```bash
flutter build web --release
# Output: build/web/
# Deploy to Firebase Hosting, GitHub Pages, or any static host
```

### iOS (requires macOS)
```bash
flutter build ios --release
```

---

## 🗂 Database Collections

| Collection | Description |
|------------|-------------|
| `users` | User accounts (instructors & students) |
| `semesters` | Academic semesters |
| `courses` | Course information |
| `groups` | Student groups per course |
| `announcements` | Course announcements |
| `assignments` | Assignment definitions |
| `questions` | Quiz question bank |
| `quizzes` | Quiz configurations |
| `quiz_submissions` | Student quiz attempts |
| `materials` | Course materials |
| `forum_topics` | Discussion topics |
| `forum_replies` | Topic replies |
| `messages` | Private messages |
| `in_app_notifications` | User notifications |

---

## 🎨 Theming

The app supports both light and dark themes with a modern Material Design 3 aesthetic.

### Color Palette

- **Primary**: Deep Purple (`#673AB7`)
- **Success**: Green (`#4CAF50`)
- **Warning**: Orange (`#FF9800`)
- **Error**: Red (`#F44336`)
- **AI Accent**: Teal (`#00BFA5`)

---

## 🌍 Localization

Full support for:
- 🇻🇳 **Vietnamese** (default)
- 🇺🇸 **English**

Switch languages via the language toggle in the app bar.

---

## Feature Checklist

### Core Features
- [x] User Authentication (Login/Register)
- [x] Role-based Access Control
- [x] Semester Management
- [x] Course Management
- [x] Group Management
- [x] Student Management
- [x] CSV Import/Export

### Content Management
- [x] Announcements with Comments
- [x] Assignments with Submissions
- [x] Quiz System with Question Bank
- [x] Materials with Attachments
- [x] Forum Discussions
- [x] Private Messaging

### AI Features
- [x] AI Learning Chatbot
- [x] AI Quiz Generator
- [x] AI Material Summarizer
- [x] File Text Extraction
- [x] Drag & Drop Support

### Notifications
- [x] In-App Notifications
- [x] Email Notifications (EmailJS)
- [x] Assignment Reminders
- [x] Grade Notifications

### Technical
- [x] Offline Caching (Hive)
- [x] Cross-Platform Support
- [x] Responsive Design
- [x] Dark Mode
- [x] Bilingual (VI/EN)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

**Cross-Platform Mobile Application Development - 502071**  
**Semester 1 – Academic Year 2025–2026**

---

## 📞 Support

For issues and questions:
- Open a [GitHub Issue](https://github.com/your-username/ggclassroom/issues)
- Email: your-email@example.com

---

<div align="center">


</div>