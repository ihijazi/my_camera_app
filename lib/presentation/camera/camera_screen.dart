import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:my_camera_app/domain/usecases/camera_usecase.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:my_camera_app/presentation/widgets/loading_indicator.dart';

class CameraScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  CameraScreen({required this.setLocale});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraUseCase _cameraUseCase;
  double _currentZoomLevel = 1.0;
  bool _showZoomOverlay = false;
  Offset? _tapPosition;
  Timer? _tapEffectTimer;
  Timer? _zoomOverlayTimer;

  @override
  void initState() {
    super.initState();
    _cameraUseCase = CameraUseCase();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Ensure setState is called after initialization
    _cameraUseCase.initializeControllerFuture.then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cameraUseCase.dispose();
    _tapEffectTimer?.cancel();
    _zoomOverlayTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
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

  Future<void> _switchCamera() async {
    setState(() {
      _cameraUseCase.isSwitchingCamera = true;
    });

    await _cameraUseCase.switchCamera();
    setState(() {
      _cameraUseCase.isSwitchingCamera = false;
    });
  }

  Future<void> _toggleFlash() async {
    await _cameraUseCase.toggleFlash();
    setState(() {});
  }

  void _onPictureTaken() {
    setState(() {
      // Update the state to reflect the new picture
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_cameraUseCase.isSwitchingCamera &&
              _cameraUseCase.blurredImage != null)
            Positioned.fill(
              child: RawImage(
                image: _cameraUseCase.blurredImage,
                fit: BoxFit.cover,
              ),
            ),
          FutureBuilder<void>(
            future: _cameraUseCase.initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  !_cameraUseCase.isSwitchingCamera) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final mediaSize = MediaQuery.of(context).size;
                    final scale = 1 /
                        (_cameraUseCase.controller!.value.aspectRatio *
                            mediaSize.aspectRatio);

                    return GestureDetector(
                      onScaleUpdate: (ScaleUpdateDetails details) async {
                        if (_cameraUseCase.controller == null ||
                            !_cameraUseCase.controller!.value.isInitialized) {
                          return;
                        }

                        double newZoomLevel;
                        if (details.scale > 1.0) {
                          newZoomLevel =
                              _currentZoomLevel + 0.1 * (details.scale - 1.0);
                          _showZoomOverlayFunction();
                        } else if (details.scale < 1.0) {
                          newZoomLevel =
                              _currentZoomLevel - 0.3 * (1.0 - details.scale);
                          _showZoomOverlayFunction();
                        } else {
                          return;
                        }

                        if (newZoomLevel < _cameraUseCase.minZoomLevel) {
                          newZoomLevel = _cameraUseCase.minZoomLevel;
                        } else if (newZoomLevel > _cameraUseCase.maxZoomLevel) {
                          newZoomLevel = _cameraUseCase.maxZoomLevel;
                        }

                        await _cameraUseCase.controller!
                            .setZoomLevel(newZoomLevel);
                        setState(() {
                          _currentZoomLevel = newZoomLevel;
                        });
                      },
                      onTapDown: (TapDownDetails details) {
                        final RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final tapPosition =
                            renderBox.globalToLocal(details.globalPosition);
                        _cameraUseCase.setFocusAndExposure(
                          Offset(tapPosition.dx / renderBox.size.width,
                              tapPosition.dy / renderBox.size.height),
                        );
                      },
                      child: Transform.scale(
                        scale: scale,
                        child: Center(
                          child: CameraPreview(_cameraUseCase.controller!),
                        ),
                      ),
                    );
                  },
                );
              } else {
                return LoadingIndicator();
              }
            },
          ),
          if (_cameraUseCase.controller == null ||
              !_cameraUseCase.controller!.value.isInitialized)
            LoadingIndicator(),
          if (_cameraUseCase.controller != null &&
              _cameraUseCase.controller!.value.isInitialized &&
              !_cameraUseCase.isSwitchingCamera) ...[
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
                onTap: () async {
                  await _cameraUseCase.loadLastGalleryImage();
                  setState(() {});
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: _cameraUseCase.lastGalleryImage != null
                        ? DecorationImage(
                            image: FileImage(_cameraUseCase.lastGalleryImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey[300],
                  ),
                  child: _cameraUseCase.lastGalleryImage == null
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
                  onTap: () =>
                      _cameraUseCase.takePicture(context, _onPictureTaken),
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
                              color: Colors.red,
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
                icon:
                    Icon(Icons.flip_camera_ios, color: Colors.white, size: 30),
                onPressed: _switchCamera,
              ),
            ),
            Positioned(
              top: 40,
              left: MediaQuery.of(context).size.width / 2 - 15,
              child: IconButton(
                icon: Icon(
                    _cameraUseCase.flashMode == FlashMode.off
                        ? Icons.flash_off
                        : _cameraUseCase.flashMode == FlashMode.auto
                            ? Icons.flash_auto
                            : Icons.flash_on,
                    color: Colors.white,
                    size: 30),
                onPressed: _toggleFlash,
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
          ],
        ],
      ),
    );
  }
}
