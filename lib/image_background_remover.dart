import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum BackgroundRemovalMode { auto, light, dark }

class BackgroundRemovalOptions {
  final BackgroundRemovalMode mode;
  final int tolerance;
  final int featherRadius;

  const BackgroundRemovalOptions({
    this.mode = BackgroundRemovalMode.auto,
    this.tolerance = 24,
    this.featherRadius = 1,
  }) : assert(tolerance >= 0 && tolerance <= 255),
       assert(featherRadius >= 0 && featherRadius <= 4);
}

class BackgroundRemovalResult {
  final img.Image image;
  final Uint8List pngBytes;
  final int removedPixelCount;
  final BackgroundRemovalMode resolvedMode;

  const BackgroundRemovalResult({
    required this.image,
    required this.pngBytes,
    required this.removedPixelCount,
    required this.resolvedMode,
  });
}

class ImageBackgroundRemover {
  static BackgroundRemovalResult removeBackgroundBytes(
    Uint8List bytes,
    BackgroundRemovalOptions options,
  ) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const FormatException('Could not decode image bytes');
    }

    if (decoded == null) {
      throw const FormatException('Could not decode image bytes');
    }

    return removeBackgroundImage(decoded, options);
  }

  static BackgroundRemovalResult removeBackgroundImage(
    img.Image input,
    BackgroundRemovalOptions options,
  ) {
    final image = input.convert(numChannels: 4);
    final resolvedMode = _resolveMode(image, options.mode);
    final removed = _removeConnectedBackground(
      image,
      resolvedMode,
      options.tolerance,
    );

    if (options.featherRadius > 0 && removed.isNotEmpty) {
      _featherEdges(image, removed, options.featherRadius);
    }

    return BackgroundRemovalResult(
      image: image,
      pngBytes: Uint8List.fromList(img.encodePng(image)),
      removedPixelCount: removed.length,
      resolvedMode: resolvedMode,
    );
  }

  static BackgroundRemovalMode _resolveMode(
    img.Image image,
    BackgroundRemovalMode requestedMode,
  ) {
    if (requestedMode != BackgroundRemovalMode.auto) {
      return requestedMode;
    }

    final samples = <img.Pixel>[
      image.getPixel(0, 0),
      image.getPixel(image.width - 1, 0),
      image.getPixel(0, image.height - 1),
      image.getPixel(image.width - 1, image.height - 1),
      image.getPixel(image.width ~/ 2, 0),
      image.getPixel(image.width ~/ 2, image.height - 1),
      image.getPixel(0, image.height ~/ 2),
      image.getPixel(image.width - 1, image.height ~/ 2),
    ];

    final averageLuminance =
        samples.map(_luminance).reduce((sum, value) => sum + value) /
        samples.length;

    return averageLuminance >= 128
        ? BackgroundRemovalMode.light
        : BackgroundRemovalMode.dark;
  }

  static Set<int> _removeConnectedBackground(
    img.Image image,
    BackgroundRemovalMode mode,
    int tolerance,
  ) {
    final visited = List<bool>.filled(image.width * image.height, false);
    final removed = <int>{};
    final queue = Queue<int>();

    void enqueueIfBackground(int x, int y) {
      final index = _indexOf(image, x, y);
      if (visited[index]) return;
      visited[index] = true;

      if (_matchesBackground(image.getPixel(x, y), mode, tolerance)) {
        queue.add(index);
      }
    }

    for (var x = 0; x < image.width; x++) {
      enqueueIfBackground(x, 0);
      enqueueIfBackground(x, image.height - 1);
    }
    for (var y = 1; y < image.height - 1; y++) {
      enqueueIfBackground(0, y);
      enqueueIfBackground(image.width - 1, y);
    }

    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      removed.add(index);

      final x = index % image.width;
      final y = index ~/ image.width;
      final pixel = image.getPixel(x, y);
      image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);

      void visitNeighbor(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
          return;
        }

        final neighborIndex = _indexOf(image, nx, ny);
        if (visited[neighborIndex]) return;
        visited[neighborIndex] = true;

        if (_matchesBackground(image.getPixel(nx, ny), mode, tolerance)) {
          queue.add(neighborIndex);
        }
      }

      visitNeighbor(x + 1, y);
      visitNeighbor(x - 1, y);
      visitNeighbor(x, y + 1);
      visitNeighbor(x, y - 1);
    }

    return removed;
  }

  static bool _matchesBackground(
    img.Pixel pixel,
    BackgroundRemovalMode mode,
    int tolerance,
  ) {
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    return switch (mode) {
      BackgroundRemovalMode.light =>
        (255 - r) <= tolerance &&
            (255 - g) <= tolerance &&
            (255 - b) <= tolerance,
      BackgroundRemovalMode.dark =>
        r <= tolerance && g <= tolerance && b <= tolerance,
      BackgroundRemovalMode.auto => false,
    };
  }

  static void _featherEdges(img.Image image, Set<int> removed, int radius) {
    final alphaUpdates = <int, int>{};

    for (final index in removed) {
      final x = index % image.width;
      final y = index ~/ image.width;

      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= image.width || ny >= image.height) {
            continue;
          }

          final neighborIndex = _indexOf(image, nx, ny);
          if (removed.contains(neighborIndex)) continue;

          final distance = math.sqrt((dx * dx) + (dy * dy));
          if (distance == 0 || distance > radius) continue;

          final alpha = (255 * (distance / (radius + 1))).round();
          alphaUpdates[neighborIndex] = math.min(
            alphaUpdates[neighborIndex] ?? 255,
            alpha.clamp(64, 220),
          );
        }
      }
    }

    for (final entry in alphaUpdates.entries) {
      final x = entry.key % image.width;
      final y = entry.key ~/ image.width;
      final pixel = image.getPixel(x, y);
      image.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, entry.value);
    }
  }

  static int _indexOf(img.Image image, int x, int y) {
    return y * image.width + x;
  }

  static num _luminance(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }
}
