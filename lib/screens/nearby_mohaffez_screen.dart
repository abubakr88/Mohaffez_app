import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'mohaffez_profile_screen.dart';

class NearbyMohaffezScreen extends StatefulWidget {
  final double userLat;
  final double userLng;

  const NearbyMohaffezScreen({
    super.key,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<NearbyMohaffezScreen> createState() => NearbyMohaffezScreenState();
}

class NearbyMohaffezScreenState extends State<NearbyMohaffezScreen> {
  final List<MohaffezWithDistance> _allMohaffez = [];
  List<MohaffezWithDistance> _filteredMohaffez = [];
  bool _loading = true;
  String _errorMessage = '';
  double _selectedDistance = 10.0;
  final List<int> _distanceOptions = [1, 2, 5, 10, 20, 50, 100, 200];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNearbyMohaffez();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // الدالة المحدثة - البحث عن المحفظين مباشرة
  Future<void> _loadNearbyMohaffez() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = '';
      _allMohaffez.clear();
      _filteredMohaffez = [];
    });

    try {
      // البحث عن المحفظين في مجموعة users مباشرة
      final mohaffezSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'mohaffez')
          .get();

      final List<MohaffezWithDistance> mohaffezList = [];

      for (var doc in mohaffezSnapshot.docs) {
        final data = doc.data();

        // التحقق من وجود موقع للمحفظ
        final double? lat = _toDouble(data['latitude']);
        final double? lng = _toDouble(data['longitude']);

        if (lat == null || lng == null) {
          continue;
        }

        // حساب المسافة
        final distance = calculateDistance(
          widget.userLat,
          widget.userLng,
          lat,
          lng,
        );

        // إنشاء كائن MohaffezWithDistance
        mohaffezList.add(
          MohaffezWithDistance(
            city: data['city'] as String? ?? '',
            country: data['country'] as String? ?? '',
            lat: lat,
            lng: lng,
            distance: distance,
            type: 'محفظ',
            details: data['bio'] as String? ?? '',
            date: null,
            mohaffezId: doc.id,
            mohaffezName: data['name'] as String?,
            mohaffezPhotoUrl: data['photoUrl'] as String?,
            rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
            reviewCount: data['reviewCount'] as int? ?? 0,
            specialization: data['specialization'] as String? ?? 'تحفيظ القرآن',
          ),
        );
      }

      // ترتيب حسب المسافة
      mohaffezList.sort((a, b) => a.distance.compareTo(b.distance));

      if (!mounted) return;

      setState(() {
        _allMohaffez.addAll(mohaffezList);
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
      });
    }
  }

  void _applyFilters() {
    if (!mounted) return;

    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMohaffez = _allMohaffez.where((m) {
        final matchesDistance = m.distance <= _selectedDistance;
        final matchesSearch = query.isEmpty ||
            (m.mohaffezName?.toLowerCase().contains(query) ?? false) ||
            m.city.toLowerCase().contains(query) ||
            m.country.toLowerCase().contains(query);
        return matchesDistance && matchesSearch;
      }).toList();
    });
  }

  void _onDistanceChanged(double? value) {
    if (value == null || !mounted) return;

    setState(() {
      _selectedDistance = value;
    });

    _applyFilters();
  }

  void _showLocationOnMap(MohaffezWithDistance m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationMapScreen(
          centerLat: m.lat,
          centerLng: m.lng,
          locationName: m.mohaffezName ?? 'موقع',
          userLat: widget.userLat,
          userLng: widget.userLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('ابحث عن محفظ'),
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم المحفظ أو المدينة أو المنطقة',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.tune),
                          label: const Text('التخصص'),
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.location_on),
                          label: const Text('المنطقة'),
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PopupMenuButton<double>(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.sort),
                            label: const Text('المسافة'),
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          itemBuilder: (context) => _distanceOptions
                              .map((d) => PopupMenuItem<double>(
                                    value: d.toDouble(),
                                    child: Text('$d كم'),
                                  ))
                              .toList(),
                          onSelected: _onDistanceChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!_loading)
                    Text(
                      'عرض ${_filteredMohaffez.length} محفظ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadNearbyMohaffez,
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredMohaffez.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search_rounded,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا يوجد محفظون بالقرب منك حالياً',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'جرب زيادة نطاق البحث أو البحث في منطقة أخرى',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _loadNearbyMohaffez,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('إعادة المحاولة'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredMohaffez.length,
                              itemBuilder: (context, index) {
                                final m = _filteredMohaffez[index];
                                return _buildMohaffezCard(m);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMohaffezCard(MohaffezWithDistance m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (m.mohaffezId == null || m.mohaffezId!.isEmpty) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MohaffezProfileScreen(
                mohaffezId: m.mohaffezId!,
                mohaffezName: m.mohaffezName ?? 'محفظ',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: m.mohaffezPhotoUrl != null
                        ? NetworkImage(m.mohaffezPhotoUrl!)
                        : null,
                    child: m.mohaffezPhotoUrl == null
                        ? const Icon(Icons.person, size: 35)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.mohaffezName ?? 'محفظ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.specialization ?? 'تحفيظ القرآن الكريم',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < m.rating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'التقييم العام من ${m.reviewCount} طالب',
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
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${m.city}، ${m.country}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.directions_walk,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'المسافة: ${m.distance.toStringAsFixed(1)} كم',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'مدة الجلسة: 45 دقيقة',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (m.mohaffezId == null || m.mohaffezId!.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MohaffezProfileScreen(
                          mohaffezId: m.mohaffezId!,
                          mohaffezName: m.mohaffezName ?? 'محفظ',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('احجز الآن'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MohaffezWithDistance {
  final String city;
  final String country;
  final double lat;
  final double lng;
  final double distance;
  final String type;
  final String details;
  final DateTime? date;
  final String? mohaffezId;
  String? mohaffezName;
  String? mohaffezPhotoUrl;
  double rating;
  int reviewCount;
  String? specialization;

  MohaffezWithDistance({
    required this.city,
    required this.country,
    required this.lat,
    required this.lng,
    required this.distance,
    required this.type,
    required this.details,
    this.date,
    this.mohaffezId,
    this.mohaffezName,
    this.mohaffezPhotoUrl,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.specialization,
  });
}

class LocationMapScreen extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  final String locationName;
  final double userLat;
  final double userLng;

  const LocationMapScreen({
    super.key,
    required this.centerLat,
    required this.centerLng,
    required this.locationName,
    required this.userLat,
    required this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('موقع: $locationName'),
        ),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('location'),
              position: LatLng(centerLat, centerLng),
              infoWindow: InfoWindow(title: locationName),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
            Marker(
              markerId: const MarkerId('user'),
              position: LatLng(userLat, userLng),
              infoWindow: const InfoWindow(title: 'موقعي'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [
                LatLng(userLat, userLng),
                LatLng(centerLat, centerLng),
              ],
              color: Colors.blue,
              width: 3,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10),
              ],
            ),
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
      ),
    );
  }
}
