import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../services/geocoding_service.dart';

class PickLocationScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialSearchQuery;

  const PickLocationScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialSearchQuery,
  });

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late LatLng _currentCenter;
  List<GeocodeResult> _predictions = [];
  bool _isSearching = false;
  bool _isLoadingPlace = false;
  Timer? _debounce;
  bool _hasInteractedWithMap = false;
  bool _isProgrammaticCameraMove = false;

  String? _selectedPlaceId;
  String? _locationName;
  String? _city;
  String? _country;

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(
      widget.initialLat ?? 30.0444,
      widget.initialLng ?? 31.2357,
    );
    _searchController.addListener(_onSearchChanged);
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
      _performSearch(widget.initialSearchQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (_searchController.text.isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 3) return;
    setState(() => _isSearching = true);
    try {
      final results = await GeocodingService.search(query);
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في البحث')),
      );
    }
  }

  Future<void> _onPlaceSelected(GeocodeResult prediction) async {
    setState(() => _isLoadingPlace = true);

    final newPosition = LatLng(prediction.lat, prediction.lng);
    setState(() {
      _currentCenter = newPosition;
      _predictions = [];
      _searchController.clear();
      _selectedPlaceId = prediction.placeId;
      _locationName = prediction.name ?? prediction.displayName;
      _city = prediction.city;
      _country = prediction.country;
      _hasInteractedWithMap = true;
      _isLoadingPlace = false;
    });

    _isProgrammaticCameraMove = true;
    _mapController.move(newPosition, 16);

    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  void _onMapEvent(MapEvent event) {
    _currentCenter = event.camera.center;
    if (event is MapEventMoveEnd) {
      if (_isProgrammaticCameraMove) {
        _isProgrammaticCameraMove = false;
        return;
      }
      setState(() => _hasInteractedWithMap = true);
      _reverseGeocode(_currentCenter);
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    try {
      final result =
          await GeocodingService.reverse(position.latitude, position.longitude);
      if (result != null && mounted) {
        setState(() {
          _locationName = result.name ?? result.displayName;
          _city = result.city;
          _country = result.country;
          _selectedPlaceId = null;
        });
      }
    } catch (_) {
      // silent fail — coordinates still valid
    }
  }

  void _onSave() {
    if (!_hasInteractedWithMap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار موقع على الخريطة أولاً'),
        ),
      );
      return;
    }
    context.pop({
      'lat': _currentCenter.latitude,
      'lng': _currentCenter.longitude,
      'locationName': _locationName,
      'city': _city,
      'country': _country,
      'placeId': _selectedPlaceId,
    });
  }

  Future<void> _goToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمات الموقع غير مفعلة')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الموقع')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض إذن الموقع بشكل دائم')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final newPosition = LatLng(position.latitude, position.longitude);
      _isProgrammaticCameraMove = true;
      setState(() {
        _currentCenter = newPosition;
        _hasInteractedWithMap = true;
      });
      _mapController.move(newPosition, 16);
      _reverseGeocode(newPosition);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحصول على موقعك الحالي')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('اختيار الموقع'),
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 15,
                onMapEvent: _onMapEvent,
              ),
              children: [
                TileLayer(
                  urlTemplate: _osmTileUrl,
                  userAgentPackageName: 'app.mohafezy',
                  maxNativeZoom: 19,
                  tileProvider: kIsWeb
                      ? CancellableNetworkTileProvider()
                      : NetworkTileProvider(),
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            // Static center pin overlay
            Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppThemeConstants.error,
                ),
              ),
            ),
            // My location FAB
            Positioned(
              bottom: 100,
              left: 16,
              child: FloatingActionButton(
                heroTag: 'my_location',
                onPressed: _goToMyLocation,
                backgroundColor: AppThemeConstants.primary,
                child: const Icon(Icons.my_location,
                    color: AppThemeConstants.onPrimary),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              left: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppThemeConstants.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: AppThemeConstants.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن الموقع...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _predictions = []);
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (_isSearching || _isLoadingPlace)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_predictions.isNotEmpty && !_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppThemeConstants.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: AppThemeConstants.shadow,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = _predictions[index];
                          final primary = p.name ?? p.displayName;
                          final secondary = [
                            if (p.city != null) p.city,
                            if (p.country != null) p.country,
                          ].whereType<String>().join('، ');
                          return ListTile(
                            leading: const Icon(Icons.location_on, size: 20),
                            title: Text(
                              primary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: secondary.isEmpty
                                ? null
                                : Text(
                                    secondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                            onTap: () => _onPlaceSelected(p),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _onSave,
              icon: const Icon(Icons.check),
              label: const Text('حفظ الموقع'),
            ),
          ),
        ),
      ),
    );
  }
}
