import 'dart:math';

class LocationUtils {
  // Prevent instantiation
  LocationUtils._();
  
  static String extractCity(String addressText) {
    if (addressText.isEmpty) return 'غير محدد';
    final parts = addressText.split(',');
    return parts.isNotEmpty ? parts[0].trim() : 'غير محدد';
  }
  
  static double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2,
  ) {
    const double earthRadius = 6371; // Radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
