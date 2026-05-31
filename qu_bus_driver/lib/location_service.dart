import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentLocation;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Position? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  Stream<Position> get onLocation => _positionController.stream;

  LocationSettings get _locationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<bool> _checkPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  void _emitPosition(Position position) {
    _currentLocation = position;
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
    notifyListeners();
  }

  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    _isTracking = true;
    notifyListeners();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(
      (Position position) {
        debugPrint(
          'GPS update: ${position.latitude}, ${position.longitude} '
          '(accuracy ${position.accuracy.toStringAsFixed(0)}m, '
          'mocked=${position.isMocked})',
        );
        _emitPosition(position);
      },
      onError: (error) {
        debugPrint('Location tracking error: $error');
        _isTracking = false;
        notifyListeners();
      },
    );

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      _emitPosition(position);
    } catch (e) {
      debugPrint('Initial GPS fix pending: $e');
    }
  }

  Future<void> stopLocationTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );

      _emitPosition(position);
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return _currentLocation;
    }
  }

  double? getDistanceFromPoint(double lat, double lng) {
    if (_currentLocation == null) return null;

    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      lat,
      lng,
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionController.close();
    super.dispose();
  }
}
