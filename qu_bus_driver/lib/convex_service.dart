import 'dart:async';

import 'package:flutter/foundation.dart';

import 'convex_http_client.dart';
import 'driver_models.dart';

class ConvexService extends ChangeNotifier {
  final ConvexHttpClient _client = ConvexHttpClient.instance;

  bool get isConnected => _client.isConnected;

  Future<void> initialize() async {
    try {
      await _client.ping();
      debugPrint('Convex initialized successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Convex initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      _client.markDisconnected();
      notifyListeners();
    }
  }

  Future<void> sendBusLocation(BusLocationData busData) async {
    try {
      await _client.mutation('buses:upsertLocation', {
        'busId': busData.busId,
        'driverName': busData.driverName,
        'routeId': busData.routeId,
        'latitude': busData.latitude,
        'longitude': busData.longitude,
        'timestamp': busData.timestamp.millisecondsSinceEpoch,
        'status': busData.status.toString().split('.').last,
      });
      debugPrint('Bus location sent to Convex: ${busData.busId}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending bus location to Convex: $e');
      _client.markDisconnected();
      notifyListeners();
    }
  }

  Future<void> updateBusStatus(String busId, BusStatus status) async {
    try {
      await _client.mutation('buses:updateStatus', {
        'busId': busId,
        'status': status.toString().split('.').last,
      });
      debugPrint('Bus status updated in Convex: $busId - $status');
    } catch (e) {
      debugPrint('Error updating bus status in Convex: $e');
    }
  }

  Future<void> removeBus(String busId) async {
    try {
      await _client.mutation('buses:remove', {'busId': busId});
      debugPrint('Bus removed from Convex: $busId');
    } catch (e) {
      debugPrint('Error removing bus from Convex: $e');
    }
  }
}
