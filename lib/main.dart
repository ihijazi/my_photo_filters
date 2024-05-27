import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_photo_filters/image_processor.dart';
import 'filter_manager.dart';
import 'apply_filter_params.dart';
import 'named_color_filter.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImageProcessorScreen(),
    );
  }
}

class ImageProcessorScreen extends StatefulWidget {
  @override
  _ImageProcessorScreenState createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  List<img.Image> _originalImages = [];
  bool _isSaved = false;
  List<File> _imageFiles = [];
  NamedColorFilter _selectedFilter =
      NamedColorFilter(colorFilterMatrix: [], name: 'None');

  Future<void> _pickImages() async {
    final stopwatch = Stopwatch()..start();
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    stopwatch.stop();
    print('Time taken to pick images: ${stopwatch.elapsedMilliseconds} ms');

    if (pickedFiles != null) {
      _imageFiles =
          pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
      await _loadImages(_imageFiles);
      setState(() {
        _isSaved = false; // Reset saved status
      });
    } else {
      print("No images selected.");
    }
  }

  Future<void> _loadImages(List<File> imageFiles) async {
    final stopwatch = Stopwatch()..start();
    _originalImages = await Future.wait(imageFiles.map((file) async {
      final imageBytes = await file.readAsBytes();
      return img.decodeImage(imageBytes)!;
    }).toList());
    stopwatch.stop();
    print('Time taken to load images: ${stopwatch.elapsedMilliseconds} ms');

    if (_originalImages.isNotEmpty) {
      stopwatch.reset();
      stopwatch.start();
      _originalImages = _originalImages.map((image) {
        return _cropAndResize(image, maxSize: 1080, aspectRatio: 1.0);
      }).toList();
      stopwatch.stop();
      print(
          'Time taken to crop and resize images: ${stopwatch.elapsedMilliseconds} ms');

      setState(() {
        _selectedFilter = NamedColorFilter(
            colorFilterMatrix: [], name: 'None'); // Reset the selected filter
      });
    }
  }

  Future<void> _applyFilter(NamedColorFilter filter) async {
    final stopwatch = Stopwatch()..start();
    setState(() {
      _selectedFilter = filter;
    });
    stopwatch.stop();
    print('Time taken to apply filter: ${stopwatch.elapsedMilliseconds} ms');
  }

  img.Image _cropAndResize(
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

  Future<void> _saveImages() async {
    final stopwatch = Stopwatch()..start();

    List<img.Image> processedImages = [];

    try {
      for (var image in _originalImages) {
        ApplyFilterParams params = ApplyFilterParams(
          img: img.copyResize(image, height: image.height, width: image.width)!,
          colorMatrix: _selectedFilter.colorFilterMatrix,
        );

        img.Image processedImage;

        if (params.colorMatrix.isNotEmpty) {
          processedImage = await FilterManager.applyFilter(params);
        } else {
          processedImage = image;
        }
        processedImages.add(processedImage);
      }

      stopwatch.stop();
      print(
          'Time taken to apply filter to images: ${stopwatch.elapsedMilliseconds} ms');

      stopwatch.reset();
      stopwatch.start();

      for (var processedImage in processedImages) {
        ImageProcessor.saveImage(processedImage, false, 100);
      }

      stopwatch.stop();
      print('Time taken to save images: ${stopwatch.elapsedMilliseconds} ms');

      setState(() {
        _isSaved = true;
      });
    } catch (e) {
      print("Failed to apply filter and save images: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Image Processor'),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: _imageFiles.isEmpty
                  ? Center(child: Text('No processed images.'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ColorFiltered(
                            colorFilter:
                                _selectedFilter.colorFilterMatrix.isEmpty
                                    ? ColorFilter.mode(
                                        Colors.transparent, BlendMode.multiply)
                                    : ColorFilter.matrix(
                                        _selectedFilter.colorFilterMatrix),
                            child: Image.file(_imageFiles[index]),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImages,
              child: Text('Pick Images'),
            ),
            SizedBox(height: 20),
            _presets(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveImages,
              child: Text('Save Images'),
            ),
            if (_isSaved)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Images saved successfully!',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            SizedBox(height: 20),
          ],
        ));
  }

  SizedBox _presets() {
    return SizedBox(
      height: 161,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: defaultColorFilters.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 1.0),
                  child: SizedBox(
                    width: 72,
                    height: 40,
                    child: Center(
                      child: Text(
                        defaultColorFilters[index].name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _applyFilter(defaultColorFilters[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ColorFiltered(
                      colorFilter:
                          defaultColorFilters[index].colorFilterMatrix.isEmpty
                              ? const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply)
                              : ColorFilter.matrix(
                                  defaultColorFilters[index].colorFilterMatrix),
                      child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(8.0)),
                          child: _imageFiles.isNotEmpty
                              ? Image.file(
                                  _imageFiles.first,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey,
                                )),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
