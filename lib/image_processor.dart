import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class ImageProcessor {
  static Future<img.Image?> loadImage(File file) async {
    final List<int> bytes = await file.readAsBytes();
    return img.decodeImage(Uint8List.fromList(bytes));
  }

  static Future<File> saveImage(
      img.Image image, bool shouldCompress, int? compressQuality) async {
    image =
        shouldCompress ? compressImage(image, compressQuality ?? 75) : image;

    final Uint8List imageBytes = Uint8List.fromList(img.encodeJpg(image));
    final tempDir = await getTemporaryDirectory();
    final path = "${tempDir.path}/${generateRandomString()}.jpeg";
    final File file = File(path);
    await file.writeAsBytes(imageBytes);

    // Save image to gallery
    final result = await PhotoManager.editor
        .saveImage(imageBytes, title: generateRandomString());

    if (result != null) {
      print('Image saved to gallery: $result');
      return file;
    } else {
      throw Exception('Failed to save image to gallery');
    }
  }

  static img.Image compressImage(img.Image originalImage, int quality) {
    Uint8List? compressedBytes = img.encodeJpg(originalImage, quality: quality);
    return img.decodeImage(compressedBytes)!;
  }

  static String generateRandomString() {
    final random = Random();
    const availableChars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final randomString = List.generate(
            4, (index) => availableChars[random.nextInt(availableChars.length)])
        .join();
    return randomString;
  }
}
