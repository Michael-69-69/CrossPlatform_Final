import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ggclassroom/l10n/app_localizations.dart';

class AssignmentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> assignment;
  const AssignmentDetailScreen({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(assignment["title"]),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              assignment["title"],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text("${loc?.due ?? "Đến hạn"}: ${assignment["due"]}"),
            const SizedBox(height: 8),
            Text("${loc?.score ?? "Điểm"}: ${assignment["score"]}"),
            const Divider(height: 24),
            Text(assignment["desc"]),
            const SizedBox(height: 20),
            if (assignment["link"] != null)
              ElevatedButton.icon(
                onPressed: () {
                  // open link
                },
                icon: const Icon(Icons.link),
                label: Text(loc?.openGoogleForm ?? "Mở Google Biểu mẫu"),
              ),
            const SizedBox(height: 24),
            if (assignment["comment"] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          AssetImage("assets/images/teacher1.jpg"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        assignment["comment"],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
