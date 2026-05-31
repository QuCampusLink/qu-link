import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class LocationService extends ChangeNotifier {
  Position? _currentLocation;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  Position? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;

  Future<bool> _checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return status.isGranted;
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

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _isTracking = true;
    notifyListeners();

    // Seed an immediate fix before the stream delivers the first event.
    _currentLocation = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    notifyListeners();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _currentLocation = position;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Location tracking error: $error');
        _isTracking = false;
        notifyListeners();
      },
    );
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentLocation = position;
      notifyListeners();
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
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
    stopLocationTracking();
    super.dispose();
  }
}
