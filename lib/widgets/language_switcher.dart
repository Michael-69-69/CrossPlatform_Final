// widgets/language_switcher.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; // for localeProvider

/// A compact language switcher button for AppBars
/// Shows current language flag and opens a dialog to switch languages
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return IconButton(
      icon: Text(
        isVietnamese ? '🇻🇳' : '🇺🇸',
        style: const TextStyle(fontSize: 20),
      ),
      tooltip: isVietnamese ? 'Đổi ngôn ngữ' : 'Change language',
      onPressed: () => _showLanguageDialog(context, ref, isVietnamese),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref, bool isVietnamese) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.language, color: Color(0xFF667eea)),
            const SizedBox(width: 12),
            Text(
              isVietnamese ? 'Ngôn ngữ' : 'Language',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context: context,
              ref: ref,
              flag: '🇻🇳',
              name: 'Tiếng Việt',
              locale: const Locale('vi'),
              isSelected: isVietnamese,
            ),
            const SizedBox(height: 8),
            _buildLanguageOption(
              context: context,
              ref: ref,
              flag: '🇺🇸',
              name: 'English',
              locale: const Locale('en'),
              isSelected: !isVietnamese,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String flag,
    required String name,
    required Locale locale,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(localeProvider.notifier).state = locale;
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667eea).withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF667eea) : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF667eea)),
          ],
        ),
      ),
    );
  }
}

/// A language toggle widget for settings/profile screens
/// Shows both language options side by side
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale('vi');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isVietnamese ? const Color(0xFF667eea) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Tiếng Việt',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isVietnamese ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale('en');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isVietnamese ? const Color(0xFF667eea) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇺🇸', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'English',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: !isVietnamese ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
