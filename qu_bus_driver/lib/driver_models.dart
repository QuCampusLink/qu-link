
/// Represents the status of a bus
enum BusStatus {
  running,
  stopped,
  outOfService,
  delayed,
  unknown,
}

/// Represents bus location data sent to Convex
class BusLocationData {
  final String busId;
  final String driverName;
  final String routeId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final BusStatus status;

  BusLocationData({
    required this.busId,
    required this.driverName,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'driverName': driverName,
      'routeId': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
    };
  }

  factory BusLocationData.fromJson(Map<String, dynamic> json) {
    return BusLocationData(
      busId: json['busId'],
      driverName: json['driverName'],
      routeId: json['routeId'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      status: BusStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => BusStatus.unknown,
      ),
    );
  }

  @override
  String toString() {
    return 'BusLocationData(busId: $busId, driverName: $driverName, routeId: $routeId, lat: $latitude, lng: $longitude, status: $status)';
  }
}

