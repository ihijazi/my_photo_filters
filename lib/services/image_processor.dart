import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

class ImageProcessor {
  static Future<void> saveImage(
      img.Image image, bool shouldCompress, int compressQuality) async {
    Uint8List imageUint8List = shouldCompress
        ? compressImage(image, compressQuality)
        : img.encodeJpg(image);

    final result =
        await PhotoManager.editor.saveImage(imageUint8List, title: '');

    if (result != null) {
      print('Image saved to gallery: $result');
    } else {
      throw Exception('Failed to save image to gallery');
    }
  }

  static Uint8List compressImage(img.Image originalImage, int quality) {
    return img.encodeJpg(originalImage, quality: quality);
  }
}
