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
