import 'dart:io';
import 'package:flutter/material.dart';
import 'photo_display_screen.dart';

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final VoidCallback onNext;

  DisplayPictureScreen({required this.imagePath, required this.onNext});

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
              onPressed: () {
                onNext();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PhotoDisplayScreen(
                      imagePaths: [
                        imagePath
                      ], // Pass the image path to the new screen
                    ),
                  ),
                );
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
}
