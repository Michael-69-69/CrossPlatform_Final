// screens/student/tabs/student_people_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/group.dart';
import '../../../../models/user.dart';

class StudentPeopleTab extends ConsumerWidget {
  final List<Group> groups;
  final List<AppUser> students;

  const StudentPeopleTab({
    super.key,
    required this.groups,
    required this.students,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Chưa có nhóm nào',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final groupStudents = students
            .where((s) => group.studentIds.contains(s.id))
            .toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              child: Text(group.name[0]),
            ),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${groupStudents.length} học sinh'),
            children: [
              if (groupStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có học sinh nào'),
                )
              else
                ...groupStudents.map((student) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(student.fullName[0]),
                    ),
                    title: Text(student.fullName),
                    subtitle: Text('${student.code} • ${student.email}'),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}