import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../tour_mode_state.dart';

Future<void> showRegisterPrompt(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppThemeConstants.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _RegisterPromptSheet(),
  );
}

class _RegisterPromptSheet extends ConsumerWidget {
  const _RegisterPromptSheet();

  void _exitTourAndGo(
      BuildContext context, WidgetRef ref, String route) {
    ref.read(tourModeProvider.notifier).exit();
    Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppThemeConstants.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppThemeConstants.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppThemeConstants.secondary, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'سجّل الآن لحفظ بياناتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppThemeConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'هذه ميزة تتطلب حساباً مسجلاً. أنشئ حساباً مجانياً للاستفادة من جميع الإمكانيات.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppThemeConstants.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      _exitTourAndGo(context, ref, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: AppThemeConstants.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'إنشاء حساب',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => _exitTourAndGo(context, ref, '/login'),
                  child: const Text(
                    'لدي حساب — تسجيل الدخول',
                    style: TextStyle(
                      color: AppThemeConstants.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
