import 'dart:io';
import 'package:flutter/material.dart';

class PhotoDisplayScreen extends StatelessWidget {
  final List<String> imagePaths;

  PhotoDisplayScreen({required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photos'),
        backgroundColor: Colors.white, // Set the app bar background to white
        foregroundColor: Colors.black, // Set the app bar text color to black
        iconTheme: IconThemeData(
            color: Colors.black), // Set the back button color to black
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).popUntil(
                (route) => route.isFirst); // Navigate back to the camera screen
          },
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: imagePaths.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemBuilder: (context, index) {
          return Image.file(
            File(imagePaths[index]),
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}
