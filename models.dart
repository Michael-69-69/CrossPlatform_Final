// import 'package:flutter/material.dart';

// // ===============================
// // Semester Model
// // ===============================
// class Semester {
//   final String code;
//   final String name;

//   Semester({required this.code, required this.name});
// }

// // ===============================
// // Course Model
// // ===============================
// class Course {
//   final String code;
//   final String name;
//   final int sessions;
//   final Semester semester;
//   final String instructor;
//   final String coverImage;

//   Course({
//     required this.code,
//     required this.name,
//     required this.sessions,
//     required this.semester,
//     required this.instructor,
//     required this.coverImage,
//   });
// }

// // ===============================
// // Group Model
// // ===============================
// class Group {
//   final String name;
//   final Course course;
//   final List<Student> students;

//   Group({required this.name, required this.course, this.students = const []});
// }

// // ===============================
// // Student Model
// // ===============================
// class Student {
//   final String id;
//   final String fullName;
//   final String email;
//   final String avatarUrl;

//   Student({
//     required this.id,
//     required this.fullName,
//     required this.email,
//     required this.avatarUrl,
//   });
// }

// // ===============================
// // Announcement Model
// // ===============================
// class Announcement {
//   final String title;
//   final String content;
//   final DateTime date;
//   final List<String> attachments;

//   Announcement({
//     required this.title,
//     required this.content,
//     required this.date,
//     this.attachments = const [],
//   });
// }

// // ===============================
// // Assignment Model
// // ===============================
// class Assignment {
//   final String title;
//   final String description;
//   final DateTime startDate;
//   final DateTime deadline;
//   final bool allowLate;
//   final int maxAttempts;
//   final List<String> attachments;

//   Assignment({
//     required this.title,
//     required this.description,
//     required this.startDate,
//     required this.deadline,
//     this.allowLate = false,
//     this.maxAttempts = 1,
//     this.attachments = const [],
//   });
// }

// // ===============================
// // Quiz Model
// // ===============================
// class Quiz {
//   final String title;
//   final DateTime openDate;
//   final DateTime closeDate;
//   final int attempts;
//   final List<QuizQuestion> questions;

//   Quiz({
//     required this.title,
//     required this.openDate,
//     required this.closeDate,
//     this.attempts = 1,
//     this.questions = const [],
//   });
// }

// // ===============================
// // Quiz Question Model
// // ===============================
// class QuizQuestion {
//   final String question;
//   final List<String> options;
//   final int correctIndex;
//   final String difficulty; // easy, medium, hard

//   QuizQuestion({
//     required this.question,
//     required this.options,
//     required this.correctIndex,
//     required this.difficulty,
//   });
// }

// // ===============================
// // Material Model
// // ===============================
// class CourseMaterial {
//   final String title;
//   final String description;
//   final List<String> attachments;

//   CourseMaterial({
//     required this.title,
//     required this.description,
//     this.attachments = const [],
//   });
// }
