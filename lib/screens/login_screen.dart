// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'nam@gmail.com');
  final _passCtrl = TextEditingController(text: '123');
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  bool _isRegister = false;
  UserRole _role = UserRole.student;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GGClassroom')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.school, size: 80, color: Colors.green),
              const Text('GGClassroom', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              if (_isRegister) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              if (_isRegister) ...[
                const SizedBox(height: 20),
                const Text("Vai trò:", style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<UserRole>(
                  title: const Text("Học sinh"),
                  value: UserRole.student,
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v!),
                ),
                RadioListTile<UserRole>(
                  title: const Text("Giảng viên"),
                  value: UserRole.instructor,
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v!),
                ),
              ],

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: _loading ? null : () async {
                  setState(() => _loading = true);
                  try {
                    if (_isRegister) {
                      await ref.read(authProvider.notifier).register(
                        email: _emailCtrl.text.trim(),
                        password: _passCtrl.text,
                        name: _nameCtrl.text.trim(),
                        role: _role,
                      );
                    } else {
                      await ref.read(authProvider.notifier).login(
                        _emailCtrl.text.trim(),
                        _passCtrl.text,
                      );
                    }
                    context.go('/home');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                    );
                  } finally {
                    setState(() => _loading = false);
                  }
                },
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isRegister ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP'),
              ),

              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký'),
              ),

              const SizedBox(height: 20),
              const Text(
                'Demo:\nnam@gmail.com / 123 → Student\nadmin@tdtu.edu.vn / admin → Instructor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}