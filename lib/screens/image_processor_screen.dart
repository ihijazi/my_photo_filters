import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_photo_filters/services/image_processor.dart';
import 'package:my_photo_filters/utils/image_utils.dart';
import 'package:my_photo_filters/widgets/image_list.dart';
import 'package:my_photo_filters/widgets/loading_indicator.dart';
import 'package:my_photo_filters/widgets/presets.dart';
import 'package:image/image.dart' as img;
import 'package:my_photo_filters/models/apply_filter_params.dart';
import 'package:my_photo_filters/services/filter_manager.dart';
import 'package:my_photo_filters/models/named_color_filter.dart';

class ImageProcessorScreen extends StatefulWidget {
  @override
  _ImageProcessorScreenState createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  List<img.Image> _originalImages = [];
  bool _isSaved = false;
  bool _isLoading = false;
  List<File> _imageFiles = [];
  NamedColorFilter _selectedFilter =
      NamedColorFilter(colorFilterMatrix: [], name: 'None');

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

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

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadImages(List<File> imageFiles) async {
    _originalImages = await Future.wait(imageFiles.map((file) async {
      final imageBytes = await file.readAsBytes();
      return img.decodeImage(imageBytes)!;
    }).toList());

    if (_originalImages.isNotEmpty) {
      _originalImages = _originalImages.map((image) {
        return cropAndResize(image, maxSize: 1080, aspectRatio: 1.0);
      }).toList();

      setState(() {
        _selectedFilter = NamedColorFilter(
            colorFilterMatrix: [], name: 'None'); // Reset the selected filter
      });
    }
  }

  Future<void> _applyFilter(NamedColorFilter filter) async {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _saveImages() async {
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

      for (var processedImage in processedImages) {
        await ImageProcessor.saveImage(processedImage, false, 100);
      }

      setState(() {
        _isSaved = true;
        _isLoading = false;
      });
    } catch (e) {
      print("Failed to apply filter and save images: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Image Processor'),
        ),
        body: Stack(
          children: [
            Column(
              children: <Widget>[
                Expanded(
                  child: _imageFiles.isEmpty
                      ? Center(child: Text('No processed images.'))
                      : ImageList(
                          imageFiles: _imageFiles,
                          selectedFilter: _selectedFilter),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _pickImages();
                  },
                  child: Text('Pick Images'),
                ),
                SizedBox(height: 20),
                PresetsWidget(
                  imageFiles: _imageFiles,
                  onApplyFilter: _applyFilter,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });
                    _saveImages();
                  },
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
            ),
            if (_isLoading) LoadingIndicator(),
          ],
        ));
  }
}
