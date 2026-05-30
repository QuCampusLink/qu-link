/// Data models for the QU Bus Tracker
///
/// This file contains the core data classes used across the app: `Bus`,
/// `BusRoute`, `BusStop`, and related value objects. Each class includes
/// serialization helpers (`fromJson`/`toJson`), basic validation, and
/// utility methods (e.g. `copyWith`, equality) so UI and services can
/// exchange structured data consistently.
///
/// Responsibilities:
/// - Define app-wide data shapes
/// - Provide stable JSON mappings for backend services
/// - Keep lightweight helpers for maps/geolocation integration

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a bus stop in the university
class BusStop {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final List<String> routes; // Route IDs that pass through this stop
  final String? gender; // 'male', 'female', or null for all

  BusStop({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.routes,
    this.gender,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      location: LatLng(
        json['location']['lat'],
        json['location']['lng'],
      ),
      routes: List<String>.from(json['routes']),
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'routes': routes,
      'gender': gender,
    };
  }
}

/// Represents a bus route
class BusRoute {
  final String id;
  final String name;
  final String description;
  final String color; // Hex color code
  final List<String> stopIds; // Ordered list of stop IDs
  final Duration estimatedDuration;
  final bool isActive;

  BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.stopIds,
    required this.estimatedDuration,
    this.isActive = true,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      color: json['color'],
      stopIds: List<String>.from(json['stopIds']),
      estimatedDuration: Duration(minutes: json['estimatedDuration']),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'stopIds': stopIds,
      'estimatedDuration': estimatedDuration.inMinutes,
      'isActive': isActive,
    };
  }
}

/// Represents a bus vehicle
class Bus {
  final String id;
  final String routeId;
  final String driverName;
  final int capacity;
  final LatLng currentLocation;
  final double heading; // Direction in degrees
  final DateTime lastUpdated;
  final BusStatus status;
  final int currentStopIndex; // Which stop the bus is currently at
  final DateTime? estimatedArrival; // Next stop arrival time

  Bus({
    required this.id,
    required this.routeId,
    required this.driverName,
    required this.capacity,
    required this.currentLocation,
    required this.heading,
    required this.lastUpdated,
    required this.status,
    required this.currentStopIndex,
    this.estimatedArrival,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'],
      routeId: json['routeId'],
      driverName: json['driverName'],
      capacity: json['capacity'],
      currentLocation: LatLng(
        json['currentLocation']['lat'],
        json['currentLocation']['lng'],
      ),
      heading: json['heading'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      status: BusStatus.values.firstWhere(
        (e) => e.toString() == 'BusStatus.${json['status']}',
        orElse: () => BusStatus.unknown,
      ),
      currentStopIndex: json['currentStopIndex'],
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'driverName': driverName,
      'capacity': capacity,
      'currentLocation': {
        'lat': currentLocation.latitude,
        'lng': currentLocation.longitude,
      },
      'heading': heading,
      'lastUpdated': lastUpdated.toIso8601String(),
      'status': status.toString().split('.').last,
      'currentStopIndex': currentStopIndex,
      'estimatedArrival': estimatedArrival?.toIso8601String(),
    };
  }
}

/// Represents the status of a bus
enum BusStatus {
  running,
  stopped,
  outOfService,
  delayed,
  unknown,
}

