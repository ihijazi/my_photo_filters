import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_photo_filters/models/named_color_filter.dart';

class PresetsWidget extends StatelessWidget {
  final List<File> imageFiles;
  final Function(NamedColorFilter) onApplyFilter;

  PresetsWidget({required this.imageFiles, required this.onApplyFilter});

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => onApplyFilter(defaultColorFilters[index]),
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
                        child: imageFiles.isNotEmpty
                            ? Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: FileImage(imageFiles.first),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: imageFiles.length > 1
                                    ? BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 5.0, sigmaY: 5.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.0),
                                          ),
                                        ),
                                      )
                                    : Container(),
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey,
                              ),
                      ),
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
