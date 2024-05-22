import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final bool saveToGallery;
  final Function(File) onComplete;
  final Function(File) onSaveComplete;

  DisplayPictureScreen({
    required this.imagePath,
    required this.saveToGallery,
    required this.onComplete,
    required this.onSaveComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          Positioned(
            bottom: 70,
            right: 30,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black, // Button background color
              ),
              onPressed: () async {
                final imageFile = File(imagePath);
                if (saveToGallery) {
                  await savePhotoToGallery(imageFile);
                }
                onComplete(imageFile);
                onSaveComplete(imageFile);
                Navigator.of(context).pop();
              },
              child: Text(
                'Next',
                style: TextStyle(
                  color: Colors.white, // Text color
                  fontFamily: 'Roboto', // Font family
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> savePhotoToGallery(File imageFile) async {
    try {
      final AssetEntity? asset = await PhotoManager.editor
          .saveImageWithPath(title: 'Photo taken by Ahrar', imageFile.path);
      if (asset != null) {
        print("Photo saved to gallery: ${asset.id}");
      } else {
        print("Failed to save photo to gallery.");
      }
    } catch (e) {
      print("Error saving photo to gallery: $e");
    }
  }
}
