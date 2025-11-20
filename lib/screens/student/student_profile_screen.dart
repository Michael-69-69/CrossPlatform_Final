// screens/student/student_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 60,
              child: Text(
                user?.fullName[0] ?? '?',
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              user?.fullName ?? 'Unknown',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Email
            Text(
              user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),

            // Code
            if (user?.code != null)
              Chip(
                label: Text('MSSV: ${user!.code}'),
                avatar: const Icon(Icons.badge, size: 16),
              ),

            const SizedBox(height: 32),

            // Info Cards
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Họ và tên'),
                subtitle: Text(user?.fullName ?? ''),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(user?.email ?? ''),
              ),
            ),
            if (user?.code != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Mã số sinh viên'),
                  subtitle: Text(user!.code!),
                ),
              ),

            const SizedBox(height: 32),

            // Logout Button
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                // ✅ FIX: Call logout() without await since it's void
                ref.read(authProvider.notifier).logout();
                
                // Navigate immediately
                context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }
}