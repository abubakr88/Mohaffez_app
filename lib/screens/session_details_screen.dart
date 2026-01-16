import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/session_model.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';

class SessionDetailsScreen extends ConsumerWidget {
  final SessionModel session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isMohaffez = currentUser?.role == 'mohaffez';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with Gradient
            SliverAppBar(
              expandedHeight: 120,
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
                                        _getStatusLabel(session.status!),
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
                delegate: SliverChildListDelegate([
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
                  if (session.hifzAssignment?.isNotEmpty ?? false ||
                      (session.hifzAssignment?.isNotEmpty ?? false) == true)
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
                          if (session.hifzAssignment?.isNotEmpty ?? false &&
                              (session.murajaAssignment?.isNotEmpty ?? false) == true)
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
                                padding: const EdgeInsets.symmetric(horizontal: 2),
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

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),

        // Action Buttons (for mohaffez only)
        bottomNavigationBar: isMohaffez && session.status == 'accepted'
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Complete session
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
              )
            : null,
      ),
    );
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
