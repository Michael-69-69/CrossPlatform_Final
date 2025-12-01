// lib/widgets/language_toggle.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; // for localeProvider

class LanguageToggle extends ConsumerWidget {
  final bool showLabel;
  
  const LanguageToggle({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';
    
    return IconButton(
      icon: Text(
        isVietnamese ? '🇻🇳' : '🇺🇸',
        style: const TextStyle(fontSize: 24),
      ),
      tooltip: isVietnamese ? 'Switch to English' : 'Chuyển sang Tiếng Việt',
      onPressed: () {
        ref.read(localeProvider.notifier).state = 
            isVietnamese ? const Locale('en') : const Locale('vi');
      },
    );
  }
}