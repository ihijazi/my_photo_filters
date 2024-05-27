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
  img.Image? _originalImage;
  bool _isSaved = false;
  File? _imageFile;
  NamedColorFilter _selectedFilter =
      NamedColorFilter(colorFilterMatrix: [], name: 'None');

  Future<void> _pickImage() async {
    final stopwatch = Stopwatch()..start();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    stopwatch.stop();
    print('Time taken to pick image: ${stopwatch.elapsedMilliseconds} ms');

    if (pickedFile != null) {
      _imageFile = File(pickedFile.path);
      await _loadImage(_imageFile!);
      setState(() {
        _isSaved = false; // Reset saved status
      });
    } else {
      print("No image selected.");
    }
  }

  Future<void> _loadImage(File imageFile) async {
    final stopwatch = Stopwatch()..start();
    final imageBytes = await imageFile.readAsBytes();
    _originalImage = img.decodeImage(imageBytes);
    stopwatch.stop();
    print('Time taken to load image: ${stopwatch.elapsedMilliseconds} ms');

    if (_originalImage != null) {
      stopwatch.reset();
      stopwatch.start();
      _originalImage =
          _cropAndResize(_originalImage!, maxSize: 1080, aspectRatio: 1.0);
      stopwatch.stop();
      print(
          'Time taken to crop and resize image: ${stopwatch.elapsedMilliseconds} ms');

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

  Future<void> _saveImage() async {
    final stopwatch = Stopwatch()..start();

    ApplyFilterParams params = ApplyFilterParams(
      img: img.copyResize(_originalImage!,
          height: _originalImage!.height, width: _originalImage!.width)!,
      colorMatrix: _selectedFilter.colorFilterMatrix,
    );

    img.Image processedImage;

    try {
      if (params.colorMatrix.isNotEmpty) {
        processedImage = await FilterManager.applyFilter(params);
      } else {
        processedImage = _originalImage!;
      }
      stopwatch.stop();
      print('Time taken to apply filter: ${stopwatch.elapsedMilliseconds} ms');

      stopwatch.reset();

      stopwatch.start();

      //ImageProcessor.saveImage(processedImage, true, 75);
      ImageProcessor.saveImage(processedImage, false, 100);

      stopwatch.stop();

      print('Time taken to save image: ${stopwatch.elapsedMilliseconds} ms');

      setState(() {
        _isSaved = true;
      });
    } catch (e) {
      print("Failed to apply filter and save image: $e");
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
              child: Center(
                child: _imageFile == null
                    ? Text('No processed image.')
                    : ColorFiltered(
                        colorFilter: _selectedFilter.colorFilterMatrix.isEmpty
                            ? ColorFilter.mode(
                                Colors.transparent, BlendMode.multiply)
                            : ColorFilter.matrix(
                                _selectedFilter.colorFilterMatrix),
                        child: Image.file(_imageFile!),
                      ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            _presets(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveImage,
              child: Text('Save Image'),
            ),
            if (_isSaved)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Image saved successfully!',
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
                          child: Image.file(
                            _imageFile!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
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
