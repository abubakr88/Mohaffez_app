import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'nearby_mohaffez_screen.dart';
import 'accepted_sessions_screen.dart';
import 'student_assignments_screen.dart';
import 'student_requests_screen.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';
import '../providers/session_provider.dart';
import '../providers/user_provider.dart';

// Location provider
final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  } catch (e) {
    return null;
  }
});

class StudentHome extends ConsumerWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(userLocationProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مرحباً بك',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          _buildSearchCard(context, ref, locationAsync),
          const SizedBox(height: 24),
          Text(
            'إدارة الجلسات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.event_available_rounded,
            title: 'الجلسات المقبولة',
            subtitle: 'عرض جلساتك المحجوزة',
            color: AppTheme.accentGreen,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AcceptedSessionsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.assignment_rounded,
            title: 'التكليفات',
            subtitle: 'مراجعة تكليفاتك',
            color: AppTheme.warning,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.pending_actions_rounded,
            title: 'طلباتي',
            subtitle: 'متابعة حالة الطلبات',
            color: Colors.blueAccent,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StudentRequestsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _buildUpcomingSessions(ref),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSearchCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Position?> locationAsync,
  ) {
    return locationAsync.when(
      data: (position) {
        if (position == null) {
          return WarningBanner(
            message: 'يرجى تفعيل خدمات الموقع للبحث عن محفظين قريبين',
            actionLabel: 'تحديث',
            onAction: () => ref.invalidate(userLocationProvider),
          );
        }

        return _buildActionCard(
          context: context,
          icon: Icons.search_rounded,
          title: 'ابحث عن محفظ قريب',
          subtitle: 'اعثر على أفضل محفظ في منطقتك',
          color: AppTheme.primaryAmber,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NearbyMohaffezScreen(
                userLat: position.latitude,
                userLng: position.longitude,
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, _) => WarningBanner(
        message: 'تعذر الحصول على موقعك. يرجى التحقق من الأذونات.',
        actionLabel: 'إعادة المحاولة',
        onAction: () => ref.invalidate(userLocationProvider),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSessions(WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final sessionsAsync = ref.watch(studentSessionsProvider(user.uid));

        return sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) return const SizedBox.shrink();

            // Get upcoming sessions (next 3)
            final now = DateTime.now();
            final upcoming = sessions
                .where((s) {
                  final date = s.sessionDate ?? s.slotStart;
                  return date != null && date.isAfter(now);
                })
                .take(3)
                .toList();

            if (upcoming.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الجلسات القادمة',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...upcoming.map((session) {
                  final date = session.sessionDate ?? session.slotStart;
                  final dateStr = date != null
                      ? '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                      : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryAmber.withOpacity(0.2),
                        child: const Icon(
                          Icons.school,
                          color: AppTheme.primaryAmber,
                        ),
                      ),
                      title: Text(session.location),
                      subtitle: Text(
                          '${session.juzCount} جزء - $dateStr'),
                    ),
                  );
                }).toList(),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
