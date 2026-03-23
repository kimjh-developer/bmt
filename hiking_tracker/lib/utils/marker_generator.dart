import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:io';

class MarkerGenerator {
  /// Generates a marker indicating an interesting start or end point.
  static Future<Uint8List> createTextMarker(
      String text, {
      required Color backgroundColor,
      Color textColor = Colors.white,
      double size = 100.0,
      bool hasBorder = true,
      }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint paint = Paint()..color = backgroundColor;
    final double radius = size / 2;

    // Draw solid circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    if (hasBorder) {
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.1;
      canvas.drawCircle(Offset(radius, radius), radius - (size * 0.05), borderPaint);
    }

    // Draw text inside the circle
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size * 0.5,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - (textPainter.width / 2),
        radius - (textPainter.height / 2),
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Generates a marker with an icon inside a circle.
  static Future<Uint8List> createIconMarker(
      IconData iconData, {
      required Color backgroundColor,
      Color iconColor = Colors.white,
      double size = 100.0,
      bool hasBorder = true,
      }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint paint = Paint()..color = backgroundColor;
    final double radius = size / 2;

    // Draw solid circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    if (hasBorder) {
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.1;
      canvas.drawCircle(Offset(radius, radius), radius - (size * 0.05), borderPaint);
    }

    // Draw icon inside the circle
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: iconColor,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        radius - (textPainter.width / 2),
        radius - (textPainter.height / 2),
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Generates a marker indicating a taken photo using its actual image file.
  static Future<Uint8List> createImageMarker(
      String imagePath, {
      Color borderColor = Colors.white,
      double size = 120.0,
      bool hasBorder = true,
      }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final double radius = size / 2;
    
    // Draw background border circle
    if (hasBorder) {
      final Paint borderPaint = Paint()..color = borderColor;
      canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
    }
    
    // Load the image file
    final file = File(imagePath);
    ui.Image? image;
    if (file.existsSync()) {
      try {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: size.toInt(), targetHeight: size.toInt());
        final frame = await codec.getNextFrame();
        image = frame.image;
      } catch (e) {
        // Fallback on error
      }
    }

    if (image != null) {
      final double imageRadius = hasBorder ? radius - (size * 0.05) : radius;
      Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: imageRadius));
      canvas.clipPath(clipPath);

      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: Offset(radius, radius), radius: imageRadius),
        image: image,
        fit: BoxFit.cover,
      );
    } else {
      // Fallback
      final Paint fallbackPaint = Paint()..color = Colors.orange;
      final double imageRadius = hasBorder ? radius - (size * 0.05) : radius;
      canvas.drawCircle(Offset(radius, radius), imageRadius, fallbackPaint);
      
      final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: '📷',
        style: TextStyle(fontSize: size * 0.4),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(radius - (textPainter.width / 2), radius - (textPainter.height / 2)),
      );
    }

    final ui.Image resultImage = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final ByteData? byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

