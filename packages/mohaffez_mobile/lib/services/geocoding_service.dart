import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodeResult {
  final double lat;
  final double lng;
  final String displayName;
  final String? name;
  final String? city;
  final String? country;
  final String? placeId;

  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.name,
    this.city,
    this.country,
    this.placeId,
  });
}

class GeocodingService {
  static const _base = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'Mohaffez/1.0 (contact@mohafezy.com)';
  static const _countryCodes = 'eg,sa,ae';

  static DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _throttle() async {
    final since = DateTime.now().difference(_lastCall);
    if (since < const Duration(seconds: 1)) {
      await Future.delayed(const Duration(seconds: 1) - since);
    }
    _lastCall = DateTime.now();
  }

  static Future<List<GeocodeResult>> search(String query) async {
    if (query.trim().length < 3) return const [];
    await _throttle();

    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'accept-language': 'ar',
      'countrycodes': _countryCodes,
      'addressdetails': '1',
      'limit': '8',
    });
    final res = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (res.statusCode != 200) return const [];

    final list = jsonDecode(res.body) as List;
    return list.map((raw) {
      final m = raw as Map<String, dynamic>;
      final addr = m['address'] as Map<String, dynamic>? ?? const {};
      return GeocodeResult(
        lat: double.parse(m['lat'].toString()),
        lng: double.parse(m['lon'].toString()),
        displayName: (m['display_name'] as String?) ?? '',
        name: (m['name'] as String?)?.isNotEmpty == true
            ? m['name'] as String?
            : (addr['road'] as String?) ?? (addr['suburb'] as String?),
        city: (addr['city'] as String?) ??
            (addr['town'] as String?) ??
            (addr['village'] as String?) ??
            (addr['state'] as String?),
        country: addr['country'] as String?,
        placeId: m['place_id']?.toString(),
      );
    }).toList();
  }

  static Future<GeocodeResult?> reverse(double lat, double lng) async {
    await _throttle();
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'jsonv2',
      'accept-language': 'ar',
      'addressdetails': '1',
    });
    final res = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (res.statusCode != 200) return null;

    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final addr = m['address'] as Map<String, dynamic>? ?? const {};
    return GeocodeResult(
      lat: lat,
      lng: lng,
      displayName: (m['display_name'] as String?) ?? '',
      name: (addr['road'] as String?) ??
          (addr['suburb'] as String?) ??
          (addr['neighbourhood'] as String?),
      city: (addr['city'] as String?) ??
          (addr['town'] as String?) ??
          (addr['village'] as String?) ??
          (addr['state'] as String?),
      country: addr['country'] as String?,
      placeId: m['place_id']?.toString(),
    );
  }
}
