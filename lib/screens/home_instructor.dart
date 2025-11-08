import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';   
import '../providers/auth_provider.dart';

class HomeInstructor extends ConsumerWidget {
  const HomeInstructor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/');               // <-- FIXED
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _statCard('Courses', '12', Icons.book, Colors.blue),
          _statCard('Groups', '36', Icons.group, Colors.green),
          _statCard('Students', '480', Icons.people, Colors.orange),
          _statCard('Assignments', '24', Icons.assignment, Colors.purple),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}