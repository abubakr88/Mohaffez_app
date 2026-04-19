import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';

import '../../config/env_config.dart';
import '../theme/app_theme_constants.dart';

class LocationPickerWidget extends StatefulWidget {
  const LocationPickerWidget({
    super.key,
    required this.onLocationSelected,
    this.initialAddress,
  });

  final void Function(String address, double lat, double lng)
      onLocationSelected;
  final String? initialAddress;

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  final TextEditingController _controller = TextEditingController();
  String? selectedAddress;
  double? selectedLat;
  double? selectedLng;
  bool loadingCurrentLocation = false;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _controller.text = widget.initialAddress!;
      selectedAddress = widget.initialAddress;
    }
    try {
      _apiKey = EnvConfig.googleMapsApiKey;
    } catch (_) {
      _apiKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_apiKey == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeConstants.errorBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeConstants.error.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Google Maps API key غير متوفر في ملف .env',
              style: TextStyle(color: AppThemeConstants.error),
            ),
          )
        else
          GooglePlaceAutoCompleteTextField(
            textEditingController: _controller,
            googleAPIKey: _apiKey!,
            inputDecoration: InputDecoration(
              labelText: 'ابحث عن العنوان',
              hintText: 'ابدأ الكتابة للبحث...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            debounceTime: 600,
            countries: const ['eg'],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (Prediction prediction) {
              final lat = double.tryParse(prediction.lat ?? '');
              final lng = double.tryParse(prediction.lng ?? '');
              if (lat == null || lng == null) return;
              setState(() {
                selectedAddress = prediction.description ?? '';
                selectedLat = lat;
                selectedLng = lng;
              });
              widget.onLocationSelected(selectedAddress!, lat, lng);
            },
            itemClick: (Prediction prediction) {
              _controller.text = prediction.description ?? '';
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            },
            itemBuilder: (context, index, Prediction prediction) {
              return Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppThemeConstants.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(prediction.description ?? '',
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              );
            },
            seperatedBuilder: const Divider(),
            isCrossBtnShown: true,
            containerHorizontalPadding: 0,
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: loadingCurrentLocation ? null : _useCurrentLocation,
            icon: loadingCurrentLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(loadingCurrentLocation
                ? 'جاري تحديد الموقع...'
                : 'استخدام موقعي الحالي'),
          ),
        ),
        if (selectedAddress != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppThemeConstants.successBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppThemeConstants.success),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppThemeConstants.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العنوان المحدد:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(selectedAddress!,
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => loadingCurrentLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('تم رفض صلاحية تحديد الموقع');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('صلاحية تحديد الموقع مرفوضة بشكل دائم');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final address =
          'إحداثيات: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      if (!mounted) return;
      setState(() {
        selectedAddress = address;
        selectedLat = position.latitude;
        selectedLng = position.longitude;
        _controller.text = address;
        loadingCurrentLocation = false;
      });
      widget.onLocationSelected(address, position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingCurrentLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديد الموقع: $e'),
          backgroundColor: AppThemeConstants.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
