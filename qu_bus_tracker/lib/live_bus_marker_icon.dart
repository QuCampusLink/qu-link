import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Cached 🚌 map marker for live driver buses.
class LiveBusMarkerIcon {
  LiveBusMarkerIcon._();

  static BitmapDescriptor? _cached;

  static Future<BitmapDescriptor> get() async {
    if (_cached != null) return _cached!;

    const emoji = '🚌';
    const size = 96.0;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF8B0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4, borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: emoji,
        style: TextStyle(fontSize: 44),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2 - 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    _cached = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    return _cached!;
  }
}
