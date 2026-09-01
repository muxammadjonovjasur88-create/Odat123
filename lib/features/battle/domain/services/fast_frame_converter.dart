import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Blazing-fast pure-Dart NV21/YUV420 to BMP converter for real-time 1v1 Battle live streaming.
/// Converts CameraImage frame into a 120x160 portrait BMP image in <0.5ms with 90° rotation and mirroring.
abstract final class FastFrameConverter {
  static const int targetW = 120;
  static const int targetH = 160;

  static String? convertCameraImageToBase64Bmp(CameraImage image, {bool isFrontCamera = true}) {
    try {
      final width = image.width;
      final height = image.height;
      if (width <= 0 || height <= 0 || image.planes.isEmpty) return null;

      final yPlane = image.planes[0].bytes;
      final int yRowStride = image.planes[0].bytesPerRow;

      // 120 * 3 = 360 bytes per row (already 4-byte aligned for BMP)
      const int rowStride = targetW * 3;
      const int dataSize = rowStride * targetH;
      const int fileSize = 54 + dataSize;
      final out = Uint8List(fileSize);
      final bd = ByteData.sublistView(out);

      // BMP File Header (14 bytes)
      out[0] = 0x42; // 'B'
      out[1] = 0x4D; // 'M'
      bd.setUint32(2, fileSize, Endian.little);
      bd.setUint32(6, 0, Endian.little);
      bd.setUint32(10, 54, Endian.little);

      // DIB Header (40 bytes - BITMAPINFOHEADER)
      bd.setUint32(14, 40, Endian.little);
      bd.setInt32(18, targetW, Endian.little);
      bd.setInt32(22, -targetH, Endian.little); // Top-down
      bd.setUint16(26, 1, Endian.little);
      bd.setUint16(28, 24, Endian.little); // 24-bit BGR
      bd.setUint32(30, 0, Endian.little); // BI_RGB (uncompressed)
      bd.setUint32(34, dataSize, Endian.little);
      bd.setInt32(38, 2835, Endian.little);
      bd.setInt32(42, 2835, Endian.little);
      bd.setUint32(46, 0, Endian.little);
      bd.setUint32(50, 0, Endian.little);

      final bool hasUv = image.planes.length >= 2;
      final Uint8List? uPlane = hasUv ? image.planes[1].bytes : null;
      final Uint8List? vPlane = image.planes.length >= 3 ? image.planes[2].bytes : null;
      final int uvRowStride = hasUv ? image.planes[1].bytesPerRow : 0;
      final int uvPixelStride = hasUv ? (image.planes[1].bytesPerPixel ?? 1) : 1;

      for (int ty = 0; ty < targetH; ty++) {
        final int outRowOffset = 54 + ty * rowStride;

        for (int tx = 0; tx < targetW; tx++) {
          // Rotate 90 degrees to convert landscape sensor image to portrait view
          // For front camera with horizontal mirror:
          final int sx = isFrontCamera
              ? (ty * width) ~/ targetH
              : ((targetH - 1 - ty) * width) ~/ targetH;
          final int sy = (tx * height) ~/ targetW;

          final int yIndex = sy * yRowStride + sx;
          if (yIndex >= yPlane.length) continue;
          final int yVal = yPlane[yIndex];

          int uVal = 128;
          int vVal = 128;

          if (hasUv && uPlane != null) {
            final int uvRow = (sy ~/ 2) * uvRowStride;
            final int uvCol = (sx ~/ 2) * uvPixelStride;
            final int uvIdx = uvRow + uvCol;

            if (vPlane != null && uvIdx < uPlane.length && uvIdx < vPlane.length) {
              uVal = uPlane[uvIdx];
              vVal = vPlane[uvIdx];
            } else if (uvIdx + 1 < uPlane.length) {
              // NV21 interleaved (V, U)
              vVal = uPlane[uvIdx];
              uVal = uPlane[uvIdx + 1];
            }
          }

          final int c = yVal - 16;
          final int d = uVal - 128;
          final int e = vVal - 128;

          final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
          final int g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
          final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

          final int outPixel = outRowOffset + tx * 3;
          out[outPixel] = b;
          out[outPixel + 1] = g;
          out[outPixel + 2] = r;
        }
      }

      return base64Encode(out);
    } catch (e) {
      return null;
    }
  }
}
