import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  test('system config exposes safe audience matching defaults', () {
    final config = SystemConfigModel.defaults();

    expect(config.discoveryChildrenMaxAge, 10);
    expect(config.discoveryTeenMaxAge, 15);
    expect(config.discoveryAudienceMatchingEnabled, isTrue);
    expect(config.allowIncompleteTeacherAudience, isTrue);
    expect(config.toMap(), containsPair('discoveryChildrenMaxAge', 10));
    expect(config.toMap(), containsPair('discoveryTeenMaxAge', 15));
  });
}
