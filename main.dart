import 'package:flutter/material.dart';

import 'models.dart';
import 'mock_data.dart';
import 'widgets.dart';
import 'screens/home_root.dart';

void main() {
  runApp(ElearnApp());
}

class ElearnApp extends StatefulWidget {
  @override
  _ElearnAppState createState() => _ElearnAppState();
}

class _ElearnAppState extends State<ElearnApp> {
  ThemeMode _themeMode = ThemeMode.light;
  String _role = 'student';
  Semester _currentSemester = MockData.semesters.first;

  void toggleRole(String role) {
    setState(() => _role = role);
  }

  void switchSemester(Semester s) {
    setState(() => _currentSemester = s);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng dụng Học tập (Dữ liệu mô phỏng)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: HomeRoot(
        role: _role,
        onRoleChange: toggleRole,
        semester: _currentSemester,
        onSemesterChange: switchSemester,
        onToggleTheme: () => setState(() {
          _themeMode =
              _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
        }),
      ),
    );
  }
}
