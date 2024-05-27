import 'package:image/image.dart' as img;

img.Image cropAndResize(
  img.Image image, {
  int? maxSize,
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

  // Resize if necessary
  if (maxSize != null && (cropW > maxSize || cropH > maxSize)) {
    if (cropW > cropH) {
      return img.copyResize(croppedImage, width: maxSize);
    } else {
      return img.copyResize(croppedImage, height: maxSize);
    }
  }

  return croppedImage;
}
