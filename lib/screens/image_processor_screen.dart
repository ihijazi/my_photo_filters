import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:my_photo_filters/models/apply_filter_params.dart';
import 'package:my_photo_filters/models/named_color_filter.dart';
import 'package:my_photo_filters/services/filter_manager.dart';
import 'package:my_photo_filters/services/image_processor.dart';
import 'package:my_photo_filters/widgets/image_list.dart';
import 'package:my_photo_filters/widgets/loading_indicator.dart';
import 'package:my_photo_filters/widgets/presets.dart';

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

  final int _isolateCount = 1000; // Number of isolates in the pool
  List<Isolate> _isolates = [];
  List<SendPort> _sendPorts = [];

  @override
  void initState() {
    super.initState();
    _initializeIsolatePool();
  }

  @override
  void dispose() {
    _isolates.forEach((isolate) => isolate.kill());
    super.dispose();
  }

  Future<void> _initializeIsolatePool() async {
    for (int i = 0; i < _isolateCount; i++) {
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);
      final sendPort = await receivePort.first as SendPort;
      _isolates.add(isolate);
      _sendPorts.add(sendPort);
    }
  }

  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      final filePath = message[0] as String;
      final replyPort = message[1] as SendPort;

      try {
        File file = File(filePath);
        Uint8List bytes = await file.readAsBytes();
        replyPort.send(bytes);
      } catch (e) {
        replyPort.send('error');
      }
    });
  }

  Future<Uint8List> readFileAsync(File file) async {
    final completer = Completer<Uint8List>();
    final sendPort = _sendPorts[_imageFiles.indexOf(file) % _isolateCount];
    final receivePort = ReceivePort();

    sendPort.send([file.path, receivePort.sendPort]);

    receivePort.listen((message) {
      if (message is Uint8List) {
        completer.complete(message);
      } else {
        completer.completeError('Failed to read file');
      }
      receivePort.close();
    });

    return completer.future;
  }

  static void _readFile(List<dynamic> args) async {
    String filePath = args[0];
    SendPort sendPort = args[1];

    try {
      File file = File(filePath);
      Uint8List bytes = await file.readAsBytes();
      sendPort.send(bytes);
    } catch (e) {
      sendPort.send('error');
    }
  }

  Future<void> _pickImages() async {
    print('pickimage 1');
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(requestFullMetadata: false);
    print('pickimage 2');
    if (pickedFiles != null) {
      _imageFiles =
          pickedFiles.map((pickedFile) => File(pickedFile.path)).toList();
      print('pickimage 3');

      await _loadImages(_imageFiles);
      print('pickimage 4');
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
    print('load images 1');

    _originalImages = await Future.wait(imageFiles.map((file) async {
      print('load images 2.0');
      final imageBytes = await readFileAsync(file);
      print('load images 2.1');

      final croppedAndResizedImage = cropAndResize(
        img.decodeImage(imageBytes)!,
        maxSize: 1080,
        aspectRatio: 1.0,
      );

      print('load images 2.2');

      return croppedAndResizedImage;
    }).toList());

    print('load images 3');

    setState(() {
      _selectedFilter = NamedColorFilter(
          colorFilterMatrix: [], name: 'None'); // Reset the selected filter
    });
  }

  img.Image cropAndResize(img.Image image,
      {required int maxSize, required double aspectRatio}) {
    // Your crop and resize logic here
    // For example, this could resize the image to maxSize while maintaining the aspect ratio
    return img.copyResize(image,
        width: maxSize, height: (maxSize / aspectRatio).toInt());
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
