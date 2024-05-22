import 'dart:io';
import 'package:flutter/material.dart';
import 'widgets/ahrar_camera/ahrar_camera.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> photos = [];

  void openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AhrarCamera(
          saveToGallery: true,
          onComplete: (files) {
            setState(() {
              photos.addAll(files);
            });
          },
          maxPhotos: 4, // Set the maximum number of photos to select
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Custom Camera Widget'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: openCamera,
            child: Text('Open Camera'),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Image.file(
                  photos[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
