import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/utils/location_utils.dart';
import '../shared/widgets/shimmer_widgets.dart';

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
    if (_loading) {
      return ShimmerWidgets.list(
        itemCount: 5,
        itemBuilder: () => ShimmerWidgets.card(),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (_mohaffezList.isEmpty) {
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
            ),
          ],
        ),
      );
    }

    // Show loaded data
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _mohaffezList.length,
      itemBuilder: (context, index) {
        final mohaffez = _mohaffezList[index];
        return _buildMohaffezCard(mohaffez);
      },
    );
  }

  Widget _buildMohaffezCard(MohaffezWithDistance mohaffez) {
    // Your card implementation here
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(mohaffez.mohaffezName ?? 'محفظ'),
        subtitle: Text('${mohaffez.distance.toStringAsFixed(1)} كم'),
        onTap: () {
          // Navigate to profile
        },
      ),
    );
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
