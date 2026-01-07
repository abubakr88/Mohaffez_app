import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._internal();

  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initialize() async {
    // Initial status
    final result = await _connectivity.checkConnectivity();
    _connectionController.add(_isOnline(result.isNotEmpty ? result.first : ConnectivityResult.none));

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((result) {
      _connectionController.add(_isOnline(result.isNotEmpty ? result.first : ConnectivityResult.none));
    });
  }

  bool _isOnline(ConnectivityResult result) {
    // Treat wifi/mobile/ethernet as online, none as offline
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet;
  }

  void dispose() {
    _connectionController.close();
  }
}
