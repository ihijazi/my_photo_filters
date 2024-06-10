import 'package:image/image.dart' as img;

const List<Map<String, double>> standardAspectRatios = [
  {'ratio': 1.0, 'width': 1440, 'height': 1440}, // 1:1 Square
  {'ratio': 4 / 3, 'width': 1440, 'height': 1080}, // 4:3 Portrait
  {'ratio': 4 / 5, 'width': 1440, 'height': 1800}, // 4:5 Portrait
  {'ratio': 1.91, 'width': 1440, 'height': 754}, // 1.91:1 Landscape
];

Map<String, double> selectBestAspectRatio(
    int originalWidth, int originalHeight) {
  double minCroppingRatio = double.infinity;
  Map<String, double> bestAspectRatio = standardAspectRatios[0];

  for (var aspectRatio in standardAspectRatios) {
    double croppingRatio = calculateCroppingRatio(
        originalWidth, originalHeight, aspectRatio['ratio']!);
    if (croppingRatio < minCroppingRatio) {
      minCroppingRatio = croppingRatio;
      bestAspectRatio = aspectRatio;
    }
  }
  return bestAspectRatio;
}

double calculateCroppingRatio(
    int originalWidth, int originalHeight, double targetAspectRatio) {
  double originalAspectRatio = originalWidth / originalHeight;
  if (originalAspectRatio > targetAspectRatio) {
    // Width will be cropped
    double targetWidth = originalHeight * targetAspectRatio;
    return (originalWidth - targetWidth) / originalWidth;
  } else {
    // Height will be cropped
    double targetHeight = originalWidth / targetAspectRatio;
    return (originalHeight - targetHeight) / originalHeight;
  }
}

img.Image cropAndResize(
  img.Image image, {
  required int targetWidth,
  required int targetHeight,
  double aspectRatio = 1.0,
  int? cropX,
  int? cropY,
  int? cropWidth,
  int? cropHeight,
}) {
  final width = image.width;
  final height = image.height;

  int newWidth, newHeight;

  // Determine new dimensions based on aspect ratio
  if (width / height > aspectRatio) {
    newHeight = height;
    newWidth = (height * aspectRatio).toInt();
  } else {
    newWidth = width;
    newHeight = (width / aspectRatio).toInt();
  }

  // Use provided crop parameters or default to center crop
  final cropStartX = cropX ?? (width - newWidth) ~/ 2;
  final cropStartY = cropY ?? (height - newHeight) ~/ 2;
  final cropW = cropWidth ?? newWidth;
  final cropH = cropHeight ?? newHeight;

  final croppedImage = img.copyCrop(
    image,
    x: cropStartX,
    y: cropStartY,
    width: cropW,
    height: cropH,
  );

  return img.copyResize(croppedImage, height: targetHeight, width: targetWidth);
}
