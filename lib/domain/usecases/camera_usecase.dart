import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_camera_app/presentation/camera/display_picture_screen.dart';
import 'package:image/image.dart' as img;
import 'package:my_camera_app/utils/image_utils.dart'; // Import the utility function
import 'dart:ui' as ui;

class CameraUseCase {
  CameraController? controller;
  List<CameraDescription>? cameras;
  late Future<void> initializeControllerFuture;
  File? lastGalleryImage;
  double maxZoomLevel = 1.0;
  double minZoomLevel = 1.0;
  FlashMode flashMode = FlashMode.off;
  bool isUsingFrontCamera = false;
  CameraDescription? frontCamera;
  CameraDescription? backCamera;
  img.Image? lastFrame;
  ui.Image? blurredImage;

  bool isSwitchingCamera = false;

  CameraUseCase() {
    initializeControllerFuture = initCamera();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    frontCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    backCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    controller = CameraController(
      backCamera!,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();
    controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    maxZoomLevel = await controller!.getMaxZoomLevel();
    if (maxZoomLevel > 10.0) maxZoomLevel = 10;
    minZoomLevel = await controller!.getMinZoomLevel();

    await loadLastGalleryImage();
  }

  Future<void> captureFrame() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    final image = await controller!.takePicture();
    final imageBytes = await image.readAsBytes();
    lastFrame = img.decodeImage(imageBytes);
    blurredImage =
        await blurImage(lastFrame!, radius: 10); // Ensure radius is provided
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    await captureFrame();
    isSwitchingCamera = true;
    isUsingFrontCamera = !isUsingFrontCamera;
    CameraDescription selectedCamera =
        isUsingFrontCamera ? frontCamera! : backCamera!;
    await controller?.dispose();
    controller = CameraController(selectedCamera, ResolutionPreset.high);

    initializeControllerFuture = controller!.initialize();
    await initializeControllerFuture;

    controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    isSwitchingCamera = false;
  }

  Future<void> takePicture(
      BuildContext context, Function onPictureTaken) async {
    try {
      await initializeControllerFuture;
      await controller!.setFlashMode(flashMode);

      final image = await controller!.takePicture();
      final directory = await getTemporaryDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      final imageFile = File(imagePath);
      imageFile.writeAsBytesSync(await image.readAsBytes());

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DisplayPictureScreen(
            imagePath: imagePath,
            onNext: () async {
              final directory = await getApplicationDocumentsDirectory();
              final newImagePath =
                  path.join(directory.path, '${DateTime.now()}.png');
              final newImageFile = File(newImagePath);
              newImageFile.writeAsBytesSync(await imageFile.readAsBytes());

              lastGalleryImage = newImageFile;
              onPictureTaken(); // Notify the CameraScreen of the new picture
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      // Update the last gallery image
      lastGalleryImage = imageFile;
    } catch (e) {
      print(e);
    }
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;

    try {
      FlashMode newFlashMode;
      if (flashMode == FlashMode.off) {
        newFlashMode = FlashMode.auto;
      } else if (flashMode == FlashMode.auto) {
        newFlashMode = FlashMode.torch;
      } else {
        newFlashMode = FlashMode.off;
      }

      await controller!.setFlashMode(newFlashMode);
      flashMode = newFlashMode;
    } catch (e) {
      print(e);
    }
  }

  Future<void> setFocusAndExposure(Offset position) async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    try {
      await controller!.setFocusPoint(position);
      await controller!.setExposurePoint(position);
    } catch (e) {
      print(e);
    }
  }

  Future<void> loadLastGalleryImage() async {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );

    List<AssetEntity> photos = await albums[0].getAssetListPaged(0, 1);
    if (photos.isNotEmpty) {
      File? file = await photos[0].file;
      if (file != null) {
        lastGalleryImage = file;
      }
    }
  }

  void dispose() {
    controller?.dispose();
  }
}
