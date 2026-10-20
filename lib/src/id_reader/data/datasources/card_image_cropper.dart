import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Utility to crop captured full-frame camera snapshots to the exact
/// ISO/IEC 7810 ID-1 National Card frame (standard aspect ratio ~1.586).
class CardImageCropper {
  /// Crops the given camera snapshot [rawBytes] to the centered ID card viewfinder frame.
  /// Automatically normalizes EXIF orientation and trims background borders.
  static Future<Uint8List> cropToCardFrame(Uint8List rawBytes) async {
    try {
      final cropped = await compute(_cropIsolateWorker, rawBytes);
      return cropped ?? rawBytes;
    } catch (e) {
      debugPrint('[IMAGE_CROPPER] Notice: Crop fallback to original image: $e');
      return rawBytes;
    }
  }

  static Uint8List? _cropIsolateWorker(Uint8List rawBytes) {
    // 1. Decode image
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // 2. Normalize EXIF orientation (so portrait preview matches pixels)
    final oriented = img.bakeOrientation(decoded);

    final imgW = oriented.width;
    final imgH = oriented.height;

    // 3. ISO/IEC 7810 ID-1 standard aspect ratio: 85.60 mm / 53.98 mm = 1.58577
    const double cardRatio = 85.60 / 53.98;

    final int cropW;
    final int cropH;

    if (imgH >= imgW) {
      // Portrait device orientation: Card spans width
      // The viewfinder box is ~88% of screen width
      cropW = (imgW * 0.88).round().clamp(10, imgW);
      cropH = (cropW / cardRatio).round().clamp(10, imgH);
    } else {
      // Landscape orientation: Card spans height
      cropH = (imgH * 0.88).round().clamp(10, imgH);
      cropW = (cropH * cardRatio).round().clamp(10, imgW);
    }

    final cropX = ((imgW - cropW) / 2).round().clamp(0, imgW - cropW);
    final cropY = ((imgH - cropH) / 2).round().clamp(0, imgH - cropH);

    // 4. Crop exactly to card frame
    final croppedImage = img.copyCrop(
      oriented,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    // 5. Re-encode to high-quality JPEG
    return Uint8List.fromList(img.encodeJpg(croppedImage, quality: 92));
  }
}
