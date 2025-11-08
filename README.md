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
  providers/
    auth_provider.dart
  models/
    user.dart
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
| Login Screen                   | CHECKED  | Hardcoded `admin/admin` + student login    |
| Role-based Homepages           | CHECKED  | `home_student.dart` & `home_instructor.dart` |
| Student Dashboard              | CHECKED  | Shows courses, "Việc cần làm" (Classwork)  |
| Classwork Screen               | CHECKED  | Lists assignments, filter by course/status |
| Assignment Detail Screen       | CHECKED  | Title, due date, score, description, comments, link |
| Calendar Screen                | CHECKED  | Weekly view with course blocks             |
| Localization (EN + VI)         | CHECKED  | `app_en.arb`, `app_vi.arb`, `flutter gen-l10n` |
| go_router Navigation           | CHECKED  | With `extra` passing, redirects, aliases   |
| Riverpod State Management      | CHECKED  | `auth_provider.dart`                       |
| User Model + Roles             | CHECKED  | `models/user.dart`                         |
| Responsive UI                  | CHECKED  | Works on mobile, tablet, desktop           |
| Avatar & Profile UI            | CHECKED  | Images in `assets/images/`                 |

---

## MISSING / UNDONE Features (CROSS)

| Feature                        | Status   | Why?                                       |
|--------------------------------|----------|---------------------------------------------|
| Backend (Firebase / Custom)    | CROSS    | No database, no real data persistence       |
| Semester Management            | CROSS    | No CRUD for semesters                       |
| Course Management              | CROSS    | No CRUD for courses                         |
| Group Management               | CROSS    | No groups                                   |
| Student Management             | CROSS    | No student CRUD, no CSV import              |
| Announcements                  | CROSS    | Not implemented                             |
| Assignments (real)             | CROSS    | Static mock data only                       |
| Quizzes & Question Bank        | CROSS    | Not implemented                             |
| Materials                      | CROSS    | Not implemented                             |
| Forums / Discussions           | CROSS    | No comment threads                          |
| Private Messaging              | CROSS    | Not implemented                             |
| Notifications (In-app / Email) | CROSS    | Not implemented                             |
| CSV Export / Import            | CROSS    | Not implemented                             |
| Search, Filter, Sort           | CROSS    | Basic filter only, no search/sort           |
| Offline Mode (Hive/SQLite sync)| CROSS    | No offline support                          |
| Instructor Dashboard Metrics   | CROSS    | No charts, no stats                         |
| Semester Switcher              | CROSS    | Not implemented                             |
| Read-only Past Semesters       | CROSS    | Not implemented                             |
| File Attachments               | CROSS    | No upload/download                          |
| View/Download Tracking         | CROSS    | Not implemented                             |
| Submission Tracking            | CROSS    | Not implemented                             |
| Late Submission Rules          | CROSS    | Not implemented                             |
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

Note: All data is mocked in code. No backend. No persistence.
```

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