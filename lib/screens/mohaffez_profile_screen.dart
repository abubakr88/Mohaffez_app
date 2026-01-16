// lib/screens/mohaffez_profile_screen.dart - REFACTORED
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';
import '../providers/user_provider.dart';
import '../services/follow_service.dart';
import '../shared/utils/error_handler.dart';
import 'dart:math';

// ✅ SPLIT: Extract providers to separate file
import '../providers/mohaffez_profile_providers.dart';

/// Main screen - now just orchestrates subwidgets
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
  ConsumerState<MohaffezProfileScreen> createState() =>
      _MohaffezProfileScreenState();
}

class _MohaffezProfileScreenState extends ConsumerState<MohaffezProfileScreen> {
  bool _isFollowing = false;
  bool _loadingFollow = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(mohaffezProfileProvider(widget.mohaffezId));
    final followStatusAsync = ref.watch(followStatusProvider(widget.mohaffezId));

    // Update follow state
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
          loading: _buildLoadingSkeleton,
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
        _buildAppBarSkeleton(),
        SliverList(
          delegate: SliverChildListDelegate([
            ShimmerWidgets.profile(),
          ]),
        ),
      ],
    );
  }

  Widget _buildContent(Map<String, dynamic> profile) {
    return CustomScrollView(
      slivers: [
        // ✅ SPLIT: App bar in separate widget
        _ProfileAppBar(
          name: profile['name'] as String? ?? 'محفظ',
          photoUrl: profile['photoUrl'] as String?,
        ),
        
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Header section
            _ProfileHeader(
              profile: profile,
              userLat: widget.userLat,
              userLng: widget.userLng,
            ),
            
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Bio card
            if ((profile['bio'] as String?)?.isNotEmpty ?? false)
              _ProfileBioCard(bio: profile['bio'] as String),
            
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Location card
            _ProfileLocationCard(
              addressText: profile['addressText'] as String?,
              addressLat: profile['addressLat'] as double?,
              addressLng: profile['addressLng'] as double?,
            ),
            
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Credentials section
            _ProfileCredentials(mohaffezId: widget.mohaffezId),
            
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Availability section
            _ProfileAvailability(mohaffezId: widget.mohaffezId),
            
            const SizedBox(height: 16),
            
            // ✅ SPLIT: Action buttons
            _ProfileActionButtons(
              mohaffezId: widget.mohaffezId,
              phoneNumber: profile['phoneNumber'] as String?,
              isFollowing: _isFollowing,
              loadingFollow: _loadingFollow,
              onFollowToggle: _handleFollowToggle,
            ),
            
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }

  Widget _buildAppBarSkeleton() {
    return SliverAppBar(
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
    );
  }

  Future<void> _handleFollowToggle() async {
    if (_loadingFollow) return;

    setState(() => _loadingFollow = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final success = _isFollowing
          ? await FollowService.unfollowMohaffez(widget.mohaffezId)
          : await FollowService.followMohaffez(widget.mohaffezId);

      if (success) {
        setState(() => _isFollowing = !_isFollowing);
        
        if (mounted) {
          ErrorHandler.showSuccess(
            context,
            _isFollowing ? 'تمت المتابعة بنجاح' : 'تم إلغاء المتابعة',
          );
        }
        
        // Refresh profile data
        ref.invalidate(mohaffezProfileProvider(widget.mohaffezId));
      }
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
}

// ===================================================================
// ✅ EXTRACTED WIDGETS - Each in its own section
// ===================================================================

/// App bar with profile photo and name
class _ProfileAppBar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _ProfileAppBar({
    required this.name,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryAmber, AppTheme.lightAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Profile photo
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  CachedAvatar(
                    imageUrl: photoUrl,
                    radius: 50,
                    semanticLabel: name,
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

/// Profile header with name, specialization, rating, followers
class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final double? userLat;
  final double? userLng;

  const _ProfileHeader({
    required this.profile,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'محفظ';
    final specialization = profile['specialization'] as String?;
    final rating = (profile['rating'] as num?)?.toDouble() ?? 0.0;
    final followerCount = profile['followerCount'] as int? ?? 0;
    final addressLat = profile['addressLat'] as double?;
    final addressLng = profile['addressLng'] as double?;

    // Calculate distance
    String? distanceText;
    if (userLat != null && userLng != null && 
        addressLat != null && addressLng != null) {
      final distance = _calculateDistance(userLat!, userLng!, addressLat, addressLng);
      distanceText = distance < 1
          ? '${(distance * 1000).round()} م'
          : '${distance.toStringAsFixed(1)} كم';
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
        children: [
          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Specialization
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
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.star,
                label: 'التقييم',
                value: rating.toStringAsFixed(1),
              ),
              _buildStatItem(
                icon: Icons.people,
                label: 'المتابعون',
                value: followerCount.toString(),
              ),
              if (distanceText != null)
                _buildStatItem(
                  icon: Icons.location_on,
                  label: 'المسافة',
                  value: distanceText,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryAmber, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryAmber,
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula (simplified - use utility if available)
    const double p = 0.017453292519943295;
    final a = 0.5 - 
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * 
        (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}

/// Bio card
class _ProfileBioCard extends StatelessWidget {
  final String bio;

  const _ProfileBioCard({required this.bio});

  @override
  Widget build(BuildContext context) {
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
                'نبذة تعريفية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            bio,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Location card
class _ProfileLocationCard extends StatelessWidget {
  final String? addressText;
  final double? addressLat;
  final double? addressLng;

  const _ProfileLocationCard({
    this.addressText,
    this.addressLat,
    this.addressLng,
  });

  @override
  Widget build(BuildContext context) {
    if (addressText == null || addressText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasCoordinates = addressLat != null && addressLng != null;

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
          const Divider(height: 24),
          Text(
            addressText!,
            style: const TextStyle(fontSize: 14),
          ),
          if (hasCoordinates) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMap(addressLat!, addressLng!),
                icon: const Icon(Icons.map, size: 18),
                label: const Text('فتح في الخريطة'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openMap(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// ✅ OPTIMIZED: Credentials section with error handling
class _ProfileCredentials extends ConsumerWidget {
  final String mohaffezId;

  const _ProfileCredentials({required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(credentialsProvider(mohaffezId));

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
          const Divider(height: 24),
          credentialsAsync.when(
            data: (credentials) {
              if (credentials.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'لا توجد شهادات مضافة',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                children: credentials.map((cred) {
                  return _buildCredentialItem(
                    title: cred['title'] as String? ?? '',
                    organization: cred['organization'] as String? ?? '',
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'خطأ في تحميل الشهادات',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialItem({
    required String title,
    required String organization,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
  }
}

/// ✅ OPTIMIZED: Availability section
class _ProfileAvailability extends ConsumerWidget {
  final String mohaffezId;

  const _ProfileAvailability({required this.mohaffezId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ TODO: Create availabilityProvider similar to credentialsProvider
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.accentGreen, size: 20),
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
          Divider(height: 24),
          Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اضغط لعرض الأوقات المتاحة',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action buttons (follow, book, call)
class _ProfileActionButtons extends StatelessWidget {
  final String mohaffezId;
  final String? phoneNumber;
  final bool isFollowing;
  final bool loadingFollow;
  final VoidCallback onFollowToggle;

  const _ProfileActionButtons({
    required this.mohaffezId,
    this.phoneNumber,
    required this.isFollowing,
    required this.loadingFollow,
    required this.onFollowToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Follow button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loadingFollow ? null : onFollowToggle,
              icon: loadingFollow
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isFollowing ? Icons.person_remove : Icons.person_add),
              label: Text(isFollowing ? 'إلغاء المتابعة' : 'متابعة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.grey : AppTheme.primaryAmber,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Call button
          if (phoneNumber != null && phoneNumber!.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _makeCall(phoneNumber!),
                icon: const Icon(Icons.phone),
                label: const Text('اتصال'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }
}
