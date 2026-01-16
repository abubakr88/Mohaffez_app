import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider_paginated.dart';
import '../providers/user_provider.dart';

class StudentAssignmentsScreen extends ConsumerWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('الرجاء تسجيل الدخول')),
          );
        }
        return _AssignmentsContent(studentId: user.uid);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

class _AssignmentsContent extends ConsumerStatefulWidget {
  final String studentId;

  const _AssignmentsContent({required this.studentId});

  @override
  ConsumerState<_AssignmentsContent> createState() => _AssignmentsContentState();
}

class _AssignmentsContentState extends ConsumerState<_AssignmentsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(widget.studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with Tabs
            SliverAppBar(
              expandedHeight: 160,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accentGreen, Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.assignment,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'واجباتي',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.accentGreen,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: AppTheme.accentGreen,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.pending_actions, size: 20),
                        text: 'قيد الإنجاز',
                      ),
                      Tab(
                        icon: Icon(Icons.check_circle, size: 20),
                        text: 'مكتملة',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tab Content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Assignments
                  sessionsAsync.when(
                    data: (sessions) {
                      final activeSessions = sessions
                          .where((s) =>
                              (s['status'] as String?) == 'accepted' &&
                              ((s['hifzAssignment'] as String?)?.isNotEmpty == true ||
                              (s['murajaAssignment'] as String?)?.isNotEmpty == true))
                          .toList();

                      if (activeSessions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'لا توجد واجبات حالية',
                          message: 'ستظهر واجباتك النشطة هنا',
                          animated: true,
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(studentSessionsFirstPageProvider(widget.studentId));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: activeSessions.length,
                          itemBuilder: (context, index) {
                            return _ActiveAssignmentCard(
                              session: activeSessions[index],
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorDisplay.dataLoad(
                      onRetry: () => ref.invalidate(
                        studentSessionsFirstPageProvider(widget.studentId),
                      ),
                    ),
                  ),

                  // Completed Assignments
                  sessionsAsync.when(
                    data: (sessions) {
                      final completedSessions = sessions
                          .where((s) =>
                              (s['status'] as String?) == 'completed')
                          .toList();

                      if (completedSessions.isEmpty) {
                        return const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'لا توجد واجبات مكتملة',
                          message: 'أكمل واجباتك لتظهر هنا',
                          animated: true,
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: completedSessions.length,
                        itemBuilder: (context, index) {
                          return _CompletedAssignmentCard(
                            session: completedSessions[index],
                            studentId: widget.studentId,
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorDisplay.dataLoad(
                      onRetry: () => ref.invalidate(
                        studentSessionsFirstPageProvider(widget.studentId),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAssignmentCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _ActiveAssignmentCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = session['mohaffezName'] as String? ?? 'محفظ';
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to session details
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: AppTheme.accentGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mohaffezName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (sessionDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy', 'ar').format(sessionDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'قيد الإنجاز',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Assignments
              if (hifz.isNotEmpty)
                _AssignmentItem(
                  icon: Icons.book,
                  label: 'حفظ',
                  content: hifz,
                  color: Colors.green,
                ),
              if (hifz.isNotEmpty && muraja.isNotEmpty)
                const SizedBox(height: 12),
              if (muraja.isNotEmpty)
                _AssignmentItem(
                  icon: Icons.refresh,
                  label: 'مراجعة',
                  content: muraja,
                  color: Colors.blue,
                ),

              const SizedBox(height: 16),

              // Progress Indicator
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.grey.shade200,
                      color: AppTheme.accentGreen,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '60%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedAssignmentCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  final String studentId;

  const _CompletedAssignmentCard({
    required this.session,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mohaffezName = session['mohaffezName'] as String? ?? 'محفظ';
    final hifz = session['hifzAssignment'] as String? ?? '';
    final muraja = session['murajaAssignment'] as String? ?? '';
    final rating = session['sessionRating'] as int? ?? 5;  // ✅ Default to 5
    final notes = session['sessionNotes'] as String? ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;
    final sessionId = session['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mohaffezName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sessionDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy', 'ar').format(sessionDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Assignments
            if (hifz.isNotEmpty)
              _CompletedAssignmentItem(
                icon: Icons.book,
                label: 'حفظ',
                content: hifz,
              ),
            if (hifz.isNotEmpty && muraja.isNotEmpty)
              const Divider(height: 24),
            if (muraja.isNotEmpty)
              _CompletedAssignmentItem(
                icon: Icons.refresh,
                label: 'مراجعة',
                content: muraja,
              ),

            const Divider(height: 24),

            // Rating Section - ✅ UPDATED
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'التقييم: $rating/10',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < (rating / 2).round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  // ✅ ADD RATE BUTTON if rating is default (5) and student hasn't rated
                  if (rating == 5 && notes.isEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showRatingDialog(context, ref, sessionId, mohaffezName);
                        },
                        icon: const Icon(Icons.star),
                        label: const Text('قيّم المحفظ'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.amber, width: 2),
                          foregroundColor: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'ملاحظات المحفظ:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notes,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ NEW METHOD: Show rating dialog
  void _showRatingDialog(
    BuildContext context,
    WidgetRef ref,
    String sessionId,
    String mohaffezName,
  ) {
    int rating = 5;  // Default to 5
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تقييم المحفظ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mohaffez Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, color: AppTheme.accentGreen),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mohaffezName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Rating Stars
                  const Text(
                    'تقييمك للجلسة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(10, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              rating = index + 1;
                            });
                          },
                          child: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$rating / 10',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notes
                  const Text(
                    'ملاحظاتك (اختياري)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'شاركنا رأيك حول الجلسة...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(sessionActionsProvider.notifier).updateAssignment(
                      sessionId: sessionId,
                      rating: rating,
                      notes: notesController.text.trim(),
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إرسال التقييم بنجاح'),
                          backgroundColor: AppTheme.accentGreen,
                        ),
                      );
                      ref.invalidate(studentSessionsFirstPageProvider(studentId));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('خطأ: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('إرسال التقييم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAmber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;
  final Color color;

  const _AssignmentItem({
    required this.icon,
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedAssignmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;

  const _CompletedAssignmentItem({
    required this.icon,
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
