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

double? selectedAspectRatio;
int? selectedHeight;
int? selectedWidth;

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  List<img.Image> _originalImages = [];
  bool _isSaved = false;
  bool _isLoading = false;
  List<File> _imageFiles = [];
  NamedColorFilter _selectedFilter =
      NamedColorFilter(colorFilterMatrix: [], name: 'None');

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
        requestFullMetadata: false,
        limit: 10,
        maxWidth: 1440, // recommended max size, do NOT change
        maxHeight: 1800, // recommended max size, do NOT change
        imageQuality: 100);

    selectedAspectRatio = null;
    selectedHeight = null;
    selectedWidth = null;

    if (pickedFiles.length > 0) {
      debugPrint("Picked " + pickedFiles.length.toString() + " images");
      _imageFiles =
          pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
      debugPrint("Mapped images");
      await _loadImages(_imageFiles);
      debugPrint("Cropped, resized and loaded images into UI");
    } else {
      debugPrint("No images selected.");
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadImages(List<File> imageFiles) async {
    _originalImages = await Future.wait(imageFiles.map((file) async {
      final imageBytes = await file.readAsBytes();

      img.Image? thisImg = img.decodeImage(imageBytes);

      if (selectedAspectRatio == null) {
        final finalAspectRatio =
            selectBestAspectRatio(thisImg!.width, thisImg.height);

        selectedAspectRatio = finalAspectRatio['ratio']!;
        selectedHeight = finalAspectRatio['height']!.toInt();
        selectedWidth = finalAspectRatio['width']!.toInt();
      }

      //return thisImg!;

      return cropAndResize(
        thisImg!,
        aspectRatio: selectedAspectRatio!,
        targetHeight: selectedHeight!,
        targetWidth: selectedWidth!,
      );
    }).toList());

    setState(() {
      _selectedFilter = NamedColorFilter(
          colorFilterMatrix: [], name: 'None'); // Reset the selected filter
    });
  }

  Future<void> _applyFilter(NamedColorFilter filter) async {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _saveImages(bool saveImagesToGallery) async {
    List<Future<img.Image>> processingFutures = [];
    List<Future<void>> savingFutures = [];

    try {
      // Process images in parallel
      for (var image in _originalImages) {
        debugPrint("Added image to processor...");
        processingFutures.add(Future(() async {
          ApplyFilterParams params = ApplyFilterParams(
            img: img.copyResize(image,
                height: image.height, width: image.width)!,
            colorMatrix: _selectedFilter.colorFilterMatrix,
          );

          if (params.colorMatrix.isNotEmpty) {
            return await FilterManager.applyFilter(params);
          } else {
            return image;
          }
        }).then((result) => result));
      }
      debugPrint("Adding future processing finished, start processing now");
      // Wait for all images to be processed
      List<img.Image> processedImages = await Future.wait(processingFutures);
      debugPrint("Images processing finished");

      if (saveImagesToGallery) {
        for (var processedImage in processedImages) {
          debugPrint("Added image to save...");
          savingFutures.add(Future(() async {
            await ImageProcessor.saveImage(processedImage, false, 100);
          }));
        }
        debugPrint("Finished adding images to save list...");
        // Start saving all images in parallel and wait for completion
        await Future.wait(savingFutures);
        debugPrint("Images saving finished");
      }

      // Update UI state
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
                    _saveImages(false);
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
