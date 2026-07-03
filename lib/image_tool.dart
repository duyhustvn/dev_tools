import 'dart:typed_data';

import 'package:dev_tools_pro_max/image_background_remover.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    if (!mounted) return;

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

      if (!mounted) return;
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
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save transparent PNG',
        fileName: '${baseName}_transparent.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
        bytes: bytes,
      );

      if (!mounted) return;
      if (savedPath == null && !kIsWeb) {
        _showStatus('Export canceled.');
      } else {
        _showStatus('PNG export ready.');
      }
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
                    onChangeEnd: isProcessing ? null : onToleranceChangeEnd,
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

  const _Checkerboard({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return CustomPaint(painter: _CheckerboardPainter(), child: child);
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
        final useDark = ((x / square).floor() + (y / square).floor()).isEven;
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
