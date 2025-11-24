// services/network_service.dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for network status
  final _networkStatusController = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get networkStatusStream => _networkStatusController.stream;
  
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  NetworkStatus get currentStatus => _currentStatus;
  
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus == NetworkStatus.offline;
  
  // ✅ FIXED: Changed type to match connectivity_plus package
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Initialize network monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(result);
      
      // ✅ FIXED: Listen to connectivity changes (returns single ConnectivityResult, not List)
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          print('❌ Network monitoring error: $error');
        },
      );
      
      print('✅ Network service initialized');
    } catch (e) {
      print('❌ Network initialization error: $e');
    }
  }

  /// ✅ FIXED: Update connection status - accepts single ConnectivityResult
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    NetworkStatus newStatus;
    
    if (result == ConnectivityResult.none) {
      newStatus = NetworkStatus.offline;
    } else {
      // For web, we assume online if not "none"
      // For mobile, we have wifi, mobile, ethernet, bluetooth, vpn, other
      newStatus = NetworkStatus.online;
    }
    
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _networkStatusController.add(_currentStatus);
      
      if (_currentStatus == NetworkStatus.online) {
        print('✅ Network: ONLINE (${result.name})');
      } else {
        print('⚠️ Network: OFFLINE');
      }
    }
  }

  /// Dispose network service
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}