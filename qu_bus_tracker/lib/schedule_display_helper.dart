import 'package:flutter/material.dart';

import 'schedule_service.dart';

/// Helpers for showing Convex pre-timed schedule data at a stop.
class ScheduleDisplayHelper {
  static String labelForKey(String scheduleKey) {
    const labels = {
      'female blue': 'Blue Route',
      'female light blue': 'Light Blue Route',
      'female dark green': 'Dark Green Route',
      'female light green': 'Light Green Route',
      'female purple': 'Purple Route',
      'female pink': 'Pink Route',
      'female orange': 'Orange Route',
      'female red': 'Red Line',
      'female zone a': 'Zone A',
      'female zone b': 'Zone B',
      'female zone c': 'Zone C',
      'female metro a': 'Metro A',
      'female metro b': 'Metro B',
      'female metro c': 'Metro C',
      'male black': 'Black Line',
      'male white': 'White Line',
      'male brown': 'Brown Line',
      'male maroon': 'Maroon Line',
      'mhostel1': 'Male Hostel Bus 1',
      'mhostel2': 'Male Hostel Bus 2',
      'mhostel3': 'Male Hostel Bus 3',
      'fhostela': 'Female Hostel Bus A',
      'fhostelb': 'Female Hostel Bus B',
      'fhostelc': 'Female Hostel Bus C',
    };
    return labels[scheduleKey] ??
        scheduleKey.split(' ').map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ');
  }

  static Color colorForKey(String scheduleKey) {
    const colors = {
      'female blue': Color(0xFF1976D2),
      'female light blue': Color(0xFF42A5F5),
      'female dark green': Color(0xFF388E3C),
      'female light green': Color(0xFF66BB6A),
      'female purple': Color(0xFF7B1FA2),
      'female pink': Color(0xFFC2185B),
      'female orange': Color(0xFFF57C00),
      'female red': Color(0xFFD32F2F),
      'female zone a': Color(0xFF757575),
      'female zone b': Color(0xFF616161),
      'female zone c': Color(0xFF424242),
      'female metro a': Color(0xFF00897B),
      'female metro b': Color(0xFF00796B),
      'female metro c': Color(0xFF00695C),
      'male black': Color(0xFF212121),
      'male white': Color(0xFF757575),
      'male brown': Color(0xFF5D4037),
      'male maroon': Color(0xFF8D6E63),
      'mhostel1': Color(0xFF1565C0),
      'mhostel2': Color(0xFF1976D2),
      'mhostel3': Color(0xFF1E88E5),
      'fhostela': Color(0xFFAD1457),
      'fhostelb': Color(0xFFC2185B),
      'fhostelc': Color(0xFFD81B60),
    };
    return colors[scheduleKey] ?? const Color(0xFF8B0000);
  }

  static String summaryLine(
    Map<String, List<int>> schedule,
    ScheduleService scheduleService,
  ) {
    if (schedule.isEmpty) return 'No scheduled buses for this stop';

    final parts = <String>[];
    for (final entry in schedule.entries.take(3)) {
      final next = entry.value.isNotEmpty ? entry.value.first : null;
      if (next == null) continue;
      final eta = scheduleService.getMinutesUntilArrival(next);
      parts.add('${labelForKey(entry.key)}: $eta min');
    }
    return parts.join(' • ');
  }
}
