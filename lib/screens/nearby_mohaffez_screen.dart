import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';
import '../shared/utils/location_utils.dart';
import 'mohaffez_profile_screen.dart';

// Model for mohaffez with distance
class MohaffezWithDistance {
  final String uid;
  final String name;
  final String? photoUrl;
  final String? bio;
  final String? specialization;
  final double? rating;
  final int followerCount;
  final double? addressLat;
  final double? addressLng;
  final String? addressText;
  final double distance;

  MohaffezWithDistance({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.bio,
    this.specialization,
    this.rating,
    required this.followerCount,
    this.addressLat,
    this.addressLng,
    this.addressText,
    required this.distance,
  });

  factory MohaffezWithDistance.fromFirestore(
    DocumentSnapshot doc,
    double userLat,
    double userLng,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final mohaffezLat = data['addressLat'] as double?;
    final mohaffezLng = data['addressLng'] as double?;

    double distance = 0;
    if (mohaffezLat != null && mohaffezLng != null) {
      distance = LocationUtils.calculateDistance(
        userLat,
        userLng,
        mohaffezLat,
        mohaffezLng,
      );
    }

    return MohaffezWithDistance(
      uid: doc.id,
      name: data['name'] as String? ?? 'بدون اسم',
      photoUrl: data['photoUrl'] as String?,
      bio: data['bio'] as String?,
      specialization: data['specialization'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      followerCount: data['followerCount'] as int? ?? 0,
      addressLat: mohaffezLat,
      addressLng: mohaffezLng,
      addressText: data['addressText'] as String?,
      distance: distance,
    );
  }
}

// Provider for nearby mohaffez
final nearbyMohaffezProvider = FutureProvider.family<List<MohaffezWithDistance>, (double, double)>(
  (ref, coords) async {
    final (userLat, userLng) = coords;
    
    // Query mohaffez with location
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'mohaffez')
        .where('addressLat', isNotEqualTo: null)
        .get();

    final mohaffezList = snapshot.docs
        .map((doc) => MohaffezWithDistance.fromFirestore(doc, userLat, userLng))
        .where((m) => m.distance <= 50) // Within 50km
        .toList();

    return mohaffezList;
  },
);

// Sort mode provider
enum SortMode { distance, rating, followers }

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.distance);

class NearbyMohaffezScreen extends ConsumerStatefulWidget {
  final double? userLat;
  final double? userLng;

  const NearbyMohaffezScreen({
    super.key,
    this.userLat,
    this.userLng,
  });

  @override
  ConsumerState<NearbyMohaffezScreen> createState() => _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends ConsumerState<NearbyMohaffezScreen> {
  Position? _currentPosition;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.userLat == null || widget.userLng == null) {
      _getCurrentLocation();
    } else {
      _currentPosition = Position(
        latitude: widget.userLat!,
        longitude: widget.userLng!,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('خدمات الموقع معطلة');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('لم يتم منح إذن الوصول للموقع');
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('محفظون قريبون')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحديد موقعك...'),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محفظون قريبون')),
        body: ErrorDisplay.locationDisabled(
          onRetry: _getCurrentLocation,
        ),
      );
    }

    return _buildContent();
  }

  Widget _buildContent() {
    final sortMode = ref.watch(sortModeProvider);
    final mohaffezAsync = ref.watch(
      nearbyMohaffezProvider((_currentPosition!.latitude, _currentPosition!.longitude)),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محفظون قريبون'),
          actions: [
            PopupMenuButton<SortMode>(
              icon: const Icon(Icons.sort),
              onSelected: (mode) {
                ref.read(sortModeProvider.notifier).state = mode;
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortMode.distance,
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: sortMode == SortMode.distance ? AppTheme.primaryAmber : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('الأقرب'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortMode.rating,
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: sortMode == SortMode.rating ? AppTheme.primaryAmber : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('الأعلى تقييماً'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SortMode.followers,
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: sortMode == SortMode.followers ? AppTheme.primaryAmber : null,
                      ),
                      const SizedBox(width: 8),
                      const Text('الأكثر متابعة'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: mohaffezAsync.when(
          data: (mohaffezList) {
            if (mohaffezList.isEmpty) {
              return const EmptyState(
                icon: Icons.person_search,
                title: 'لا يوجد محفظون قريبون',
                message: 'لا يوجد محفظون في نطاق 50 كم من موقعك الحالي.',
                animated: true,
              );
            }

            // Sort list based on selected mode
            final sortedList = List<MohaffezWithDistance>.from(mohaffezList);
            switch (sortMode) {
              case SortMode.distance:
                sortedList.sort((a, b) => a.distance.compareTo(b.distance));
                break;
              case SortMode.rating:
                sortedList.sort((a, b) {
                  final ratingA = a.rating ?? 0;
                  final ratingB = b.rating ?? 0;
                  return ratingB.compareTo(ratingA);
                });
                break;
              case SortMode.followers:
                sortedList.sort((a, b) => b.followerCount.compareTo(a.followerCount));
                break;
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(nearbyMohaffezProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sortedList.length,
                itemBuilder: (context, index) {
                  final mohaffez = sortedList[index];
                  return _buildMohaffezCard(mohaffez);
                },
              ),
            );
          },
          loading: () => ShimmerWidgets.list(
            itemCount: 5,
            itemBuilder: () => ShimmerWidgets.listItem(
              showAvatar: true,
              lines: 3,
            ),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(nearbyMohaffezProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildMohaffezCard(MohaffezWithDistance mohaffez) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MohaffezProfileScreen(
                mohaffezId: mohaffez.uid,
                userLat: _currentPosition?.latitude,
                userLng: _currentPosition?.longitude,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CachedAvatar(
                imageUrl: mohaffez.photoUrl,
                radius: 32,
                semanticLabel: 'صورة ${mohaffez.name}',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mohaffez.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (mohaffez.specialization?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        mohaffez.specialization!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Distance
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mohaffez.distance < 1
                              ? '${(mohaffez.distance * 1000).round()} م'
                              : '${mohaffez.distance.toStringAsFixed(1)} كم',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Rating
                        if (mohaffez.rating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mohaffez.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        // Followers
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${mohaffez.followerCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
