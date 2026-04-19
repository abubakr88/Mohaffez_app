import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/env_config.dart';
import '../../shared/theme/app_theme_constants.dart';

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
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  GoogleMapsPlaces? _places;
  late LatLng _currentCenter;
  bool _mapReady = false;
  List<Prediction> _predictions = [];
  bool _isSearching = false;
  bool _isLoadingPlace = false;
  Timer? _debounce;
  String? _errorMessage;
  bool _hasInteractedWithMap = false;
  bool _isProgrammaticCameraMove = false;

  // FIXED: Load API key from environment variable
  late final String _googleApiKey;

  String? _selectedPlaceId;
  String? _locationName;
  String? _city;
  String? _country;

  @override
  void initState() {
    super.initState();

    _googleApiKey = EnvConfig.googleMapsApiKey;

    if (_googleApiKey.isEmpty) {
      setState(() {
        _errorMessage = 'لم يتم إعداد مفتاح Google Maps. يرجى الاتصال بالدعم.';
      });
      return;
    }

    _places = GoogleMapsPlaces(apiKey: _googleApiKey);
    _isProgrammaticCameraMove = true;
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
    _mapController?.dispose();
    _debounce?.cancel();
    _places?.dispose();
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

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 3) return;
    if (_places == null) return;

    setState(() => _isSearching = true);

    try {
      final result = await _places!.autocomplete(
        query,
        language: 'ar',
      );

      if (result.isOkay) {
        setState(() {
          _predictions = result.predictions;
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في البحث')),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في البحث')),
      );
    }
  }

  Future<void> _onPlaceSelected(Prediction prediction) async {
    if (prediction.placeId == null) return;
    if (_places == null) return;
    
    setState(() => _isLoadingPlace = true);
    
    try {
      final details = await _places!.getDetailsByPlaceId(
        prediction.placeId!,
        language: 'ar',
      );

      if (details.isOkay) {
        final result = details.result;
        final location = result.geometry?.location;

        if (location != null) {
          final newPosition = LatLng(location.lat, location.lng);
          final placeName = result.name;

          String? city;
          String? country;

          for (final comp in result.addressComponents) {
            if (comp.types.contains('locality')) {
              city = comp.longName;
            }

            if (comp.types.contains('administrative_area_level_1') &&
                (city == null || city.isEmpty)) {
              city = comp.longName;
            }

            if (comp.types.contains('country')) {
              country = comp.longName;
            }
          }

          setState(() {
            _currentCenter = newPosition;
            _predictions = [];
            _searchController.clear();
            _selectedPlaceId = result.placeId;
            _locationName = placeName;
            _city = city;
            _country = country;
            _hasInteractedWithMap = true;
            _isLoadingPlace = false;
          });

          _isProgrammaticCameraMove = true;
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 16),
          );

          if (!mounted) return;
          FocusScope.of(context).unfocus();
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoadingPlace = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حدث خطأ في جلب تفاصيل المكان')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPlace = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في تحديد الموقع')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() => _mapReady = true);
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
  }

  Future<void> _onCameraIdle() async {
    // Skip geocoding if this was a programmatic camera move (e.g., from place selection or my location)
    if (_isProgrammaticCameraMove) {
      _isProgrammaticCameraMove = false;
      return;
    }
    
    setState(() {
      _hasInteractedWithMap = true;
    });
    
    // Perform reverse geocoding for manual drags
    try {
      final placemarks = await placemarkFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _locationName = place.name ?? place.street;
          _city = place.locality ?? place.subAdministrativeArea;
          _country = place.country;
          _selectedPlaceId = null; // Clear place ID since this is manual selection
        });
      }
    } catch (e) {
      // Silently fail reverse geocoding - location coordinates still valid
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمات الموقع غير مفعلة')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
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
      
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newPosition, 16),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحصول على موقعك الحالي')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
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
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppThemeConstants.error),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: 15,
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
            if (!_mapReady) const Center(child: CircularProgressIndicator()),
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
                child: const Icon(Icons.my_location, color: AppThemeConstants.onPrimary),
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
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];

                          return ListTile(
                            leading: const Icon(Icons.location_on, size: 20),
                            title: Text(
                              prediction.structuredFormatting?.mainText ??
                                  prediction.description ??
                                  '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: prediction
                                        .structuredFormatting?.secondaryText !=
                                    null
                                ? Text(
                                    prediction
                                        .structuredFormatting!.secondaryText!,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            onTap: () => _onPlaceSelected(prediction),
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
