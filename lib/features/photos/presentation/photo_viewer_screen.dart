/// One photograph, as large as the screen allows.
///
/// The grid shows thumbnails and the sheet shows a readable size; this is for
/// the moment you want to look properly. Black behind it on purpose: a progress
/// photo is mostly skin against a wall, and the app's own surface colour sits
/// somewhere in between and makes both look wrong.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/widgets/common.dart';

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.file, required this.title});

  static Future<void> open(
    BuildContext context, {
    required File file,
    required String title,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PhotoViewerScreen(file: file, title: title),
      ),
    );
  }

  final File file;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        // Pinch to look closer, and a double tap is not bound to anything:
        // there is nothing here to open by accident.
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) =>
                const MissingPhotoPlaceholder(),
          ),
        ),
      ),
    );
  }
}
