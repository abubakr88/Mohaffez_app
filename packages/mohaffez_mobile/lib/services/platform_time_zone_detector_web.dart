import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
external _JsDateTimeFormat _dateTimeFormat();

@JS('Intl.DateTimeFormat.prototype')
@staticInterop
abstract class _JsDateTimeFormat {}

extension on _JsDateTimeFormat {
  @JS()
  external _JsResolvedOptions resolvedOptions();
}

@JS()
@staticInterop
abstract class _JsResolvedOptions {}

extension on _JsResolvedOptions {
  @JS()
  external String get timeZone;
}

/// Reads the browser's IANA zone without relying on Flutter plugin
/// registration. The caller handles any JavaScript failure.
String? detectPlatformTimeZoneId() {
  final identifier = _dateTimeFormat().resolvedOptions().timeZone.trim();
  return identifier.isEmpty ? null : identifier;
}
