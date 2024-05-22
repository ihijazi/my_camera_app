import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'dart:async';

Future<ui.Image> blurImage(img.Image image, {int radius = 10}) async {
  // Apply Gaussian blur with the provided radius
  final blurredImage = img.gaussianBlur(image, radius: radius);

  // Convert to ui.Image
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    blurredImage.getBytes(),
    blurredImage.width,
    blurredImage.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
