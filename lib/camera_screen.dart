import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'display_picture_screen.dart';
import 'photo_display_screen.dart';

class CameraScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  CameraScreen({required this.setLocale});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  CameraController? frontCameraController;
  CameraController? backCameraController;
  List<CameraDescription>? cameras;
  bool isInitialized = false;
  File? imageFile;
  File? lastGalleryImage;
  bool isFlashOn = false;
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  CameraDescription? frontCamera;
  CameraDescription? backCamera;
  bool isUsingFrontCamera = false;
  Offset? _tapPosition;
  Timer? _tapEffectTimer;
  bool _showZoomOverlay = false;
  Timer? _zoomOverlayTimer;
  FlashMode _flashMode = FlashMode.off;
  bool isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    initCamera();
    requestPermission();
  }

  Future<void> initCamera() async {
    cameras = await availableCameras();
    frontCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    backCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back);

    frontCameraController = CameraController(
      frontCamera!,
      ResolutionPreset.high,
    );
    backCameraController = CameraController(
      backCamera!,
      ResolutionPreset.high,
    );

    await frontCameraController!.initialize();
    await backCameraController!.initialize();

    frontCameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
    backCameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    double maxZoomLevel = await backCameraController!.getMaxZoomLevel();
    double minZoomLevel = await backCameraController!.getMinZoomLevel();

    setState(() {
      controller = backCameraController;
      _currentZoomLevel = 1.0;
      _maxZoomLevel = maxZoomLevel;
      _minZoomLevel = minZoomLevel;
      isInitialized = true;
    });
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.isEmpty) return;

    setState(() {
      isInitialized = false; // Hide the camera preview immediately
      isSwitchingCamera = true;
      isUsingFrontCamera = !isUsingFrontCamera;
    });

    CameraController selectedController =
        isUsingFrontCamera ? frontCameraController! : backCameraController!;

    // Dispose of the current controller
    await controller?.dispose();

    // Initialize the selected controller
    selectedController = CameraController(
      isUsingFrontCamera ? frontCamera! : backCamera!,
      ResolutionPreset.high,
    );

    await selectedController.initialize();
    selectedController.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // Retrieve zoom levels for the selected camera
    double maxZoomLevel = await selectedController.getMaxZoomLevel();
    double minZoomLevel = await selectedController.getMinZoomLevel();

    if (!mounted) return;

    setState(() {
      controller = selectedController;
      _currentZoomLevel = 1.0;
      _maxZoomLevel = maxZoomLevel;
      _minZoomLevel = minZoomLevel;
      isInitialized = true; // Show the camera preview again
      isSwitchingCamera = false;
    });
  }

  Future<void> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      loadLastGalleryImage();
    } else {
      // handle permission denial
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
        setState(() {
          lastGalleryImage = file;
        });
      }
    }
  }

  @override
  void dispose() {
    frontCameraController?.dispose();
    backCameraController?.dispose();
    _tapEffectTimer?.cancel();
    _zoomOverlayTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]); // Reset to default
    super.dispose();
  }

  Future<void> takePicture() async {
    try {
      await controller!.setFlashMode(_flashMode); // Ensure flash mode is set

      final image = await controller!.takePicture();
      final directory = await getTemporaryDirectory();
      final imagePath = path.join(directory.path, '${DateTime.now()}.png');
      final imageFile = File(imagePath);
      imageFile.writeAsBytesSync(await image.readAsBytes());

      setState(() {
        this.imageFile = imageFile;
      });

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DisplayPictureScreen(
            imagePath: imagePath,
            onNext: () async {
              // Save the photo to the gallery
              final directory = await getApplicationDocumentsDirectory();
              final newImagePath =
                  path.join(directory.path, '${DateTime.now()}.png');
              final newImageFile = File(newImagePath);
              newImageFile.writeAsBytesSync(await imageFile.readAsBytes());

              setState(() {
                lastGalleryImage = newImageFile;
              });

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PhotoDisplayScreen(
                    imagePaths: [
                      newImagePath
                    ], // Pass the correct image path to the new screen
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;

    try {
      FlashMode newFlashMode;

      // Only allow "off" or "auto" for front camera
      if (isUsingFrontCamera) {
        if (_flashMode == FlashMode.off) {
          newFlashMode = FlashMode.auto;
        } else {
          newFlashMode = FlashMode.off;
        }
      } else {
        // Allow "off", "auto", and "torch" for back camera
        if (_flashMode == FlashMode.off) {
          newFlashMode = FlashMode.auto;
        } else if (_flashMode == FlashMode.auto) {
          newFlashMode = FlashMode.torch;
        } else {
          newFlashMode = FlashMode.off;
        }
      }

      await controller!.setFlashMode(newFlashMode);
      setState(() {
        _flashMode = newFlashMode;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _setFocusAndExposure(Offset position) async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    try {
      await controller!.setFocusPoint(position);
      await controller!.setExposurePoint(position);

      setState(() {
        _tapPosition = position;
      });

      _tapEffectTimer?.cancel();
      _tapEffectTimer = Timer(Duration(seconds: 1), () {
        setState(() {
          _tapPosition = null;
        });
      });
    } catch (e) {
      print(e);
    }
  }

  void _showZoomOverlayFunction() {
    setState(() {
      _showZoomOverlay = true;
    });

    _zoomOverlayTimer?.cancel();
    _zoomOverlayTimer = Timer(Duration(milliseconds: 1500), () {
      setState(() {
        _showZoomOverlay = false;
      });
    });
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

                    double zoomInSpeedFactor = 0.1; // Speed for zooming in
                    double zoomOutSpeedFactor = 0.7; // Speed for zooming out
                    double newZoomLevel;

                    if (details.scale > 1.0) {
                      // Zooming in
                      newZoomLevel = _currentZoomLevel +
                          zoomInSpeedFactor * (details.scale - 1.0);
                      _showZoomOverlayFunction();
                    } else if (details.scale < 1.0) {
                      // Zooming out
                      newZoomLevel = _currentZoomLevel -
                          zoomOutSpeedFactor * (1.0 - details.scale);
                      _showZoomOverlayFunction();
                    } else {
                      return; // If scale is 1, do nothing
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
                  onTapDown: (TapDownDetails details) {
                    final RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    final tapPosition =
                        renderBox.globalToLocal(details.globalPosition);
                    _setFocusAndExposure(
                      Offset(tapPosition.dx / renderBox.size.width,
                          tapPosition.dy / renderBox.size.height),
                    );
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
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_tapPosition != null)
            Positioned(
              left: _tapPosition!.dx * MediaQuery.of(context).size.width - 20,
              top: _tapPosition!.dy * MediaQuery.of(context).size.height - 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),
          if (_showZoomOverlay)
            Center(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!
                      .camera_zoomLabel(_currentZoomLevel.toStringAsFixed(1)),
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          Positioned(
            bottom: 70,
            left: 30,
            child: GestureDetector(
              onTap: loadLastGalleryImage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  image: lastGalleryImage != null
                      ? DecorationImage(
                          image: FileImage(lastGalleryImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey[300],
                ),
                child: lastGalleryImage == null
                    ? Icon(Icons.photo, size: 30, color: Colors.grey[800])
                    : null,
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
            // Centering the button
            child: IconButton(
              icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off
                      : _flashMode == FlashMode.auto
                          ? Icons.flash_auto
                          : Icons.flash_on,
                  color: Colors.white,
                  size: 30),
              onPressed: toggleFlash,
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
          if (isSwitchingCamera)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    color:
                        Colors.white, // Change progress circle color to white
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
