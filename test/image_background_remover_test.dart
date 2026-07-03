import 'dart:typed_data';

import 'package:dev_tools_pro_max/image_background_remover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

img.Image _solidImage(int width, int height, int r, int g, int b) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  return image;
}

int _alphaAt(img.Image image, int x, int y) {
  return image.getPixel(x, y).a.toInt();
}

int _redAt(img.Image image, int x, int y) {
  return image.getPixel(x, y).r.toInt();
}

void main() {
  group('ImageBackgroundRemover', () {
    test('removes white background connected to image edges', () {
      final input = _solidImage(5, 5, 255, 255, 255);
      for (var y = 1; y < 4; y++) {
        for (var x = 1; x < 4; x++) {
          input.setPixelRgba(x, y, 20, 40, 80, 255);
        }
      }

      final result = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.light,
          tolerance: 20,
          featherRadius: 0,
        ),
      );

      expect(_alphaAt(result.image, 0, 0), 0);
      expect(_alphaAt(result.image, 4, 4), 0);
      expect(_alphaAt(result.image, 2, 2), 255);
      expect(result.removedPixelCount, 16);
    });

    test('removes black background connected to image edges', () {
      final input = _solidImage(5, 5, 0, 0, 0);
      for (var y = 1; y < 4; y++) {
        for (var x = 1; x < 4; x++) {
          input.setPixelRgba(x, y, 230, 230, 230, 255);
        }
      }

      final result = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.dark,
          tolerance: 20,
          featherRadius: 0,
        ),
      );

      expect(_alphaAt(result.image, 0, 0), 0);
      expect(_alphaAt(result.image, 4, 4), 0);
      expect(_alphaAt(result.image, 2, 2), 255);
      expect(result.removedPixelCount, 16);
    });

    test('keeps interior white detail that is not connected to an edge', () {
      final input = _solidImage(7, 7, 255, 255, 255);
      for (var y = 1; y < 6; y++) {
        for (var x = 1; x < 6; x++) {
          input.setPixelRgba(x, y, 30, 60, 120, 255);
        }
      }
      input.setPixelRgba(3, 3, 255, 255, 255, 255);

      final result = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.light,
          tolerance: 20,
          featherRadius: 0,
        ),
      );

      expect(_alphaAt(result.image, 0, 0), 0);
      expect(_alphaAt(result.image, 3, 3), 255);
      expect(_redAt(result.image, 3, 3), 255);
      expect(result.removedPixelCount, 24);
    });

    test('uses tolerance for near-white edge pixels', () {
      final input = _solidImage(3, 3, 244, 246, 248);
      input.setPixelRgba(1, 1, 10, 40, 90, 255);

      final lowTolerance = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.light,
          tolerance: 4,
          featherRadius: 0,
        ),
      );
      final highTolerance = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.light,
          tolerance: 16,
          featherRadius: 0,
        ),
      );

      expect(_alphaAt(lowTolerance.image, 0, 0), 255);
      expect(_alphaAt(highTolerance.image, 0, 0), 0);
      expect(_alphaAt(highTolerance.image, 1, 1), 255);
    });

    test('auto mode classifies a dark edge as dark background', () {
      final input = _solidImage(5, 5, 8, 8, 8);
      for (var y = 1; y < 4; y++) {
        for (var x = 1; x < 4; x++) {
          input.setPixelRgba(x, y, 230, 230, 230, 255);
        }
      }

      final result = ImageBackgroundRemover.removeBackgroundImage(
        input,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.auto,
          tolerance: 20,
          featherRadius: 0,
        ),
      );

      expect(result.resolvedMode, BackgroundRemovalMode.dark);
      expect(_alphaAt(result.image, 0, 0), 0);
      expect(_alphaAt(result.image, 2, 2), 255);
    });

    test('decodes bytes and returns PNG bytes', () {
      final input = _solidImage(3, 3, 255, 255, 255);
      input.setPixelRgba(1, 1, 0, 0, 0, 255);
      final bytes = Uint8List.fromList(img.encodePng(input));

      final result = ImageBackgroundRemover.removeBackgroundBytes(
        bytes,
        const BackgroundRemovalOptions(
          mode: BackgroundRemovalMode.light,
          tolerance: 20,
          featherRadius: 0,
        ),
      );
      final decoded = img.decodeImage(result.pngBytes);

      expect(decoded, isNotNull);
      expect(_alphaAt(decoded!, 0, 0), 0);
      expect(_alphaAt(decoded, 1, 1), 255);
    });
  });
}
