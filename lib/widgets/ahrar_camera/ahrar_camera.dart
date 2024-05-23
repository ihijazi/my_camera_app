import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'display_picture_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class AhrarCamera extends StatefulWidget {
  final bool saveToGallery;
  final int maxPhotos;

  final Function(List<File>) onComplete;

  AhrarCamera(
      {required this.saveToGallery,
      required this.onComplete,
      this.maxPhotos = 5});

  @override
  _AhrarCameraState createState() => _AhrarCameraState();
}

class _AhrarCameraState extends State<AhrarCamera> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isInitialized = false;
  File? imageFile;
  File? lastGalleryImage;
  bool lastGalleryImageLoading = true;
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;
  bool isSwitchingCamera = false;
  bool isUsingFrontCamera = false;
  CameraController? frontCameraController;
  CameraController? backCameraController;
  CameraDescription? frontCamera;
  CameraDescription? backCamera;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeWidget();
  }

  Future<void> _initializeWidget() async {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    bool permissionsGranted = await requestPermissions(context);
    if (permissionsGranted) {
      initCamera();
      loadLastGalleryImage();
    }
  }

  Future<bool> requestPermissions(BuildContext context) async {
    PermissionStatus cameraStatus = await Permission.camera.request();
    PermissionStatus photosStatus = await Permission.photos.request();

    if (cameraStatus.isGranted && photosStatus.isGranted) {
      return true;
    } else {
      showPermissionDialog();
      return false;
    }
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
            'This app needs camera and photo library access to function properly. Please grant the necessary permissions in your settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    frontCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    backCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);

    frontCameraController = CameraController(
        frontCamera!, ResolutionPreset.high,
        enableAudio: false);
    backCameraController = CameraController(backCamera!, ResolutionPreset.high,
        enableAudio: false);

    try {
      await frontCameraController!.initialize();
      await backCameraController!.initialize();

      frontCameraController!
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
      backCameraController!
          .lockCaptureOrientation(DeviceOrientation.portraitUp);

      double maxZoomLevel = await backCameraController!.getMaxZoomLevel();
      double minZoomLevel = await backCameraController!.getMinZoomLevel();

      if (maxZoomLevel > 10.0) {
        maxZoomLevel = 10.0;
      }

      setState(() {
        controller = backCameraController;
        _currentZoomLevel = 1.0;
        _maxZoomLevel = maxZoomLevel;
        _minZoomLevel = minZoomLevel;
        isInitialized = true;
      });
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Future<void> loadLastGalleryImage() async {
    setState(() {
      lastGalleryImageLoading = true;
    });

    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );

    if (albums.isNotEmpty) {
      List<AssetEntity> photos =
          await albums[0].getAssetListPaged(page: 0, size: 1);
      if (photos.isNotEmpty) {
        File? file = await photos[0].file;
        if (file != null) {
          setState(() {
            lastGalleryImage = file;
            lastGalleryImageLoading = false;
          });
          return;
        }
      }
    }

    setState(() {
      lastGalleryImageLoading = false;
    });
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    setState(() {
      isInitialized = false;
      isSwitchingCamera = true;
      isUsingFrontCamera = !isUsingFrontCamera;
    });

    CameraController selectedController =
        isUsingFrontCamera ? frontCameraController! : backCameraController!;

    await controller?.dispose();

    selectedController = CameraController(
        isUsingFrontCamera ? frontCamera! : backCamera!, ResolutionPreset.high,
        enableAudio: false);

    await selectedController.initialize();
    selectedController.lockCaptureOrientation(DeviceOrientation.portraitUp);

    double maxZoomLevel = await selectedController.getMaxZoomLevel();
    double minZoomLevel = await selectedController.getMinZoomLevel();

    if (maxZoomLevel > 10.0) {
      maxZoomLevel = 10.0;
    }

    if (!mounted) return;

    setState(() {
      controller = selectedController;
      _currentZoomLevel = 1.0;
      _maxZoomLevel = maxZoomLevel;
      _minZoomLevel = minZoomLevel;
      isInitialized = true;
      isSwitchingCamera = false;
    });
  }

  Future<void> takePicture() async {
    if (!isInitialized ||
        controller == null ||
        !controller!.value.isInitialized) {
      print("Camera is not initialized or controller is not set.");
      return;
    }

    try {
      await controller!.setFlashMode(_flashMode);

      final image = await controller!.takePicture();
      final directory = await getTemporaryDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(await image.readAsBytes());

      await controller!.setFlashMode(FlashMode.off);
      setState(() {
        _flashMode = FlashMode.off;
        this.imageFile = imageFile;
      });

      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => DisplayPictureScreen(
                imagePath: imagePath,
                saveToGallery: widget.saveToGallery,
                onComplete: (File file) {
                  widget.onComplete([file]);
                  // Navigator.of(context).pop(); // Pop the DisplayPictureScreen
                  // Navigator.of(context).pop(); // Pop the AhrarCamera widget
                },
                onSaveComplete: (File savedFile) {
                  setState(() {
                    lastGalleryImage = savedFile;
                  });
                },
              ),
            ),
          )
          .then((_) => Navigator.of(context)
              .pop()); // Ensure AhrarCamera is popped when DisplayPictureScreen is closed
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  Future<void> pickImages() async {
    final ImagePicker picker = ImagePicker();
    final ImagePickerPlatform imagePickerImplementation =
        ImagePickerPlatform.instance;
    if (imagePickerImplementation is ImagePickerAndroid) {
      imagePickerImplementation.useAndroidPhotoPicker = true;
    }

    try {
      final List<XFile>? pickedFiles =
          await picker.pickMultiImage(limit: widget.maxPhotos);
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        final List<File> imageFiles =
            pickedFiles.map((file) => File(file.path)).toList();
        widget.onComplete(imageFiles);
        Navigator.of(context).pop(); // Pop the AhrarCamera widget
      }
    } catch (e) {
      print(e);
    }
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

  @override
  void dispose() {
    frontCameraController?.dispose();
    backCameraController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (controller != null && isInitialized)
            LayoutBuilder(
              builder: (context, constraints) {
                final mediaSize = MediaQuery.of(context).size;
                final scale =
                    1 / (controller!.value.aspectRatio * mediaSize.aspectRatio);

                return GestureDetector(
                  onScaleUpdate: (ScaleUpdateDetails details) async {
                    if (controller == null ||
                        !controller!.value.isInitialized) {
                      return;
                    }

                    double zoomInSpeedFactor = 0.1;
                    double zoomOutSpeedFactor = 0.7;
                    double newZoomLevel;

                    if (details.scale > 1.0) {
                      newZoomLevel = _currentZoomLevel +
                          zoomInSpeedFactor * (details.scale - 1.0);
                    } else if (details.scale < 1.0) {
                      newZoomLevel = _currentZoomLevel -
                          zoomOutSpeedFactor * (1.0 - details.scale);
                    } else {
                      return;
                    }

                    if (newZoomLevel < _minZoomLevel) {
                      newZoomLevel = _minZoomLevel;
                    } else if (newZoomLevel > _maxZoomLevel) {
                      newZoomLevel = _maxZoomLevel;
                    }

                    await controller!.setZoomLevel(newZoomLevel);

                    setState(() {
                      _currentZoomLevel = newZoomLevel;
                    });
                  },
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: CameraPreview(controller!),
                    ),
                  ),
                );
              },
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          if (lastGalleryImage != null)
            Positioned(
              bottom: 70,
              left: 30,
              child: GestureDetector(
                onTap: pickImages,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(lastGalleryImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: takePicture,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 70,
            right: 30,
            child: IconButton(
              icon: Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
              onPressed: switchCamera,
            ),
          ),
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 15,
            child: IconButton(
              icon: Icon(
                _flashMode == FlashMode.off
                    ? Icons.flash_off
                    : _flashMode == FlashMode.auto
                        ? Icons.flash_auto
                        : _flashMode == FlashMode.always
                            ? Icons.flash_on
                            : Icons.flash_off,
                color: Colors.white,
                size: 30,
              ),
              onPressed: toggleFlash,
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                widget.onComplete([]);
                Navigator.of(context).pop();
              },
            ),
          ),
          if (isSwitchingCamera)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;

    try {
      FlashMode newFlashMode;

      if (isUsingFrontCamera) {
        if (_flashMode == FlashMode.off) {
          newFlashMode = FlashMode.auto;
        } else {
          newFlashMode = FlashMode.off;
        }
      } else {
        if (_flashMode == FlashMode.off) {
          newFlashMode = FlashMode.auto;
        } else if (_flashMode == FlashMode.auto) {
          newFlashMode = FlashMode.always;
        } else {
          newFlashMode = FlashMode.off;
        }
      }

      setState(() {
        _flashMode = newFlashMode;
      });
    } catch (e) {
      print("Error toggling flash: $e");
    }
  }
}
