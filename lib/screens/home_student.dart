import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ggclassroom/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../screens/calendar_screen.dart';
import '../screens/course_homework_screen.dart';
import '../main.dart';
import '../models/user.dart'; 

final localeProvider = StateProvider<Locale>((ref) => const Locale('vi'));

class HomeStudent extends ConsumerWidget {
  HomeStudent({super.key});

  final List<Map<String, dynamic>> _courses = [
    {
      "id": "c1",
      "title": "Ngữ Văn 11B3",
      "teacher": "Thu Vy Nguyen",
      "cover": "assets/images/web_cover.jpg",
      "avatar": "assets/images/teacher1.jpg",
      "color": Colors.green,
      "startDate": DateTime(2025, 9, 1),
      "endDate": DateTime(2026, 1, 31),
      "schedule": [
        {"day": "Monday", "time": "08:00 - 09:30", "topic": "Văn học dân gian"},
        {"day": "Wednesday", "time": "08:00 - 09:30", "topic": "Tác phẩm Chí Phèo"},
      ],
      "assignments": [
        {
          "title": "[Trắc nghiệm buổi 3] Thao tác lập luận bình luận",
          "due": "16:00 26 thg 2, 2025",
          "score": "8/10",
          "status": "Hoàn thành",
          "desc": "Trắc nghiệm ôn tập thao tác lập luận bình luận. Làm 10 câu trắc nghiệm trong 20 phút.",
          "link": "https://forms.gle/example1",
          "comment": "Làm khá tốt, nhưng cần chú ý ví dụ minh họa rõ hơn."
        },
        {
          "title": "[Trắc nghiệm buổi 2] Đây thôn Vĩ Dạ",
          "due": "23:59 23 thg 2, 2025",
          "score": "9/10",
          "status": "Hoàn thành",
          "desc": "Trắc nghiệm kiến thức bài thơ Đây thôn Vĩ Dạ của Hàn Mặc Tử.",
          "link": "https://forms.gle/example2",
          "comment": "Câu trả lời ngắn gọn và đúng trọng tâm."
        },
      ],
    },
    {
      "id": "c2",
      "title": "Toán 11B3",
      "teacher": "Nguon Tran Thi",
      "cover": "assets/images/db_cover.jpg",
      "avatar": "assets/images/teacher2.jpg",
      "color": Colors.blueGrey,
      "startDate": DateTime(2025, 10, 1),
      "endDate": DateTime(2026, 3, 1),
      "schedule": [
        {"day": "Tuesday", "time": "10:00 - 11:30", "topic": "Hình học không gian"},
        {"day": "Thursday", "time": "10:00 - 11:30", "topic": "Lượng giác"},
      ],
      "assignments": [
        {
          "title": "Bài tập lượng giác chương 3",
          "due": "23:59 5 thg 3, 2025",
          "score": "Chưa nộp",
          "status": "Chưa nộp",
          "desc": "Hoàn thành các bài tập từ trang 45-50 trong sách bài tập Lượng giác.",
          "link": "https://forms.gle/example3",
          "comment": null
        },
        {
          "title": "Ôn tập hình học không gian",
          "due": "18:00 12 thg 3, 2025",
          "score": "9/10",
          "status": "Hoàn thành",
          "desc": "Bài ôn tập khối đa diện và công thức thể tích.",
          "link": "https://forms.gle/example4",
          "comment": "Giải thích hình tốt, trình bày gọn gàng."
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(authProvider)!;

    return Scaffold(
      drawer: _SideMenu(courses: _courses, user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Row(
          children: [
            Icon(Icons.class_, color: Colors.green),
            SizedBox(width: 8),
            Text("Lớp học", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: (locale) => ref.read(localeProvider.notifier).state = locale,
            itemBuilder: (context) => [
              const PopupMenuItem(value: Locale('vi'), child: Text('Tiếng Việt')),
              const PopupMenuItem(value: Locale('en'), child: Text('English')),
            ],
          ),
          IconButton(tooltip: "Tạo hoặc tham gia lớp học", onPressed: () {}, icon: const Icon(Icons.add)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.apps)),
          const SizedBox(width: 4),
          const CircleAvatar(backgroundImage: AssetImage("assets/images/student_avatar.jpg"), radius: 16),
          const SizedBox(width: 12),
        ],
      ),
      body: Container(
        color: const Color(0xFFF7F8FA),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: _courses.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, i) => _CourseCard(course: _courses[i]),
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {},
        child: Column(
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: course["color"],
                image: DecorationImage(
                  image: AssetImage(course['cover']),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course["title"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(course["teacher"], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: CircleAvatar(radius: 20, backgroundImage: AssetImage(course["avatar"])),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.assignment, size: 20),
                    tooltip: "Bài tập của lớp",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CourseHomeworkScreen(course: course)),
                      );
                    },
                  ),
                  const Icon(Icons.folder_open_outlined, size: 20),
                  const Icon(Icons.more_vert, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final AppUser user;
  const _SideMenu({super.key, required this.courses, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 36, backgroundImage: AssetImage("assets/images/student_avatar.jpg")),
                const SizedBox(height: 8),
                Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(user.email, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          _drawerItem(Icons.home_outlined, "Màn hình chính", true),
          _drawerItem(Icons.calendar_today_outlined, "Lịch", false, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen(courses: courses)));
          }),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Việc cần làm'),
            onTap: () {
              context.go('/classwork', extra: courses);
              Navigator.pop(context);
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text("Đã đăng ký"),
            children: courses.map((c) => _drawerItem(Icons.class_outlined, c["title"], false)).toList(),
          ),
          _drawerItem(Icons.archive_outlined, "Lớp học đã lưu trữ", false),
          _drawerItem(Icons.settings_outlined, "Cài đặt", false),
          const Divider(),
          Consumer(
            builder: (context, ref, child) {
              return ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Đăng xuất", style: TextStyle(color: Colors.red)),
                onTap: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, bool selected, {VoidCallback? onTap}) {
    return ListTile(
      selected: selected,
      selectedTileColor: const Color(0xFFE3F2FD),
      leading: Icon(icon, color: selected ? Colors.green : Colors.black54),
      title: Text(title, style: TextStyle(color: selected ? Colors.green : Colors.black87, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      onTap: onTap,
    );
  }
}

class ClassworkScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> courses;
  const ClassworkScreen({super.key, required this.courses});

  @override
  ConsumerState<ClassworkScreen> createState() => _ClassworkScreenState();
}

class _ClassworkScreenState extends ConsumerState<ClassworkScreen> {
  String _selectedFilter = "Tất cả";

  List<Map<String, dynamic>> get _assignments {
    return widget.courses.expand((course) => course["assignments"] as List<Map<String, dynamic>>).toList();
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_selectedFilter == "Tất cả") return _assignments;
    return _assignments.where((a) => a["status"] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider)!; // NOW WORKS — ConsumerStatefulWidget

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Việc cần làm", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(radius: 36, backgroundImage: AssetImage("assets/images/student_avatar.jpg")),
          const SizedBox(height: 8),
          Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: InputDecoration(
                labelText: "Bộ lọc việc cần làm",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredAssignments.length,
              itemBuilder: (context, index) {
                final a = _filteredAssignments[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0.3,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(a["title"], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text("Đến hạn ${a["due"]}"),
                    trailing: Text(a["score"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.assignment_outlined, color: Colors.blueAccent),
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