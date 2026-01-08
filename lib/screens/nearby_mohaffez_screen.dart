import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mohaffez_finder_app/shared/widgets/verification_badge.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/utils/location_utils.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../screens/mohaffez_profile_screen.dart';
import '../shared/widgets/cached_avatar.dart';
import '../shared/widgets/error_widgets.dart';

class NearbyMohaffezScreen extends StatefulWidget {
  final double? userLat;
  final double? userLng;

  const NearbyMohaffezScreen({
    super.key,
    this.userLat,
    this.userLng,
  });

  @override
  State<NearbyMohaffezScreen> createState() => _NearbyMohaffezScreenState();
}

class _NearbyMohaffezScreenState extends State<NearbyMohaffezScreen> {
  Position? _currentPosition;
  bool _loading = true;
  String? _errorMessage;
  List<MohaffezWithDistance> _mohaffezList = [];
  String _sortBy = 'distance'; // 'distance', 'rating'

  @override
  void initState() {
    super.initState();
    if (widget.userLat != null && widget.userLng != null) {
      _loadNearbyMohaffez();
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'خدمات الموقع غير مفعلة';
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'تم رفض إذن الموقع';
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'إذن الموقع مرفوض بشكل دائم';
          _loading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      await _loadNearbyMohaffez();
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في تحديد الموقع: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadNearbyMohaffez() async {
    final baseLat = widget.userLat ?? _currentPosition?.latitude;
    final baseLng = widget.userLng ?? _currentPosition?.longitude;
    if (baseLat == null || baseLng == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mohaffez')
          .get();

      final List<MohaffezWithDistance> mohaffezWithDistance = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['addressLat'] as num?)?.toDouble();
        final lng = (data['addressLng'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          // Use LocationUtils.calculateDistance
          final distance = LocationUtils.calculateDistance(
            baseLat,
            baseLng,
            lat,
            lng,
          );
          
          if (distance <= 50) {
            mohaffezWithDistance.add(MohaffezWithDistance(
              mohaffezId: doc.id,
              mohaffezName: data['name'] as String?,
              mohaffezPhotoUrl: data['photoUrl'] as String?,
              specialization:
                  (data['specialization'] as String?) ?? 'تحفيظ القرآن الكريم',
              rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
              reviewCount: (data['reviewCount'] as int?) ?? 0,
              distance: distance,
              addressText: data['addressText'] as String? ?? '',
              addressLat: lat,
              addressLng: lng,
              // Use LocationUtils.extractCity
              city: LocationUtils.extractCity(data['addressText'] as String? ?? ''),
              country: 'مصر',
              badges: data['badges'] != null 
                  ? Map<String, bool>.from(data['badges'] as Map)
                  : {},
            ));
          }
        }
      }

      mohaffezWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

      setState(() {
        _mohaffezList = mohaffezWithDistance;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في تحميل البيانات: $e';
        _loading = false;
      });
    }
  }

  // Add this method
  void _sortMohaffezList(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      if (sortBy == 'distance') {
        _mohaffezList.sort((a, b) => a.distance.compareTo(b.distance));
      } else if (sortBy == 'rating') {
        _mohaffezList.sort((a, b) => b.rating.compareTo(a.rating));
      }
    });
  }

  Future<void> showLocationOnMap(MohaffezWithDistance mohaffez) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${mohaffez.addressLat},${mohaffez.addressLng}';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الخريطة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('محفظون قريبون'),
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: _sortMohaffezList, // Now this will work
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'distance',
                  child: Row(
                    children: [
                      Icon(
                        Icons.near_me,
                        size: 20,
                        color: _sortBy == 'distance'
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('الأقرب'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rating',
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        size: 20,
                        color: _sortBy == 'rating'
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text('الأعلى تقييماً'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Show shimmer loading
    if (loading) {
      return ShimmerWidgets.list(
        itemCount: 5,
        itemBuilder: () => ShimmerWidgets.card(),
      );
    }

    // Show error state with appropriate error type
    if (errorMessage != null) {
      // Check if it's a permission error
      if (errorMessage!.contains('إذن') || 
          errorMessage!.contains('permission') ||
          errorMessage!.contains('denied')) {
        return ErrorDisplay.permission(
          permissionName: 'الموقع',
          onRetry: getCurrentLocation,
        );
      }
      
      // Check if location services are disabled
      if (errorMessage!.contains('معطلة') || 
          errorMessage!.contains('disabled')) {
        return ErrorDisplay.locationDisabled(
          onRetry: getCurrentLocation,
        );
      }
      
      // Default to data load error
      return ErrorDisplay.dataLoad(
        onRetry: getCurrentLocation,
      );
    }

    // Show empty state
    if (mohaffezList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'لا يوجد محفظين قريبين',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم نجد أي محفظين في منطقتك',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show loaded data
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mohaffezList.length,
      itemBuilder: (context, index) {
        final mohaffez = mohaffezList[index];
        return _buildMohaffezCard(mohaffez);
      },
    );
  }

  Widget _buildMohaffezCard(MohaffezWithDistance mohaffez) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to mohaffez profile
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MohaffezProfileScreen(
                mohaffezId: mohaffez.mohaffezId,
                mohaffezName: mohaffez.mohaffezName ?? 'محفظ',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Name + Badges
              Row(
                children: [
                  // Avatar with cached image
                  CachedAvatar(
                    imageUrl: mohaffez.mohaffezPhotoUrl,
                    radius: 35,
                  ),
                  const SizedBox(width: 16),
                  
                  // Name and specialization
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name with badges
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                mohaffez.mohaffezName ?? 'محفظ',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Verification badges
                            if (mohaffez.badges.isNotEmpty)
                              VerificationBadgesRow(
                                badges: mohaffez.badges,
                                size: 18,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Specialization
                        if (mohaffez.specialization.isNotEmpty)
                          Text(
                            mohaffez.specialization,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  
                  // Distance badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${mohaffez.distance.toStringAsFixed(1)} كم',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Rating and review count
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < mohaffez.rating.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 18,
                      color: Colors.amber,
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    mohaffez.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${mohaffez.reviewCount})',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Address
              if (mohaffez.addressText.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.place,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mohaffez.addressText,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  // View Profile button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MohaffezProfileScreen(
                              mohaffezId: mohaffez.mohaffezId,
                              mohaffezName: mohaffez.mohaffezName ?? 'محفظ',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person, size: 18),
                      label: const Text('عرض الملف'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Show on map button
                  OutlinedButton(
                    onPressed: () => _showLocationOnMap(mohaffez),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.map, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to show location on map
  Future<void> _showLocationOnMap(MohaffezWithDistance mohaffez) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${mohaffez.addressLat},${mohaffez.addressLng}';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الخريطة')),
        );
      }
    }
  }
}

// MohaffezWithDistance model
class MohaffezWithDistance {
  final String mohaffezId;
  final String? mohaffezName;
  final String? mohaffezPhotoUrl;
  final String specialization;
  final double rating;
  final int reviewCount;
  final double distance;
  final String addressText;
  final double addressLat;
  final double addressLng;
  final String city;
  final String country;
  final Map<String, bool> badges;

  MohaffezWithDistance({
    required this.mohaffezId,
    this.mohaffezName,
    this.mohaffezPhotoUrl,
    required this.specialization,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.addressText,
    required this.addressLat,
    required this.addressLng,
    required this.city,
    required this.country,
    required this.badges,
  });
}
