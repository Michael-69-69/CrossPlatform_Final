import 'package:flutter/material.dart';
import 'package:ggclassroom/screens/assignment_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:ggclassroom/l10n/app_localizations.dart';

class ClassworkScreen extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  const ClassworkScreen({super.key, required this.courses});

  @override
  State<ClassworkScreen> createState() => _ClassworkScreenState();
}

class _ClassworkScreenState extends State<ClassworkScreen> {
  String _selectedStatus = "Tất cả";
  String _selectedCourse = "Tất cả lớp học";

  List<Map<String, dynamic>> get _assignments {
    return widget.courses.expand((course) {
      final title = course["title"] as String;
      final assigns =
          (course["assignments"] as List<dynamic>).cast<Map<String, dynamic>>();
      return assigns.map((a) => {...a, "courseTitle": title}).toList();
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    return _assignments.where((a) {
      final matchCourse = _selectedCourse == "Tất cả lớp học"
          ? true
          : a["courseTitle"] == _selectedCourse;
      final matchStatus =
          _selectedStatus == "Tất cả" ? true : a["status"] == _selectedStatus;
      return matchCourse && matchStatus;
    }).toList();
  }

  void _openAssignmentDetail(Map<String, dynamic> assignment, int fallbackIndex) {
    final id = (assignment['id']?.toString().isNotEmpty == true)
        ? assignment['id'].toString()
        : fallbackIndex.toString();
    // Use path navigation to avoid go_router version differences around named params
    context.go('/assignment/$id', extra: assignment);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final courseTitles =
        widget.courses.map((c) => c["title"] as String).toList(growable: false);
    final courseOptions = [loc?.allCourses ?? "Tất cả lớp học", ...courseTitles];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(loc?.classworkTitle ?? "Việc cần làm",
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
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

            // Filters section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCourse,
                    decoration: InputDecoration(
                      labelText: loc?.filterByCourse ?? "Lọc theo lớp học",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    items: courseOptions
                        .map((title) =>
                            DropdownMenuItem(value: title, child: Text(title)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCourse = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: loc?.assignmentStatus ?? "Trạng thái bài tập",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                    ),
                    items: [
                      DropdownMenuItem(value: loc?.all ?? "Tất cả", child: Text(loc?.all ?? "Tất cả")),
                      DropdownMenuItem(value: loc?.completed ?? "Hoàn thành", child: Text(loc?.completed ?? "Hoàn thành")),
                      DropdownMenuItem(value: loc?.notSubmitted ?? "Chưa nộp", child: Text(loc?.notSubmitted ?? "Chưa nộp")),
                    ],
                    onChanged: (v) => setState(() => _selectedStatus = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Assignment List
            Expanded(
              child: _filteredAssignments.isEmpty
                  ? Center(
                      child: Text(
                        loc?.noAssignments ?? "Không có bài tập nào phù hợp",
                        style: const TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredAssignments.length,
                      itemBuilder: (context, index) {
                        final a = _filteredAssignments[index];
                        final String rating = a["rating"]?.toString() ?? "";
                        final String status = a["status"] ?? "";

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.assignment_outlined,
                                      color: Colors.blueAccent,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a["title"],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${a["courseTitle"]} · ${loc?.due ?? "Đến hạn"} ${a["due"]}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (rating.isNotEmpty)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "${loc?.score ?? "Điểm"}: $rating",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blueAccent,
                                                    ),
                                                  ),
                                                ),
                                              if (status.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: status == (loc?.completed ?? "Hoàn thành")
                                                        ? Colors.green.shade50
                                                        : Colors.red.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: status == (loc?.completed ?? "Hoàn thành")
                                                          ? Colors.green
                                                          : Colors.redAccent,
                                                    ),
                                                  ),
                                                ),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _openAssignmentDetail(a, index),
                                      icon: const Icon(Icons.visibility),
                                      label: Text(loc?.viewDetails ?? "Xem chi tiết"),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        backgroundColor: Colors.blue.shade50,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
