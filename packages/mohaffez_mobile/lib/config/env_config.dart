class EnvConfig {
  // Keys are injected at build time via --dart-define-from-file=.env
  // They are NOT bundled in the APK as a readable asset.
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
