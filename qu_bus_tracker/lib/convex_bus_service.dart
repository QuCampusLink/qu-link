/// Convex-backed bus service
///
/// Polls live bus positions from Convex and maps them to local `Bus` models.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bus_models.dart';
import 'convex_http_client.dart';

class ConvexBusService extends ChangeNotifier {
  final ConvexHttpClient _client = ConvexHttpClient.instance;
  Timer? _pollTimer;
  Map<String, Bus> _liveBuses = {};

  Map<String, Bus> get liveBuses => Map.from(_liveBuses);
  bool get isConnected => _client.isConnected;

  Future<void> initialize() async {
    try {
      await _client.ping();
      try {
        await _client.mutation('buses:pruneStale', {});
      } catch (e) {
        debugPrint('Stale bus prune skipped: $e');
      }
      await _refreshBuses();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _refreshBuses();
      });
      debugPrint('Convex Bus Service initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Convex Bus Service initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      _client.markDisconnected();
      notifyListeners();
    }
  }

  Future<void> _refreshBuses() async {
    try {
      final result = await _client.query('buses:listActive', {});
      _parseBuses(result);
    } catch (e) {
      debugPrint('Error polling buses from Convex: $e');
      _client.markDisconnected();
      notifyListeners();
    }
  }

  void _parseBuses(dynamic value) {
    if (value is! List) {
      _liveBuses.clear();
      notifyListeners();
      return;
    }

    _liveBuses.clear();

    for (final item in value) {
      if (item is! Map) continue;
      final busData = Map<String, dynamic>.from(item);

      try {
        final busId = busData['busId']?.toString() ?? '';
        if (busId.isEmpty) continue;

        final driverName = busData['driverName']?.toString() ?? 'Unknown Driver';
        final routeId = busData['routeId']?.toString() ?? '';

        final lat = _toDouble(busData['latitude']);
        final lng = _toDouble(busData['longitude']);
        if (lat == 0.0 && lng == 0.0) continue;

        final lastUpdatedMs = _toInt(
          busData['lastUpdated'] ?? busData['timestamp'],
          DateTime.now().millisecondsSinceEpoch,
        );
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdatedMs;
        if (age > const Duration(minutes: 3).inMilliseconds) continue;

        _liveBuses[busId] = Bus(
          id: busId,
          routeId: routeId,
          driverName: driverName.isEmpty ? 'Unknown Driver' : driverName,
          capacity: 0,
          currentLocation: LatLng(lat, lng),
          heading: 0.0,
          lastUpdated: DateTime.fromMillisecondsSinceEpoch(
            _toInt(busData['timestamp'], DateTime.now().millisecondsSinceEpoch),
          ),
          status: _parseBusStatus(busData['status']?.toString() ?? 'unknown'),
          currentStopIndex: 0,
          estimatedArrival: null,
        );
      } catch (e) {
        debugPrint('Error parsing Convex bus data: $e');
      }
    }

    notifyListeners();
    if (_liveBuses.isNotEmpty) {
      for (final bus in _liveBuses.values) {
        debugPrint(
          'Live bus ${bus.id} @ '
          '${bus.currentLocation.latitude}, ${bus.currentLocation.longitude}',
        );
      }
    }
    debugPrint('Updated ${_liveBuses.length} live buses from Convex');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  BusStatus _parseBusStatus(String status) {
    switch (status.toLowerCase()) {
      case 'running':
        return BusStatus.running;
      case 'stopped':
        return BusStatus.stopped;
      case 'outofservice':
        return BusStatus.outOfService;
      case 'delayed':
        return BusStatus.delayed;
      default:
        return BusStatus.unknown;
    }
  }

  List<Bus> getAllActiveBuses() {
    return _liveBuses.values
        .where((bus) => bus.status == BusStatus.running)
        .toList();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
