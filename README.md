# GGClassroom – Final Project Status Report

**CROSS-PLATFORM MOBILE APPLICATION DEVELOPMENT - 502071**  
**SEMESTER 1 – ACADEMIC YEAR 2025–2026**  
**Lecturer: Mai Van Manh**

---

## Project Overview

A **cross-platform Flutter E-Learning app** inspired by Google Classroom, supporting **Instructor (admin/admin)** and **Students**.  
Built with **Flutter**, **Riverpod**, **go_router**, **Hive**, **Flutter Localizations**, and responsive design.

**GitHub Repository**: https://github.com/Michael-69-69/CrossPlatform_Final  
**Current Branch**: `main` (last updated: Nov 7, 2025)

---

## Recent Updates (Latest Implementation)

### Course Management System
- **Announcements Tab**: Full announcement system with rich-text content, file attachments, scope selection (one/multiple/all groups), social media-style comments, view tracking, and download tracking
- **Assignments Tab**: Complete assignment management with:
  - File attachments (picker and download)
  - Deadline management with late submission support
  - Maximum submission attempts
  - Real-time tracking table with filtering, sorting, and search
  - CSV export for assignment submissions
  - Grading interface
- **Groups Tab**: Full group management within courses:
  - Create, edit, and delete groups
  - Add/remove students with automatic enforcement of one-student-per-course rule
  - Uses all students from the dataset (not limited to course-specific students)
- **Tab Organization**: Tabs are properly spaced with Groups as the 5th tab (after Quiz and Materials)

### Data Management
- All data now stored in MongoDB Atlas (semesters, courses, groups, students, announcements, assignments)
- Full CRUD operations for all entities
- CSV import/export functionality

---

## Current Project Structure

```
lib/
  main.dart
  routes/
    app_router.dart
  screens/
    login_screen.dart
    home_student.dart
    home_instructor.dart
    classwork_screen.dart
    assignment_detail_screen.dart
    calendar_screen.dart
    instructor/
      course_detail_screen.dart
      course_list_screen.dart
      announcements_tab.dart
      assignments_tab.dart
      groups_tab.dart
      group_detail_screen.dart
      group_list_screen.dart
  providers/
    auth_provider.dart
    semester_provider.dart
    course_provider.dart
    group_provider.dart
    student_provider.dart
    announcement_provider.dart
    assignment_provider.dart
  models/
    user.dart
    semester.dart
    course.dart
    group.dart
    announcement.dart
    assignment.dart
    csv_preview_item.dart
  services/
    mongodb_service.dart
    data_loader.dart
  l10n/
    app_en.arb
    app_vi.arb
assets/
  images/
    student_avatar.jpg
    teacher1.jpg
    ...
```

---

## Implemented Features (CHECKED)

| Feature                        | Status   | Notes                                      |
|--------------------------------|----------|--------------------------------------------|
| Flutter + Cross-platform setup | CHECKED  | `flutter run` works on Android, Windows, Web |
| Login / Register Screen        | CHECKED  | Uses MongoDB Atlas `users` collection      |
| Role-based Homepages           | CHECKED  | `home_student.dart` & `home_instructor.dart` |
| Student Dashboard              | CHECKED  | Shows courses, "Việc cần làm" (Classwork)  |
| Classwork Screen               | CHECKED  | Lists assignments, filter by course/status | 
| Assignment Detail Screen       | CHECKED  | Title, due date, score, description, comments, link |
| Calendar Screen                | CHECKED  | Weekly view with course blocks             |
| Localization (EN + VI)         | CHECKED  | `app_en.arb`, `app_vi.arb`, `flutter gen-l10n` |
| go_router Navigation           | CHECKED  | With `extra` passing, redirects, aliases   |
| Riverpod State Management      | CHECKED  | `auth_provider.dart` and all other providers |
| User Model + Roles             | CHECKED  | `models/user.dart`                         |
| Responsive UI                  | CHECKED  | Works on mobile, tablet, desktop           |
| Avatar & Profile UI            | CHECKED  | Images in `assets/images/`                 |
| Semester Management            | CHECKED  | Full CRUD with MongoDB, filter by semester |
| Course Management              | CHECKED  | Full CRUD with MongoDB, linked to semesters |
| Group Management               | CHECKED  | Full CRUD, one student per course rule enforced |
| Student Management             | CHECKED  | Full CRUD, CSV import, quick create mode |
| Announcements                  | CHECKED  | Create, view, comment, scope (one/multiple/all groups), view/download tracking |
| Assignments (real)             | CHECKED  | Full CRUD, deadlines, late submissions, max attempts, file attachments |
| CSV Export / Import            | CHECKED  | CSV import for students, CSV export for assignment tracking |
| File Attachments               | CHECKED  | File picker for assignments, download functionality |
| View/Download Tracking         | CHECKED  | Announcement view tracking, file download tracking |
| Submission Tracking            | CHECKED  | Real-time tracking table with filtering, sorting, status |
| Late Submission Rules          | CHECKED  | Configurable late deadlines, late submission tracking |
| Search, Filter, Sort           | CHECKED  | Full search/filter/sort for assignments and tracking |

---

## MISSING / UNDONE Features (CROSS)

| Feature                        | Status   | Why?                                       |
|--------------------------------|----------|---------------------------------------------|
| Backend (Firebase / Custom)    | CROSS    | Using MongoDB Atlas directly, no custom backend server |
| Quizzes & Question Bank        | CROSS    | Not implemented (tab placeholder exists)   |
| Materials                      | CROSS    | Not implemented (tab placeholder exists)    |
| Forums / Discussions           | CROSS    | No comment threads (announcements have simple comments) |
| Private Messaging              | CROSS    | Not implemented                             |
| Notifications (In-app / Email) | CROSS    | Not implemented                             |
| Offline Mode (Hive/SQLite sync)| CROSS    | No offline support                          |
| Instructor Dashboard Metrics | CROSS    | No charts, no stats                         |
| Semester Switcher              | CROSS    | Not implemented                             |
| Read-only Past Semesters       | CROSS    | Not implemented                             |
| Quiz Randomization             | CROSS    | Not implemented                             |
| APK (arm64) + Windows EXE      | CROSS    | Not built                                   |
| Web Deployment (Firebase/GitHub Pages) | CROSS | Not deployed                        |
| GitHub Insights (Teamwork Evidence) | CROSS | Solo repo, no team activity           |
| Demo Video (1080p, all members)| CROSS    | Not recorded                                |
| Bonus Folder + Evidence        | CROSS    | No bonus features                           |
| Rubrik.docx Self-Assessment    | CROSS    | Not filled                                  |

---

## Deployment Status

| Platform                | Status | Link / File      |
|-------------------------|--------|------------------|
| Android APK (arm64)     | CROSS  | Not built        |
| Windows EXE (64-bit)    | CROSS  | Not built        |
| Web Version (Public URL)| CROSS  | Not deployed     |
| GitHub Pages / Firebase | CROSS  | Not set up       |

> **WARNING: Submission will get 0 if any of these are missing**

---

## Running the App (Current State)

```bash
flutter pub get
flutter gen-l10n   # if you modify .arb files
flutter run        # works on Android, Windows, Web

Note: User login/register uses MongoDB; the rest of the data (courses, assignments) is still mocked.
```

### Environment Setup

Create a `.env` file at project root with the MongoDB Atlas credentials:

```
MONGODB_USERNAME=starboy_user
MONGODB_PASSWORD=55359279
MONGODB_CLUSTER=cluster0.qnn7pyq.mongodb.net
DATABASE_NAME=GoogleClarroom
```

Ensure the cluster has a `GoogleClarroom` database and a `users` collection before running.

---

## What You MUST Do Before Submission (CHECKLIST)

- [ ] Build Android APK (arm64): `flutter build apk --release --target-platform android-arm64`
- [ ] Build Windows EXE: `flutter build windows`
- [ ] Deploy Web: `flutter build web` → upload to Firebase Hosting or GitHub Pages
- [ ] Get Public Web URL (e.g., `https://ggclassroom.web.app`)
- [ ] Record 1080p Demo Video (all team members speaking)
- [ ] Fill `Rubrik.docx` with self-assessment
- [ ] Create `git/` folder with **GitHub Insights screenshots** (1+ month, 2+ commits/week/member)
- [ ] Clean project: remove `build/`, `.dart_tool/`, etc.
- [ ] Test login: `admin/admin` and at least 1 student
- [ ] Test all screens on Web + Mobile

---

## Submission Folder Structure (MUST MATCH)

```
textid1_fullname1_id2_fullname2/
├── source/                  ← Full Flutter project (cleaned)
├── bin/
│   ├── ggclassroom.apk      ← arm64
│   └── ggclassroom.exe      ← Windows 64-bit
├── demo.mp4                 ← OR YouTube link in Readme.txt
├── git/
│   └── insights_*.png       ← GitHub Insights screenshots
├── Readme.txt               ← Build/run instructions + URLs + logins
├── Rubrik.docx              ← Self-assessment
└── Bonus/                   ← (if any)
```

---

## Final Warning

- If you submit only source code without APK + EXE + Web URL → 0 points
- If no GitHub Insights (teamwork proof) → -0.5 points
- If no Rubrik.docx → Not graded
- If web version crashes or needs wake-up → 0 for deployment

---

**This README now accurately reflects the current state of your project. Only features that are truly implemented are marked as CHECKED. All others remain CROSS until completed.**