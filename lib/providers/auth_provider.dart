import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier() : super(null);

  void login(String email, String password) {
    if (email == 'admin' && password == 'admin') {
      state = AppUser(
        id: '1',
        name: 'Administrator',
        email: 'admin@it.edu',
        role: UserRole.instructor,
      );
    } else {
      state = AppUser(
        id: '2',
        name: email.split('@').first.replaceFirst('.', ' '),
        email: email,
        role: UserRole.student,
      );
    }
  }

  void logout() => state = null;
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  return AuthNotifier();
});