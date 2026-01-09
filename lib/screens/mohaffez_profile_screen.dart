import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/availability_calendar_widget.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';
import '../shared/constants/schedule_constants.dart';
import '../shared/utils/location_utils.dart';
import '../providers/user_provider.dart';
import '../providers/session_provider.dart';
import '../services/follow_service.dart';
import '../shared/utils/error_handler.dart';

// Provider for mohaffez profile data
final mohaffezProfileProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, mohaffezId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .get();

    if (!doc.exists) {
      throw Exception('المحفظ غير موجود');
    }

    return {
      ...doc.data()!,
      'uid': doc.id,
    };
  },
);

// Provider for follow status
final followStatusProvider = StreamProvider.family<bool, String>(
  (ref, mohaffezId) async* {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      yield false;
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('follows')
        .where('studentId', isEqualTo: currentUser.uid)
        .where('mohaffezId', isEqualTo: mohaffezId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  },
);

// Provider for credentials
final credentialsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .collection('credentials')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList());
  },
);

class MohaffezProfileScreen extends ConsumerStatefulWidget {
  final String mohaffezId;
  final double? userLat;
  final double? userLng;

  const MohaffezProfileScreen({
    super.key,
    required this.mohaffezId,
    this.userLat,
    this.userLng,
  });

  @override
  ConsumerState<MohaffezProfileScreen> createState() => _MohaffezProfileScreenState();
}

class _MohaffezProfileScreenState extends ConsumerState<MohaffezProfileScreen> {
  bool _isFollowing = false;
  bool _loadingFollow = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final followStatusAsync = ref.watch(followStatusProvider(widget.mohaffezId));

    // Update local follow state
    followStatusAsync.whenData((isFollowing) {
      if (_isFollowing != isFollowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isFollowing = isFollowing);
          }
        });
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: profileAsync.when(
          data: (profile) => _buildContent(profile),
          loading: () => _buildLoadingSkeleton(),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(mohaffezProfileProvider(widget.mohaffezId)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            ShimmerWidgets.profile(),
          ]),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> profile) {
    final name = profile['name'] as String? ?? 'بدون اسم';
    final photoUrl = profile['photoUrl'] as String?;
    final bio = profile['bio'] as String?;
    final specialization = profile['specialization'] as String?;
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
    final followerCount = profile['followerCount'] as int? ?? 0;
    final addressText = profile['addressText'] as String?;
    final addressLat = profile['addressLat'] as double?;
    final addressLng = profile['addressLng'] as double?;
    final phoneNumber = profile['phoneNumber'] as String?;

    // Calculate distance if user location is available
    String? distanceText;
    if (widget.userLat != null &&
        widget.userLng != null &&
        addressLat != null &&
        addressLng != null) {
      final distance = LocationUtils.calculateDistance(
        widget.userLat!,
        widget.userLng!,
        addressLat,
        addressLng,
      );
      distanceText = distance < 1
          ? '${(distance * 1000).round()} م'
          : '${distance.toStringAsFixed(1)} كم';
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(name, photoUrl),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            _buildHeader(name, specialization, rating, followerCount, distanceText),
            const SizedBox(height: 16),
            if (bio != null && bio.isNotEmpty) ...[
              _buildBioCard(bio),
              const SizedBox(height: 16),
            ],
            _buildLocationCard(addressText, addressLat, addressLng),
            const SizedBox(height: 16),
            _buildCredentialsSection(),
            const SizedBox(height: 16),
            _buildAvailabilitySection(),
            const SizedBox(height: 16),
            _buildActionButtons(phoneNumber),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }

  Widget _buildAppBar(String name, String? photoUrl) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  CachedAvatar(
                    imageUrl: photoUrl,
                    radius: 50,
                    semanticLabel: 'صورة $name',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String name,
    String? specialization,
    double rating,
    int followerCount,
    String? distance,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (specialization != null && specialization.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              specialization,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.star,
                label: 'التقييم',
                value: rating.toStringAsFixed(1),
                color: Colors.amber,
              ),
              _buildStatItem(
                icon: Icons.people,
                label: 'المتابعون',
                value: '$followerCount',
                color: AppTheme.primaryAmber,
              ),
              if (distance != null)
                _buildStatItem(
                  icon: Icons.location_on,
                  label: 'المسافة',
                  value: distance,
                  color: AppTheme.accentGreen,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loadingFollow ? null : _toggleFollow,
        icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
        label: Text(_isFollowing ? 'إلغاء المتابعة' : 'متابعة'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey : AppTheme.accentGreen,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBioCard(String bio) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'نبذة عني',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(String? addressText, double? lat, double? lng) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.accentGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'الموقع',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            addressText ?? 'غير محدد',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          if (lat != null && lng != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.map, size: 18),
                label: const Text('عرض على الخريطة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    final credentialsAsync = ref.watch(credentialsProvider(widget.mohaffezId));

    return credentialsAsync.when(
      data: (credentials) {
        if (credentials.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'الشهادات والمؤهلات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...credentials.map((cred) {
                final title = cred['title'] as String? ?? '';
                final organization = cred['organization'] as String? ?? '';
                final type = cred['type'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCredentialIcon(type),
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              organization,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  IconData _getCredentialIcon(String type) {
    switch (type) {
      case 'ijazah':
        return Icons.book;
      case 'education':
        return Icons.school;
      case 'license':
        return Icons.card_membership;
      case 'award':
        return Icons.emoji_events;
      default:
        return Icons.description;
    }
  }

  Widget _buildAvailabilitySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, color: AppTheme.primaryAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'الأوقات المتاحة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AvailabilityCalendarWidget(
            mohaffezId: widget.mohaffezId,
            daysToShow: 7,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String? phoneNumber) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showBookingSheet,
              icon: const Icon(Icons.book_online),
              label: const Text('حجز جلسة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAmber,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('https://wa.me/$phoneNumber');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: Icon(Icons.phone, color: Colors.green.shade600),
                label: const Text('تواصل عبر واتساب'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.green.shade600),
                  foregroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleFollow() async {
    setState(() => _loadingFollow = true);

    try {
      if (_isFollowing) {
        await FollowService.unfollowMohaffez(widget.mohaffezId);
        if (mounted) {
          ErrorHandler.showSuccess(context, 'تم إلغاء المتابعة');
        }
      } else {
        await FollowService.followMohaffez(widget.mohaffezId);
        if (mounted) {
          ErrorHandler.showSuccess(context, 'تمت المتابعة بنجاح');
        }
      }

      // Refresh profile and follow status
      ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
      ref.invalidate(followStatusProvider(widget.mohaffezId));
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingFollow = false);
      }
    }
  }

  void _showBookingSheet() {
    final currentUser = ref.read(currentUserProvider).value;
    
    if (currentUser == null) {
      ErrorHandler.showError(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BookingSheet(
        mohaffezId: widget.mohaffezId,
        studentId: currentUser.uid,
        studentName: currentUser.name,
      ),
    );
  }
}

class _BookingSheet extends ConsumerStatefulWidget {
  final String mohaffezId;
  final String studentId;
  final String studentName;

  const _BookingSheet({
    required this.mohaffezId,
    required this.studentId,
    required this.studentName,
  });

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  String _sessionType = 'حفظ';
  String _selectedTimeSlot = '08:00';
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final mohaffezProfile = ref.watch(mohaffezProfileProvider(widget.mohaffezId)).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'حجز جلسة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Session Type
                        const Text(
                          'نوع الجلسة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: ['حفظ', 'مراجعة', 'حفظ ومراجعة'].map((type) {
                            return ChoiceChip(
                              label: Text(type),
                              selected: _sessionType == type,
                              onSelected: (selected) {
                                setState(() => _sessionType = type);
                              },
                              selectedColor: AppTheme.primaryAmber,
                              labelStyle: TextStyle(
                                color: _sessionType == type ? Colors.white : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        // Date
                        const Text(
                          'اختر التاريخ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Time Slot
                        const Text(
                          'اختر الوقت',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ScheduleConstants.quickSlots.map((slot) {
                            return ChoiceChip(
                              label: Text(slot),
                              selected: _selectedTimeSlot == slot,
                              onSelected: (selected) {
                                setState(() => _selectedTimeSlot = slot);
                              },
                              selectedColor: AppTheme.accentGreen,
                              labelStyle: TextStyle(
                                color: _selectedTimeSlot == slot ? Colors.white : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Submit Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () => _submitBooking(mohaffezProfile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'إرسال طلب الحجز',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitBooking(Map<String, dynamic>? mohaffezProfile) async {
    if (mohaffezProfile == null) return;

    setState(() => _submitting = true);

    try {
      // Parse time slot
      final parts = _selectedTimeSlot.split(':');
      final slotStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final slotEnd = slotStart.add(const Duration(minutes: 45));

      // Submit booking request
      final notifier = ref.read(sessionBookingProvider.notifier);
      final result = await notifier.requestSession(
        mohaffezId: widget.mohaffezId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        mohaffezName: mohaffezProfile['name'] as String,
        slotStart: slotStart,
        slotEnd: slotEnd,
        sessionType: _sessionType,
        timeSlot: _selectedTimeSlot,
        additionalData: {
          'imamAddressText': mohaffezProfile['addressText'],
          'imamAddressLat': mohaffezProfile['addressLat'],
          'imamAddressLng': mohaffezProfile['addressLng'],
          'mohaffezPhone': mohaffezProfile['phoneNumber'],
        },
      );

      if (!mounted) return;

      if (result.success) {
        Navigator.pop(context);
        ErrorHandler.showSuccess(context, 'تم إرسال طلب الحجز بنجاح');
      } else {
        ErrorHandler.showError(context, result.errorMessage ?? 'فشل في إرسال الطلب');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
