import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Shown when a picked image isn't square. Lets the user drag a fixed-size
/// square crop box around the image, then returns the cropped bytes (JPEG)
/// via Navigator.pop. Pops with null if the user cancels.
class SquareCropPage extends StatefulWidget {
  final Uint8List bytes;
  const SquareCropPage({super.key, required this.bytes});

  @override
  State<SquareCropPage> createState() => _SquareCropPageState();
}

class _SquareCropPageState extends State<SquareCropPage> {
  img.Image? _decoded;
  double _offsetX = 0; // top-left of the crop square, in source-image pixels
  double _offsetY = 0;
  double _squareSize = 0;

  @override
  void initState() {
    super.initState();
    _decoded = img.decodeImage(widget.bytes);
    if (_decoded != null) {
      _squareSize = _decoded!.width < _decoded!.height
          ? _decoded!.width.toDouble()
          : _decoded!.height.toDouble();
      _offsetX = (_decoded!.width - _squareSize) / 2;
      _offsetY = (_decoded!.height - _squareSize) / 2;
    }
  }

  void _pan(DragUpdateDetails details, double screenToImageScale) {
    if (_decoded == null) return;
    setState(() {
      _offsetX = (_offsetX - details.delta.dx / screenToImageScale)
          .clamp(0.0, (_decoded!.width - _squareSize).toDouble());
      _offsetY = (_offsetY - details.delta.dy / screenToImageScale)
          .clamp(0.0, (_decoded!.height - _squareSize).toDouble());
    });
  }

  void _confirm() {
    if (_decoded == null) return;
    final cropped = img.copyCrop(
      _decoded!,
      x: _offsetX.round(),
      y: _offsetY.round(),
      width: _squareSize.round(),
      height: _squareSize.round(),
    );
    final out = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    if (_decoded == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Crop to square'),
        ),
        body: const Center(
          child: Text(
            "Couldn't read this image",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final imgW = _decoded!.width.toDouble();
    final imgH = _decoded!.height.toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Drag to position the crop'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: _confirm,
            child: const Text('Use This Crop', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'This logo isn\'t square. Drag the image to choose which part to keep.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availW = constraints.maxWidth;
                final availH = constraints.maxHeight;
                final scale = (availW / imgW < availH / imgH)
                    ? availW / imgW
                    : availH / imgH;
                final displayW = imgW * scale;
                final displayH = imgH * scale;
                final boxLeft = _offsetX * scale;
                final boxTop = _offsetY * scale;
                final boxSize = _squareSize * scale;

                return Center(
                  child: SizedBox(
                    width: displayW,
                    height: displayH,
                    child: GestureDetector(
                      onPanUpdate: (details) => _pan(details, scale),
                      child: Stack(
                        children: [
                          Image.memory(
                            widget.bytes,
                            width: displayW,
                            height: displayH,
                            fit: BoxFit.fill,
                          ),
                          // Dim everything outside the square crop box.
                          Positioned(
                            left: 0,
                            top: 0,
                            width: displayW,
                            height: boxTop,
                            child: Container(color: Colors.black54),
                          ),
                          Positioned(
                            left: 0,
                            top: boxTop + boxSize,
                            width: displayW,
                            height: displayH - boxTop - boxSize,
                            child: Container(color: Colors.black54),
                          ),
                          Positioned(
                            left: 0,
                            top: boxTop,
                            width: boxLeft,
                            height: boxSize,
                            child: Container(color: Colors.black54),
                          ),
                          Positioned(
                            left: boxLeft + boxSize,
                            top: boxTop,
                            width: displayW - boxLeft - boxSize,
                            height: boxSize,
                            child: Container(color: Colors.black54),
                          ),
                          Positioned(
                            left: boxLeft,
                            top: boxTop,
                            width: boxSize,
                            height: boxSize,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}