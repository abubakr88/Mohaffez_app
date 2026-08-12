import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/services/time_zone_service.dart';

void main() {
  group('TimeZoneService notification zone detection', () {
    test('recognizes IANA identifiers returned by devices and browsers', () {
      expect(TimeZoneService.isPlausibleIanaTimeZone('Africa/Cairo'), isTrue);
      expect(
        TimeZoneService.isPlausibleIanaTimeZone('America/New_York'),
        isTrue,
      );
      expect(TimeZoneService.isPlausibleIanaTimeZone('UTC'), isTrue);
      expect(TimeZoneService.isPlausibleIanaTimeZone(''), isFalse);
      expect(TimeZoneService.isPlausibleIanaTimeZone('Arabian Standard Time'),
          isFalse);
    });
  });
}
