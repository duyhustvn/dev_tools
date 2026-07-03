# Image Background Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `Image` tab that picks an image, removes connected white/black edge backgrounds with edge flood-fill, previews transparency, and exports PNG.

**Architecture:** Keep pixel processing in a pure Dart service (`lib/image_background_remover.dart`) so it can be tested without Flutter widgets. Put the image UI in `lib/image_tool.dart` and keep `lib/main.dart` limited to registering the new tool in the existing `NavigationRail`.

**Tech Stack:** Flutter, Dart, `file_picker` for pick/save, `image` for decode/pixel manipulation/PNG encode, `flutter_test` for widget and unit tests.

---

## File Structure

- Modify `pubspec.yaml`
  - Add `file_picker` and `image`.
- Create `lib/image_background_remover.dart`
  - Owns `BackgroundRemovalMode`, `BackgroundRemovalOptions`, `BackgroundRemovalResult`, `ImageBackgroundRemover`.
  - Exposes `removeBackgroundBytes(Uint8List bytes, BackgroundRemovalOptions options)` and `removeBackgroundImage(img.Image input, BackgroundRemovalOptions options)`.
- Create `lib/image_tool.dart`
  - Owns `ImageTool`, file picking, processing state, preview panes, controls, and export action.
- Modify `lib/main.dart`
  - Import `image_tool.dart`.
  - Register `ImageTool` and its `NavigationRailDestination`.
- Create `test/image_background_remover_test.dart`
  - Tests flood-fill behavior with tiny synthetic images.
- Modify `test/widget_test.dart`
  - Update navigation expectations.
  - Add an empty-state widget test for `ImageTool`.

---

### Task 1: Add Dependencies And Failing Algorithm Tests

**Files:**
- Modify: `pubspec.yaml`
- Create: `test/image_background_remover_test.dart`

- [ ] **Step 1: Add packages**

Run:

```bash
flutter pub add file_picker image
```

Expected:

```text
Changed 2 dependencies!
```

If the exact text differs because Flutter reports transitive dependency changes, continue as long as `pubspec.yaml` contains `file_picker:` and `image:` under `dependencies`.

- [ ] **Step 2: Write failing tests for the pure remover**

Create `test/image_background_remover_test.dart`:

```dart
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
```

- [ ] **Step 3: Run tests to verify they fail because the service does not exist**

Run:

```bash
flutter test test/image_background_remover_test.dart
```

Expected:

```text
Error: Error when reading 'lib/image_background_remover.dart': No such file or directory
```

- [ ] **Step 4: Commit dependency and failing test**

Run:

```bash
git add pubspec.yaml pubspec.lock test/image_background_remover_test.dart
git commit -m "test: cover image background remover"
```

---

### Task 2: Implement Edge Flood-Fill Background Removal

**Files:**
- Create: `lib/image_background_remover.dart`
- Test: `test/image_background_remover_test.dart`

- [ ] **Step 1: Create the remover implementation**

Create `lib/image_background_remover.dart`:

```dart
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum BackgroundRemovalMode {
  auto,
  light,
  dark,
}

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
    final decoded = img.decodeImage(bytes);
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

    final averageLuminance = samples
            .map(_luminance)
            .reduce((sum, value) => sum + value) /
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

  static void _featherEdges(
    img.Image image,
    Set<int> removed,
    int radius,
  ) {
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
```

- [ ] **Step 2: Run remover tests**

Run:

```bash
flutter test test/image_background_remover_test.dart
```

Expected:

```text
00:00 +6: All tests passed!
```

- [ ] **Step 3: Format the new service and tests**

Run:

```bash
dart format lib/image_background_remover.dart test/image_background_remover_test.dart
```

Expected:

```text
Formatted 2 files
```

If Dart says one or both files are unchanged, continue.

- [ ] **Step 4: Re-run remover tests after formatting**

Run:

```bash
flutter test test/image_background_remover_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: Commit the remover implementation**

Run:

```bash
git add lib/image_background_remover.dart test/image_background_remover_test.dart
git commit -m "feat: add edge flood-fill background remover"
```

---

### Task 3: Register The Image Tool Navigation

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/image_tool.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add a minimal placeholder `ImageTool`**

Create `lib/image_tool.dart`:

```dart
import 'package:flutter/material.dart';

class ImageTool extends StatelessWidget {
  const ImageTool({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Tools'), elevation: 1),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text(
              'No image selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick an image to remove a white or black background.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('image-pick-button'),
              onPressed: null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick Image'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const Key('image-remove-background-button'),
              onPressed: null,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Remove Background'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Register the placeholder in navigation**

Modify the import section at the top of `lib/main.dart`:

```dart
import 'dart:async'; // Required for Timer in TimestampTool
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dev_tools_pro_max/image_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
```

Modify `_tools` in `_MultiToolScreenState`:

```dart
  final List<Widget> _tools = [
    const JsonTool(),
    const Base64Tool(),
    const UrlTool(),
    const TimestampTool(),
    const JwtTool(),
    const Uint64CalcTool(),
    const ImageTool(),
  ];
```

Add the new destination after `Calculator`:

```dart
              NavigationRailDestination(
                icon: Icon(Icons.calculate),
                label: Text('Calculator'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.image),
                label: Text('Image'),
              ),
```

- [ ] **Step 3: Update widget tests for navigation and empty Image state**

Modify `test/widget_test.dart` imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dev_tools_pro_max/image_tool.dart';
import 'package:dev_tools_pro_max/main.dart';
```

In `renders the tool navigation`, add:

```dart
    expect(find.text('Image'), findsOneWidget);
```

Add this test near the navigation test:

```dart
  testWidgets('renders image tool empty state with disabled actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ImageTool()));

    expect(find.text('Image Tools'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);

    final pickButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('image-pick-button')),
    );
    final removeButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('image-remove-background-button')),
    );

    expect(pickButton.onPressed, isNull);
    expect(removeButton.onPressed, isNull);
  });
```

- [ ] **Step 4: Run widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: Format touched Dart files**

Run:

```bash
dart format lib/main.dart lib/image_tool.dart test/widget_test.dart
```

Expected:

```text
Formatted 3 files
```

If Dart says one or more files are unchanged, continue.

- [ ] **Step 6: Commit navigation and placeholder UI**

Run:

```bash
git add lib/main.dart lib/image_tool.dart test/widget_test.dart
git commit -m "feat: add image tool navigation"
```

---

### Task 4: Build Image Pick, Preview, Controls, Processing, And Export UI

**Files:**
- Modify: `lib/image_tool.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Replace the placeholder with the full ImageTool**

Replace all content in `lib/image_tool.dart`:

```dart
import 'dart:typed_data';

import 'package:dev_tools_pro_max/image_background_remover.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ImageTool extends StatefulWidget {
  const ImageTool({super.key});

  @override
  State<ImageTool> createState() => _ImageToolState();
}

class _ImageToolState extends State<ImageTool> {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  String? _fileName;
  String? _statusMessage;
  bool _isProcessing = false;
  BackgroundRemovalMode _mode = BackgroundRemovalMode.auto;
  double _tolerance = 24;
  bool _featherEdges = true;

  bool get _hasOriginal => _originalBytes != null;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showStatus('Could not read selected image bytes.');
      return;
    }

    setState(() {
      _originalBytes = bytes;
      _processedBytes = null;
      _fileName = result.files.single.name;
      _statusMessage = null;
    });
  }

  Future<void> _removeBackground() async {
    final bytes = _originalBytes;
    if (bytes == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final result = ImageBackgroundRemover.removeBackgroundBytes(
        bytes,
        BackgroundRemovalOptions(
          mode: _mode,
          tolerance: _tolerance.round(),
          featherRadius: _featherEdges ? 1 : 0,
        ),
      );

      setState(() {
        _processedBytes = result.pngBytes;
        _statusMessage =
            'Removed ${result.removedPixelCount} background pixels '
            '(${_labelForMode(result.resolvedMode)}).';
      });
    } catch (error) {
      _showStatus('Could not process image: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportPng() async {
    final bytes = _processedBytes;
    if (bytes == null) return;

    final baseName = (_fileName ?? 'image')
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^\w\-.]+'), '_');

    try {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save transparent PNG',
        fileName: '${baseName}_transparent.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: bytes,
      );
      _showStatus('PNG export ready.');
    } catch (error) {
      _showStatus('Could not export PNG: $error');
    }
  }

  void _showStatus(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  String _labelForMode(BackgroundRemovalMode mode) {
    return switch (mode) {
      BackgroundRemovalMode.auto => 'auto',
      BackgroundRemovalMode.light => 'light background',
      BackgroundRemovalMode.dark => 'dark background',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Tools'), elevation: 1),
      body: Column(
        children: [
          _ImageToolbar(
            mode: _mode,
            tolerance: _tolerance,
            featherEdges: _featherEdges,
            hasOriginal: _hasOriginal,
            hasProcessed: _processedBytes != null,
            isProcessing: _isProcessing,
            onPickImage: _pickImage,
            onRemoveBackground: _removeBackground,
            onExportPng: _exportPng,
            onModeChanged: (mode) {
              setState(() => _mode = mode);
              if (_processedBytes != null) {
                _removeBackground();
              }
            },
            onToleranceChanged: (value) {
              setState(() => _tolerance = value);
            },
            onToleranceChangeEnd: (_) {
              if (_processedBytes != null) {
                _removeBackground();
              }
            },
            onFeatherChanged: (value) {
              setState(() => _featherEdges = value);
              if (_processedBytes != null) {
                _removeBackground();
              }
            },
          ),
          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blueGrey.shade50,
              child: Text(
                _statusMessage!,
                style: TextStyle(color: Colors.blueGrey.shade700),
              ),
            ),
          Expanded(
            child: _hasOriginal
                ? _ImagePreviewGrid(
                    originalBytes: _originalBytes!,
                    processedBytes: _processedBytes,
                    fileName: _fileName,
                  )
                : const _ImageEmptyState(),
          ),
        ],
      ),
    );
  }
}

class _ImageToolbar extends StatelessWidget {
  final BackgroundRemovalMode mode;
  final double tolerance;
  final bool featherEdges;
  final bool hasOriginal;
  final bool hasProcessed;
  final bool isProcessing;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveBackground;
  final VoidCallback onExportPng;
  final ValueChanged<BackgroundRemovalMode> onModeChanged;
  final ValueChanged<double> onToleranceChanged;
  final ValueChanged<double> onToleranceChangeEnd;
  final ValueChanged<bool> onFeatherChanged;

  const _ImageToolbar({
    required this.mode,
    required this.tolerance,
    required this.featherEdges,
    required this.hasOriginal,
    required this.hasProcessed,
    required this.isProcessing,
    required this.onPickImage,
    required this.onRemoveBackground,
    required this.onExportPng,
    required this.onModeChanged,
    required this.onToleranceChanged,
    required this.onToleranceChangeEnd,
    required this.onFeatherChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            key: const Key('image-pick-button'),
            onPressed: isProcessing ? null : onPickImage,
            icon: const Icon(Icons.upload_file),
            label: const Text('Pick Image'),
          ),
          ElevatedButton.icon(
            key: const Key('image-remove-background-button'),
            onPressed: hasOriginal && !isProcessing ? onRemoveBackground : null,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(isProcessing ? 'Processing' : 'Remove Background'),
          ),
          OutlinedButton.icon(
            key: const Key('image-export-button'),
            onPressed: hasProcessed && !isProcessing ? onExportPng : null,
            icon: const Icon(Icons.download),
            label: const Text('Export PNG'),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<BackgroundRemovalMode>(
              key: const Key('image-background-mode-dropdown'),
              initialValue: mode,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Background',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: BackgroundRemovalMode.auto,
                  child: Text('Auto'),
                ),
                DropdownMenuItem(
                  value: BackgroundRemovalMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: BackgroundRemovalMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: isProcessing
                  ? null
                  : (value) {
                      if (value != null) {
                        onModeChanged(value);
                      }
                    },
            ),
          ),
          SizedBox(
            width: 240,
            child: Row(
              children: [
                const Text('Tolerance'),
                Expanded(
                  child: Slider(
                    key: const Key('image-tolerance-slider'),
                    min: 0,
                    max: 80,
                    divisions: 80,
                    label: tolerance.round().toString(),
                    value: tolerance,
                    onChanged: isProcessing ? null : onToleranceChanged,
                    onChangeEnd:
                        isProcessing ? null : onToleranceChangeEnd,
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    tolerance.round().toString(),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Feather'),
              Switch(
                key: const Key('image-feather-switch'),
                value: featherEdges,
                onChanged: isProcessing ? null : onFeatherChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewGrid extends StatelessWidget {
  final Uint8List originalBytes;
  final Uint8List? processedBytes;
  final String? fileName;

  const _ImagePreviewGrid({
    required this.originalBytes,
    required this.processedBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final panes = [
          _ImagePreviewPane(
            title: 'ORIGINAL',
            subtitle: fileName,
            bytes: originalBytes,
            checkerboard: false,
          ),
          _ImagePreviewPane(
            title: 'TRANSPARENT PNG',
            subtitle: processedBytes == null
                ? 'Run remove background to generate preview'
                : 'Checkerboard shows transparent pixels',
            bytes: processedBytes,
            checkerboard: true,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: panes
                .map((pane) => Expanded(child: pane))
                .toList(growable: false),
          );
        }

        return Row(
          children: panes
              .map((pane) => Expanded(child: pane))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ImagePreviewPane extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Uint8List? bytes;
  final bool checkerboard;

  const _ImagePreviewPane({
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.checkerboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey.shade200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: checkerboard ? null : Colors.white,
            ),
            child: _Checkerboard(
              enabled: checkerboard,
              child: bytes == null
                  ? Center(
                      child: Text(
                        'No processed image yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 8,
                      child: Center(
                        child: Image.memory(
                          bytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Checkerboard extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _Checkerboard({
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return CustomPaint(
      painter: _CheckerboardPainter(),
      child: child,
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const square = 16.0;
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFE2E8F0);

    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        final useDark =
            ((x / square).floor() + (y / square).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, square, square),
          useDark ? dark : light,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ImageEmptyState extends StatelessWidget {
  const _ImageEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 56, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          const Text(
            'No image selected',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick an image to remove a white or black background.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update empty-state widget test expectations**

Modify `renders image tool empty state with disabled actions` in `test/widget_test.dart`:

```dart
  testWidgets('renders image tool empty state with disabled actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ImageTool()));

    expect(find.text('Image Tools'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);

    final removeButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('image-remove-background-button')),
    );
    final exportButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('image-export-button')),
    );

    expect(removeButton.onPressed, isNull);
    expect(exportButton.onPressed, isNull);
    expect(find.byKey(const Key('image-pick-button')), findsOneWidget);
    expect(find.byKey(const Key('image-tolerance-slider')), findsOneWidget);
    expect(find.byKey(const Key('image-feather-switch')), findsOneWidget);
  });
```

- [ ] **Step 3: Run widget tests**

Run:

```bash
flutter test test/widget_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 4: Format the UI**

Run:

```bash
dart format lib/image_tool.dart test/widget_test.dart
```

Expected:

```text
Formatted 2 files
```

If Dart says one or both files are unchanged, continue.

- [ ] **Step 5: Run full Flutter test suite**

Run:

```bash
flutter test
```

Expected:

```text
All tests passed!
```

- [ ] **Step 6: Commit full ImageTool UI**

Run:

```bash
git add lib/image_tool.dart test/widget_test.dart
git commit -m "feat: build image background removal UI"
```

---

### Task 5: Analyze, Manual Smoke Test, And Final Commit Check

**Files:**
- Verify all touched files

- [ ] **Step 1: Run static analysis**

Run:

```bash
flutter analyze
```

Expected:

```text
No issues found!
```

- [ ] **Step 2: Run full tests**

Run:

```bash
flutter test
```

Expected:

```text
All tests passed!
```

- [ ] **Step 3: Run the app for manual smoke testing**

Run:

```bash
flutter run -d linux
```

Expected:

```text
Flutter run key commands.
```

Manual checks:

- The `Image` destination appears in the left navigation.
- The `Image Tools` tab opens without exceptions.
- `Pick Image` opens a native picker.
- A white-background icon previews in the original pane.
- `Remove Background` creates a transparent preview on the checkerboard pane.
- `Tolerance`, `Background`, and `Feather` can be changed without layout overflow.
- `Export PNG` opens save/download behavior and writes a PNG with transparency.

- [ ] **Step 4: Stop the manual app run**

In the `flutter run` terminal, press:

```text
q
```

Expected:

```text
Application finished.
```

- [ ] **Step 5: Inspect git status**

Run:

```bash
git status --short
```

Expected:

```text

```

If `pubspec.lock` changed from `flutter pub add`, ensure it was included in Task 1's commit. If any source files changed after the latest commit, review and commit them:

```bash
git add lib test pubspec.yaml pubspec.lock
git commit -m "chore: finalize image tool verification fixes"
```

Only run this final commit if `git status --short` shows legitimate implementation changes.
