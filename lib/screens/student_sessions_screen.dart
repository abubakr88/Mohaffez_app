// FILE: lib/screens/student_sessions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';

/// Dedicated screen for viewing and managing confirmed/booked sessions
class StudentSessionsScreen extends ConsumerStatefulWidget {
  const StudentSessionsScreen({super.key});

  @override
  ConsumerState<StudentSessionsScreen> createState() => _StudentSessionsScreenState();
}

class _StudentSessionsScreenState extends ConsumerState<StudentSessionsScreen> {
  String selectedFilter = 'all'; // all, upcoming, completed

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(user.uid));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // App Bar
            _buildAppBar(),
            
            // Filter Chips
            SliverToBoxAdapter(
              child: _buildFilterChips(),
            ),
            
            // Sessions List
            sessionsAsync.when(
              data: (sessions) {
                var filteredSessions = sessions.where((s) {
                  final status = (s['status'] as String?)?.toLowerCase();
                  return status == 'accepted';
                }).toList();

                // Apply additional filters
                if (selectedFilter == 'upcoming') {
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  filteredSessions = filteredSessions.where((s) {
                    final date = s['sessionDate'] as DateTime?;
                    return date != null && !date.isBefore(todayStart);
                  }).toList();
                } else if (selectedFilter == 'completed') {
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  filteredSessions = filteredSessions.where((s) {
                    final date = s['sessionDate'] as DateTime?;
                    return date != null && date.isBefore(todayStart);
                  }).toList();
                }

                if (filteredSessions.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.event_busy,
                      title: 'لا توجد جلسات',
                      message: 'لم يتم حجز أي جلسات بعد',
                      animated: true,
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = filteredSessions[index];
                        return _SessionCard(session: session);
                      },
                      childCount: filteredSessions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('حدث خطأ: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppThemeConstants.accentGreen,
                Color(0xFF66BB6A),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_available,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جلساتي',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'إدارة الجلسات المؤكدة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
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
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'الكل',
              icon: Icons.all_inclusive,
              isSelected: selectedFilter == 'all',
              onTap: () => setState(() => selectedFilter = 'all'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'القادمة',
              icon: Icons.upcoming,
              isSelected: selectedFilter == 'upcoming',
              onTap: () => setState(() => selectedFilter = 'upcoming'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'المنتهية',
              icon: Icons.history,
              isSelected: selectedFilter == 'completed',
              onTap: () => setState(() => selectedFilter = 'completed'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeConstants.accentGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppThemeConstants.accentGreen
                : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeConstants.accentGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final mohaffezName = (session['mohaffezName'] as String?) ?? 'محفظ';
    final sessionType = (session['sessionType'] as String?) ?? 'home';
    final location = (session['imamAddressText'] as String?) ?? '';
    final timeSlot = (session['preferredTimeSlot'] as String?) ?? '';
    final sessionDate = session['sessionDate'] as DateTime?;
    final hifz = (session['hifzAssignment'] as String?) ?? '';
    final muraja = (session['murajaAssignment'] as String?) ?? '';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isUpcoming = sessionDate != null && !sessionDate.isBefore(todayStart);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isUpcoming ? AppThemeConstants.accentGreen.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to session details if needed
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppThemeConstants.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 24,
                      color: AppThemeConstants.accentGreen,
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
                        Text(
                          _getSessionTypeLabel(sessionType),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'قادمة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.accentGreen,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Details
              if (sessionDate != null)
                _DetailRow(
                  icon: Icons.calendar_today,
                  text: DateFormat('EEEE، d MMMM yyyy', 'ar').format(sessionDate),
                ),
              if (timeSlot.isNotEmpty)
                _DetailRow(
                  icon: Icons.access_time,
                  text: timeSlot,
                ),
              if (location.isNotEmpty)
                _DetailRow(
                  icon: Icons.location_on,
                  text: location,
                ),
              
              // Assignments
              if (hifz.isNotEmpty || muraja.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (hifz.isNotEmpty)
                  _AssignmentChip(label: 'حفظ', text: hifz, color: Colors.green),
                if (muraja.isNotEmpty)
                  _AssignmentChip(label: 'مراجعة', text: muraja, color: Colors.blue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSessionTypeLabel(String type) {
    switch (type) {
      case 'home':
        return 'جلسة منزلية';
      case 'mosque':
        return 'جلسة في المسجد';
      case 'online':
        return 'جلسة أونلاين';
      default:
        return type;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentChip extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AssignmentChip({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
