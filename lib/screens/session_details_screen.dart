import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/session_model.dart';
import '../models/quran_mistake_model.dart';

import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import '../shared/widgets/interactive_quran_page.dart';
import 'rate_session_screen.dart';

class SessionDetailsScreen extends ConsumerStatefulWidget {
  final SessionModel session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends ConsumerState<SessionDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isMohaffez = currentUser?.role == 'mohaffez';
    final isStudent = currentUser?.role == 'student';
    final session = widget.session;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with Gradient
            SliverAppBar(
              expandedHeight: 130,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Hero(
                                tag: 'session_${session.id}',
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMohaffez
                                          ? session.studentName
                                          : session.mohaffezName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getStatusLabel(session.status ?? ''),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // Session Info Card
                    _SectionCard(
                      title: 'معلومات الجلسة',
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.event,
                            label: 'النوع',
                            value: _getSessionTypeLabel(session.sessionType),
                          ),
                          const Divider(height: 24),
                          if (session.preferredTimeSlot != null)
                            _InfoRow(
                              icon: Icons.access_time,
                              label: 'الوقت',
                              value: session.preferredTimeSlot!,
                            ),
                          if (session.sessionDate != null) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'التاريخ',
                              value: DateFormat('dd MMMM yyyy', 'ar')
                                  .format(session.sessionDate!),
                            ),
                          ],
                          if (session.location.isNotEmpty) ...[
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.location_on,
                              label: 'المكان',
                              value: session.location,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Assignments Section
                    if ((session.hifzAssignment?.isNotEmpty ?? false) ||
                        (session.murajaAssignment?.isNotEmpty ?? false))
                      _SectionCard(
                        title: 'الواجبات',
                        icon: Icons.assignment,
                        color: AppTheme.accentGreen,
                        child: Column(
                          children: [
                            if (session.hifzAssignment?.isNotEmpty ?? false)
                              _AssignmentCard(
                                title: 'حفظ',
                                content: session.hifzAssignment!,
                                color: Colors.green,
                                icon: Icons.book,
                              ),
                            if ((session.hifzAssignment?.isNotEmpty ?? false) &&
                                (session.murajaAssignment?.isNotEmpty ?? false))
                              const SizedBox(height: 12),
                            if (session.murajaAssignment?.isNotEmpty ?? false)
                              _AssignmentCard(
                                title: 'مراجعة',
                                content: session.murajaAssignment!,
                                color: Colors.blue,
                                icon: Icons.refresh,
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Rating Section
                    if (session.sessionRating > 0)
                      _SectionCard(
                        title: 'التقييم',
                        icon: Icons.star,
                        color: Colors.amber,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${session.sessionRating}/10',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(10, (index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: Icon(
                                    index < session.sessionRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Performance notes
                    if (session.performanceNotes?.isNotEmpty ?? false)
                      _SectionCard(
                        title: 'ملاحظات على التكليف السابق',
                        icon: Icons.fact_check,
                        color: Colors.teal,
                        child: Text(
                          session.performanceNotes!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Notes Section
                    if (session.sessionNotes?.isNotEmpty ?? false)
                      _SectionCard(
                        title: 'ملاحظات',
                        icon: Icons.notes,
                        color: Colors.purple,
                        child: Text(
                          session.sessionNotes!,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ✅ Quran mistakes section
                    if (session.mistakes.isNotEmpty)
                      _SectionCard(
                        title: 'الأخطاء على المصحف',
                        icon: Icons.menu_book,
                        color: AppTheme.accentGreen,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary
                            Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'تم تسجيل ${session.mistakes.length} خطأ في هذه الجلسة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Grouped by page
                            ...session.mistakesByPage.entries.map((entry) {
                              final page = entry.key;
                              final mistakes = entry.value;
                              return ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                    'صفحة $page (${mistakes.length} أخطاء)'),
                                children: mistakes.map((m) {
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor: _mistakeColor(m.type),
                                      child: Icon(
                                        _mistakeIcon(m.type),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                        'آية ${m.ayahNumber} - ${_getMistakeLabel(m.type)}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (m.wordText != null)
                                          Text(
                                            m.wordText!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        if (m.correctionNote != null)
                                          Text(
                                            m.correctionNote!,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text(
                                              'عرض الأخطاء على المصحف'),
                                        ),
                                        body: InteractiveQuranPage(
                                          pageNumber:
                                              session.mistakes.first.pageNumber,
                                          existingMistakes: session.mistakes,
                                          onMistakeAdded: (_) {},
                                          isEditable: false,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.book),
                                label: const Text('عرض على المصحف'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Action Buttons
        bottomNavigationBar: _buildBottomNavigationBar(
          isMohaffez: isMohaffez,
          isStudent: isStudent,
          session: session,
        ),
      ),
    );
  }

  // ==========================================================================
  // BOTTOM NAVIGATION BAR BUILDER
  // ==========================================================================
  Widget? _buildBottomNavigationBar({
    required bool isMohaffez,
    required bool isStudent,
    required SessionModel session,
  }) {
    // Mohaffez: Show complete session button
    if (isMohaffez && session.status == 'accepted') {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to completion screen
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('إنهاء الجلسة'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: AppTheme.accentGreen,
                      width: 2,
                    ),
                    foregroundColor: AppTheme.accentGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Edit assignment
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل الواجب'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryAmber,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Student: Show cancel button for accepted sessions that haven't happened yet
    if (isStudent && 
        session.status == 'accepted' && 
        session.sessionDate != null &&
        session.sessionDate!.isAfter(DateTime.now())) {
      final hoursUntil = session.sessionDate!.difference(DateTime.now()).inHours;
      
      // Calculate refund policy
      String refundPolicy;
      Color policyColor;
      if (hoursUntil > 24) {
        refundPolicy = '✅ استرداد كامل';
        policyColor = Colors.green;
      } else if (hoursUntil > 2) {
        refundPolicy = '⚠️ استرداد 50%';
        policyColor = Colors.orange;
      } else {
        refundPolicy = '❌ لا استرداد';
        policyColor = Colors.red;
      }
      
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refund policy warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: policyColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: policyColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'سياسة الإلغاء: $refundPolicy',
                    style: TextStyle(color: policyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            // Cancel button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showCancellationDialog(session, refundPolicy),
                icon: const Icon(Icons.cancel),
                label: const Text('إلغاء الجلسة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Student: Show rating button for completed sessions that haven't been rated
    if (isStudent && 
        session.status == 'completed' &&
        (session.sessionRating == null || session.sessionRating == 0)) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _navigateToRating(session),
            icon: const Icon(Icons.star, color: Colors.white),
            label: const Text('قيّم الجلسة', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      );
    }

    return null;
  }

  // ==========================================================================
  // CANCELLATION DIALOG
  // ==========================================================================
  Future<void> _showCancellationDialog(SessionModel session, [String? precalculatedRefundPolicy]) async {
    final hoursUntilSession = 
        session.sessionDate!.difference(DateTime.now()).inHours;
    
    String refundPolicy;
    Color policyColor;
    
    if (hoursUntilSession > 24) {
      refundPolicy = '✅ استرداد كامل المبلغ';
      policyColor = Colors.green;
    } else if (hoursUntilSession > 2) {
      refundPolicy = '⚠️ استرداد 50% من المبلغ';
      policyColor = Colors.orange;
    } else {
      refundPolicy = '❌ لا يمكن الاسترداد';
      policyColor = Colors.red;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد الإلغاء'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'هل تريد إلغاء هذه الجلسة؟',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: policyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: policyColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: policyColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        refundPolicy,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: policyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('نعم، إلغاء الجلسة'),
            ),
          ],
        ),
      ),
    );
    
    if (confirmed != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري إلغاء الجلسة...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      final sessionId = session.id;
      if (sessionId == null) {
        throw Exception('معرف الجلسة غير متاح');
      }
      
      await ref.read(sessionActionsProvider.notifier)
        .cancelSession(sessionId);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close details screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الجلسة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // NAVIGATE TO RATING
  // ==========================================================================
  Future<void> _navigateToRating(SessionModel session) async {
    final sessionId = session.id;
    if (sessionId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('معرف الجلسة غير متاح'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RateSessionScreen(
          sessionId: sessionId,
          mohaffezName: session.mohaffezName,
        ),
      ),
    );
    
    if (result == true && mounted) {
      // Refresh the current session details
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شكراً لتقييمك!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'مقبولة';
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return status;
    }
  }

  String _getSessionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return 'في المنزل';
      case 'mosque':
        return 'في المسجد';
      case 'online':
        return 'عن بُعد';
      default:
        return type;
    }
  }

  // Helper to avoid ambiguous extension
  String _getMistakeLabel(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return 'خطأ تجويد';
      case MistakeType.pronunciation:
        return 'خطأ نطق';
      case MistakeType.reading:
        return 'قراءة خاطئة';
      case MistakeType.skip:
        return 'تجاوز';
      case MistakeType.addition:
        return 'زيادة';
      case MistakeType.other:
        return 'أخرى';
      default:  // ✅ ADD THIS
        return 'غير محدد';
    }
  }

  Color _mistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return Colors.orange;
      case MistakeType.pronunciation:
        return Colors.red;
      case MistakeType.reading:
        return Colors.purple;
      case MistakeType.skip:
        return Colors.blue;
      case MistakeType.addition:
        return Colors.green;
      case MistakeType.other:
        return Colors.grey;
      default:  // ✅ ADD THIS
        return Colors.grey;
    }
  }

  IconData _mistakeIcon(MistakeType type) {
    switch (type) {
      case MistakeType.tajweed:
        return Icons.auto_fix_high;
      case MistakeType.pronunciation:
        return Icons.record_voice_over;
      case MistakeType.reading:
        return Icons.error_outline;
      case MistakeType.skip:
        return Icons.fast_forward;
      case MistakeType.addition:
        return Icons.add_circle_outline;
      case MistakeType.other:
        return Icons.help_outline;
      default:  // ✅ ADD THIS
        return Icons.help_outline;

    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final IconData icon;

  const _AssignmentCard({
    required this.title,
    required this.content,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
