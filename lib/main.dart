import 'package:flutter/material.dart';
import 'package:my_photo_filters/screens/image_processor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
