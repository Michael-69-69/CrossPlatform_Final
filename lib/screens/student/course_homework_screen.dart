// lib/screens/student/course_homework_screen.dart
import 'package:flutter/material.dart';
import 'assignment_detail_screen.dart';

class CourseHomeworkScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const CourseHomeworkScreen({super.key, required this.course});

  @override
  State<CourseHomeworkScreen> createState() => _CourseHomeworkScreenState();
}

class _CourseHomeworkScreenState extends State<CourseHomeworkScreen> {
  String _selectedFilter = "Tất cả";

  List<Map<String, dynamic>> get _assignments {
    return (widget.course["assignments"] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_selectedFilter == "Tất cả") return _assignments;
    return _assignments.where((a) => a["status"] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.course["title"],
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(
            radius: 36,
            backgroundImage: AssetImage("assets/images/student_avatar.jpg"),
          ),
          const SizedBox(height: 8),
          const Text(
            "Phong Mai",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                labelText: "Bộ lọc việc cần làm",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: const [
                DropdownMenuItem(value: "Tất cả", child: Text("Tất cả")),
                DropdownMenuItem(value: "Hoàn thành", child: Text("Hoàn thành")),
                DropdownMenuItem(value: "Chưa nộp", child: Text("Chưa nộp")),
              ],
              onChanged: (v) => setState(() => _selectedFilter = v!),
            ),
          ),

          const SizedBox(height: 16),

          // Homework List
          Expanded(
            child: _filteredAssignments.isEmpty
                ? const Center(
                    child: Text(
                      "Không có bài tập nào",
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredAssignments.length,
                    itemBuilder: (context, index) {
                      final a = _filteredAssignments[index];
                      final score = a["score"] ?? "Chưa chấm";
                      final status = a["status"] ?? "Chưa nộp";

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 0.3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AssignmentDetailScreen(assignment: {
                                  ...a,
                                  "courseTitle": widget.course["title"],
                                }),
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            leading: const Icon(
                              Icons.assignment_outlined,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            title: Text(
                              a["title"],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "Đến hạn ${a["due"]}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  score,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: status == "Hoàn thành"
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                                if (status == "Chưa nộp")
                                  const Icon(Icons.error_outline,
                                      size: 16, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

