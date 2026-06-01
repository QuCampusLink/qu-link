import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'bus_models.dart';

class BusEtaInfo {
  final double distanceMeters;
  final int etaMinutes;
  final String distanceText;
  final String etaText;

  const BusEtaInfo({
    required this.distanceMeters,
    required this.etaMinutes,
    required this.distanceText,
    required this.etaText,
  });
}

/// Distance-based ETA estimates styled like Google Maps transit.
class BusEtaHelper {
  BusEtaHelper._();

  static const double _earthRadiusM = 6371000;
  static const double averageSpeedKmh = 22;

  static BusEtaInfo compute(LatLng busLocation, LatLng stopLocation) {
    final distance = distanceMeters(busLocation, stopLocation);
    final etaMinutes = estimateMinutes(distance);
    return BusEtaInfo(
      distanceMeters: distance,
      etaMinutes: etaMinutes,
      distanceText: formatDistance(distance),
      etaText: formatEta(etaMinutes),
    );
  }

  static double distanceMeters(LatLng from, LatLng to) {
    final lat1Rad = from.latitude * (math.pi / 180);
    final lat2Rad = to.latitude * (math.pi / 180);
    final deltaLatRad = (to.latitude - from.latitude) * (math.pi / 180);
    final deltaLngRad = (to.longitude - from.longitude) * (math.pi / 180);

    final a = math.pow(math.sin(deltaLatRad / 2), 2).toDouble() +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.pow(math.sin(deltaLngRad / 2), 2).toDouble();
    final c = 2 * math.asin(math.sqrt(a));

    return _earthRadiusM * c;
  }

  static int estimateMinutes(double distanceMeters) {
    if (distanceMeters < 50) return 1;

    final speedMps = averageSpeedKmh * 1000 / 3600;
    final minutes = (distanceMeters / speedMps / 60).ceil();
    return minutes.clamp(1, 120);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatEta(int minutes) {
    return '$minutes min';
  }

  static InfoWindow buildInfoWindow({
    required Bus bus,
    required String routeName,
    String? stopName,
    BusEtaInfo? eta,
  }) {
    final busLabel = bus.id.contains('_') ? bus.id.split('_').last : bus.id;

    if (eta != null && stopName != null) {
      return InfoWindow(
        title: eta.etaText,
        snippet: '${eta.distanceText} · $stopName',
      );
    }

    return InfoWindow(
      title: 'Bus $busLabel',
      snippet: routeName,
    );
  }

  static void showOnMap({
    required GoogleMapController? mapController,
    required String markerId,
  }) {
    if (mapController == null) return;
    mapController.showMarkerInfoWindow(MarkerId(markerId));
  }

  static void hideFromMap({
    required GoogleMapController? mapController,
    required String? markerId,
  }) {
    if (mapController == null || markerId == null) return;
    mapController.hideMarkerInfoWindow(MarkerId(markerId));
  }
}

/// Google Maps-style floating card anchored to the bottom of the map.
class BusEtaMapCard extends StatelessWidget {
  final String busLabel;
  final String routeName;
  final String stopName;
  final BusEtaInfo eta;
  final Color routeColor;
  final VoidCallback onClose;

  const BusEtaMapCard({
    super.key,
    required this.busLabel,
    required this.routeName,
    required this.stopName,
    required this.eta,
    required this.routeColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADCE0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 44,
                          margin: const EdgeInsets.only(right: 12, top: 2),
                          decoration: BoxDecoration(
                            color: routeColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                busLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF202124),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$routeName · to $stopName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5F6368),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Color(0xFF5F6368),
                          ),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          eta.distanceText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            eta.etaText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF137333),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
