import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_photo_filters/models/named_color_filter.dart';

class ImageList extends StatelessWidget {
  final List<File> imageFiles;
  final NamedColorFilter selectedFilter;

  ImageList({required this.imageFiles, required this.selectedFilter});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: imageFiles.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ColorFiltered(
            colorFilter: selectedFilter.colorFilterMatrix.isEmpty
                ? ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : ColorFilter.matrix(selectedFilter.colorFilterMatrix),
            child: Image.file(imageFiles[index]),
          ),
        );
      },
    );
  }
}
