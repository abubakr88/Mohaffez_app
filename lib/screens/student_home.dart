import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'nearby_mohaffez_screen.dart';
import 'accepted_sessions_screen.dart';
import 'student_assignments_screen.dart';
import 'student_requests_screen.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/error_widgets.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  Position? currentPosition;
  bool loadingLocation = false;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      loadingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خدمة تحديد الموقع غير مفعلة'),
            ),
          );
        }
        setState(() {
          loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          setState(() {
            loadingLocation = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        currentPosition = position;
        loadingLocation = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      setState(() {
        loadingLocation = false;
      });
    }
  }

@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ابحث واحجز',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          context: context,
          icon: Icons.search_rounded,
          title: 'ابحث عن محفظ قريب',
          subtitle: 'اعثر على محفظ في منطقتك',
          color: AppTheme.primaryAmber,
          onTap: () {
            if (currentPosition == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('جاري الحصول على موقعك، برجاء المحاولة لاحقًا'),
                ),
              );
              return;
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NearbyMohaffezScreen(
                  userLat: currentPosition!.latitude,
                  userLng: currentPosition!.longitude,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'جلساتي وتكليفاتي',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context: context,
          icon: Icons.event_available_rounded,
          title: 'جلساتي المقبولة',
          subtitle: 'عرض الجلسات المؤكدة',
          color: AppTheme.accentGreen,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AcceptedSessionsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context: context,
          icon: Icons.assignment_rounded,
          title: 'تكليفات الحفظ والمراجعة',
          subtitle: 'ورد الحفظ والمراجعة والتقييمات',
          color: AppTheme.warning,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StudentAssignmentsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context: context,
          icon: Icons.pending_actions_rounded,
          title: 'طلبات الجلسات',
          subtitle: 'تتبع حالة طلباتك',
          color: Colors.blueAccent,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StudentRequestsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16), // Add some bottom padding
      ],
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

  Widget buildLatestSessions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('sessionDate')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),

                // Warning banner if location is not enabled
                if (currentPosition == null && !loadingLocation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: WarningBanner(
                      message: 'تفعيل الموقع سيساعدك في العثور على محفظين قريبين',
                      actionLabel: 'تفعيل',
                      onAction: getCurrentLocation,
                    ),
                  ),
                Text(
                  'لا توجد جلسات اليوم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابحث عن محفظ قريب لحجز جلسة',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final location = data['location'] as String? ?? '';
            final juzCount = data['juzCount'] as int? ?? 1;
            final ts = data['sessionDate'] as Timestamp?;
            final date = ts?.toDate();
            final dateStr = date != null
                ? '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
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
                title: Text(location),
                subtitle: Text('أجزاء: $juzCount - $dateStr'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
