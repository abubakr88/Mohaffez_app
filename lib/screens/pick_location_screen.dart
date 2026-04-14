import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import '../config/env_config.dart';

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
  late GoogleMapsPlaces _places;
  late LatLng _currentCenter;
  Marker? _marker;
  bool _mapReady = false;
  List<Prediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;

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
      throw Exception('GOOGLE_MAPS_API_KEY not set. Build with --dart-define-from-file=.env');
    }

    _places = GoogleMapsPlaces(apiKey: _googleApiKey);
    _currentCenter = LatLng(
      widget.initialLat ?? 30.0444,
      widget.initialLng ?? 31.2357,
    );
    _marker = Marker(
      markerId: const MarkerId('location'),
      position: _currentCenter,
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

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 3) return;

    setState(() => _isSearching = true);

    try {
      final result = await _places.autocomplete(
        query,
        language: 'ar',
        components: [
          Component(Component.country, 'eg'),
          Component(Component.country, 'sa'),
          Component(Component.country, 'ae'),
        ],
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
          SnackBar(content: Text('خطأ: ${result.errorMessage}')),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في البحث: $e')),
      );
    }
  }

  Future<void> _onPlaceSelected(Prediction prediction) async {
    try {
      final details = await _places.getDetailsByPlaceId(
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
            _marker = Marker(
              markerId: const MarkerId('location'),
              position: newPosition,
            );
            _predictions = [];
            _searchController.clear();
            _selectedPlaceId = result.placeId;
            _locationName = placeName;
            _city = city;
            _country = country;
          });

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 16),
          );

          if (!mounted) return;
          FocusScope.of(context).unfocus();
        }
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في تفاصيل المكان: ${details.errorMessage}')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديد الموقع: $e')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() => _mapReady = true);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentCenter = position.target;
      _marker = Marker(
        markerId: const MarkerId('location'),
        position: _currentCenter,
      );
    });
  }

  void _onSave() {
    Navigator.of(context).pop({
      'lat': _currentCenter.latitude,
      'lng': _currentCenter.longitude,
      'locationName': _locationName,
      'city': _city,
      'country': _country,
      'placeId': _selectedPlaceId,
    });
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
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: 15,
              ),
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              markers: _marker != null ? {_marker!} : {},
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
            if (!_mapReady) const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 16,
              right: 16,
              left: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
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
                  if (_isSearching)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
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
