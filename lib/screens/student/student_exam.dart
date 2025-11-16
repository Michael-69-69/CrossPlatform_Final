// screens/student/student_exam.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentExamScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> exam;
  final String classId;
  const StudentExamScreen({super.key, required this.exam, required this.classId});

  @override ConsumerState<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends ConsumerState<StudentExamScreen> {
  final _answers = <int>[];
  int score = 0;

  @override
  Widget build(BuildContext context) {
    final questions = widget.exam['questions'] as List;
    return Scaffold(
      appBar: AppBar(title: const Text('Làm bài kiểm tra')),
      body: ListView.builder(
        itemCount: questions.length,
        itemBuilder: (context, i) {
          final q = questions[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q['question'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(4, (j) => RadioListTile(
                    title: Text(q['options'][j]),
                    value: j,
                    groupValue: _answers.length > i ? _answers[i] : null,
                    onChanged: (v) => setState(() => _answers.length > i ? _answers[i] = v! : _answers.add(v!)),
                  )),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          score = 0;
          for (int i = 0; i < questions.length; i++) {
            if (_answers[i] == questions[i]['correct']) score++;
          }
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Kết quả'),
              content: Text('Bạn được $score / ${questions.length}'),
              actions: [
                TextButton(
                  onPressed: () {
                    // TODO: Save score to DB
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

