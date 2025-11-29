// screens/student/tabs/student_people_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/group.dart';
import '../../../models/user.dart';
import '../../../providers/group_provider.dart';
import '../../../services/network_service.dart';

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
    final isOffline = NetworkService().isOffline;
    
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

    return RefreshIndicator(
      onRefresh: () => ref.read(groupProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          
          // ✅ Get students from provider (online)
          final providerStudents = students
              .where((s) => group.studentIds.contains(s.id))
              .toList();
          
          // ✅ Get cached student details using STATIC method
          final cachedDetails = GroupNotifier.getStudentDetails(group.id);
          
          final hasProviderStudents = providerStudents.isNotEmpty;
          final hasCachedDetails = cachedDetails.isNotEmpty;
          
          // Debug
          print('🔍 Group ${group.name}: providerStudents=${providerStudents.length}, cachedDetails=${cachedDetails.length}');
          
          final displayCount = hasProviderStudents 
              ? providerStudents.length 
              : (hasCachedDetails ? cachedDetails.length : group.studentIds.length);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: (hasProviderStudents || hasCachedDetails) 
                    ? Colors.blue 
                    : Colors.grey[400],
                child: Text(
                  group.name.isNotEmpty ? group.name[0] : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Text('$displayCount học sinh'),
                  if (isOffline && hasCachedDetails && !hasProviderStudents) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cached, size: 12, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Cached',
                            style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isOffline && !hasCachedDetails && !hasProviderStudents && group.studentIds.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              children: _buildStudentList(
                group,
                providerStudents,
                cachedDetails,
                hasProviderStudents,
                hasCachedDetails,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildStudentList(
    Group group,
    List<AppUser> providerStudents,
    List<Map<String, dynamic>> cachedDetails,
    bool hasProviderStudents,
    bool hasCachedDetails,
  ) {
    // ✅ Priority 1: Use provider students
    if (hasProviderStudents) {
      return providerStudents.map((student) {
        return ListTile(
          leading: CircleAvatar(
            child: Text(student.fullName.isNotEmpty ? student.fullName[0] : '?'),
          ),
          title: Text(student.fullName),
          subtitle: Text('${student.code ?? ''} • ${student.email}'),
        );
      }).toList();
    }
    
    // ✅ Priority 2: Use cached student details
    if (hasCachedDetails) {
      return cachedDetails.map((student) {
        final fullName = student['full_name']?.toString() ?? '';
        final code = student['code']?.toString() ?? '';
        final email = student['email']?.toString() ?? '';
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Text(
              fullName.isNotEmpty ? fullName[0] : '?',
              style: TextStyle(color: Colors.blue[800]),
            ),
          ),
          title: Text(fullName.isNotEmpty ? fullName : 'Unknown'),
          subtitle: Text('$code • $email'),
        );
      }).toList();
    }
    
    // ✅ Priority 3: Show count only
    if (group.studentIds.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 32, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Có ${group.studentIds.length} học sinh',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Chi tiết học sinh chưa được cache.\nKết nối mạng để xem thông tin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ];
    }
    
    return [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chưa có học sinh nào'),
      ),
    ];
  }
}