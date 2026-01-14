// lib/screens/student_home.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider_paginated.dart';
import 'nearby_mohaffez_screen.dart';
import 'accepted_sessions_screen.dart';
import 'student_assignments_screen.dart';

class StudentHome extends ConsumerWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('لم يتم تسجيل الدخول')),
          );
        }
        return StudentHomeContent(studentId: user.uid);
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

class StudentHomeContent extends ConsumerWidget {
  final String studentId;

  const StudentHomeContent({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome section
          _buildWelcomeSection(ref),
          const SizedBox(height: 24),
          
          // Quick stats
          _buildQuickStats(ref),
          const SizedBox(height: 24),
          
          // Recent assignments
          _buildRecentAssignments(ref),
          const SizedBox(height: 24),
          
          // Quick actions
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.waving_hand, size: 40, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مرحباً',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickStats(WidgetRef ref) {
    // ✅ FIXED: Use studentSessionsFirstPageProvider instead of undefined studentSessionsProvider
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));
    final requestsAsync = ref.watch(studentRequestsFirstPageProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات سريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Accepted Sessions
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) {
                  final acceptedCount = sessions
                      .where((s) => (s['status'] as String? ?? '') == 'accepted')
                      .length;
                  return _buildStatCard(
                    icon: Icons.event_available,
                    title: 'جلسات مقبولة',
                    value: acceptedCount.toString(),
                    color: AppTheme.accentGreen,
                    onTap: () {
                      Navigator.of(ref.context).push(
                        MaterialPageRoute(
                          builder: (_) => const AcceptedSessionsScreen(),
                        ),
                      );
                    },
                  );
                },
                loading: () => _buildStatCard(
                  icon: Icons.event_available,
                  title: 'جلسات مقبولة',
                  value: '...',
                  color: AppTheme.accentGreen,
                  onTap: () {},
                ),
                error: (_, __) => _buildStatCard(
                  icon: Icons.event_available,
                  title: 'جلسات مقبولة',
                  value: '0',
                  color: AppTheme.accentGreen,
                  onTap: () {},
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Pending Requests
            Expanded(
              child: requestsAsync.when(
                data: (requests) {
                  final pendingCount = requests
                      .where((r) => (r['status'] as String? ?? '') == 'pending')
                      .length;
                  return _buildStatCard(
                    icon: Icons.pending_actions,
                    title: 'طلبات قيد الانتظار',
                    value: pendingCount.toString(),
                    color: Colors.orange,
                    onTap: () {}, // Navigate to requests screen if needed
                  );
                },
                loading: () => _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'طلبات قيد الانتظار',
                  value: '...',
                  color: Colors.orange,
                  onTap: () {},
                ),
                error: (_, __) => _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'طلبات قيد الانتظار',
                  value: '0',
                  color: Colors.orange,
                  onTap: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: color),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAssignments(WidgetRef ref) {
    // ✅ FIXED: Use correct provider
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(studentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'الواجبات الأخيرة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.of(ref.context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudentAssignmentsScreen(),
                  ),
                );
              },
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        sessionsAsync.when(
          data: (sessions) {
            final assignmentSessions = sessions.where((s) {
              final hifz = s['hifzAssignment'] as String? ?? '';
              final muraja = s['murajaAssignment'] as String? ?? '';
              return hifz.isNotEmpty || muraja.isNotEmpty;
            }).take(3).toList();

            if (assignmentSessions.isEmpty) {
              return const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'لا توجد واجبات',
                message: 'جميع الواجبات ستظهر هنا',
                animated: false,
              );
            }

            return Column(
              children: assignmentSessions.map((session) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryAmber.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.assignment,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                    title: Text(session['mohaffezName'] as String? ?? 'غير معروف'),
                    subtitle: Text(
                      session['hifzAssignment'] as String? ?? 
                      session['murajaAssignment'] as String? ?? 
                      '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const EmptyState(
            icon: Icons.error_outline,
            title: 'حدث خطأ',
            message: 'تعذر تحميل الواجبات',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NearbyMohaffezScreen(),
                ),
              );
            },
            icon: const Icon(Icons.search),
            label: const Text('البحث عن محفظ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
