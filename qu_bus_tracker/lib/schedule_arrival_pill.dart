import 'package:flutter/material.dart';

import 'schedule_service.dart';

/// Styled chip for a scheduled arrival (today ETA or tomorrow time).
class ScheduleArrivalPill extends StatelessWidget {
  final int busTimeMinutes;
  final ScheduleService scheduleService;

  const ScheduleArrivalPill({
    super.key,
    required this.busTimeMinutes,
    required this.scheduleService,
  });

  @override
  Widget build(BuildContext context) {
    if (scheduleService.isTomorrow(busTimeMinutes)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wb_twilight_outlined,
              size: 16,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TOMORROW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  scheduleService.formatMinutes(busTimeMinutes),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2933),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final eta = scheduleService.getMinutesUntilArrival(busTimeMinutes);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F9E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$eta min',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF037F4C),
        ),
      ),
    );
  }
}
