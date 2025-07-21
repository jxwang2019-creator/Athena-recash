import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FullScreenCameraPreview extends StatelessWidget {
  final CameraController controller;

  const FullScreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.0, // Remove if you want front-camera mirroring
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          );
        },
      ),
    );
  }
}
