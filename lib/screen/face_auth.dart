import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:dartz/dartz.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import '../model/face_account.dart';
 // Changed import to use AccountManager

class FaceAuth {
  // Detector
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;

  // Camera
  CameraController? _cameraController;
  bool _isInitialized = false;

  // Configuration
  static const int enrollmentSamples = 3;
  static const int _inputSize = 112;
  static const int _embeddingSize = 192;
  static const double baseThreshold = 0.65;

  // State
  final List<List<double>> _enrollmentEmbeddings = [];
  int _consecutiveFailures = 0;

  bool get isInitialized => _isInitialized;
  CameraController? get cameraController => _cameraController;
  int get successfulCaptures => _enrollmentEmbeddings.length;

  Future<void> initialize() async {
    try {
      // First dispose any existing resources
      await _safeDispose();

      // Initialize detector
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableContours: true,
          enableClassification: true,
        ),
      );

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');

      // Initialize camera with retry logic
      await _initializeCameraWithRetry();

      // Initialize AccountManager
      await AccountManager.init();

      _isInitialized = true;
    } catch (e) {
      await _safeDispose();
      throw Exception('Initialization failed: $e');
    }
  }

  Future<void> _initializeCameraWithRetry() async {
    const maxRetries = 3;
    for (var i = 0; i < maxRetries; i++) {
      try {
        final cameras = await availableCameras();
        _cameraController = CameraController(
          cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        return;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  Future<Either<String, FaceAccount>> authenticate() async {
    if (!_isInitializedCheck()) {
      return Left('FaceAuth not initialized');
    }

    try {
      final currentEmbedding = await _processFaceWithQualityCheck();
      final account = await AccountManager.handleFaceAuthentication([currentEmbedding]);
      return Right(account!);
    } catch (e) {
      return Left('Authentication failed: ${e.toString()}');
    }
  }

  Future<Either<String, List<double>>> captureEnrollmentSample() async {
    if (!_isInitializedCheck()) {
      return Left('FaceAuth not initialized');
    }

    try {
      final embedding = await _processFaceWithQualityCheck();
      _enrollmentEmbeddings.add(embedding);
      _consecutiveFailures = 0;
      return Right(embedding);
    } catch (e) {
      _consecutiveFailures++;
      return Left(e.toString());
    }
  }

  Future<Either<String, FaceAccount>> finalizeEnrollment({
    required String fullName,
    String? phoneNumber,
  }) async {
    if (!_isInitializedCheck()) {
      return Left('FaceAuth not initialized');
    }

    if (_enrollmentEmbeddings.length < 2) {
      return Left('Need at least 2 good samples');
    }

    try {
      final account = await AccountManager.registerNewAccount(
        embeddings: _enrollmentEmbeddings,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
      _enrollmentEmbeddings.clear();
      return Right(account);
    } catch (e) {
      return Left('Failed to create account: ${e.toString()}');
    }
  }

  // For login flow
  Future<FaceAccount?> verifyUser() async {
    if (!_isInitializedCheck()) return null;

    try {
      final currentEmbedding = await _processFaceWithQualityCheck();
      return await AccountManager.authenticateUser(currentEmbedding);
    } catch (e) {
      debugPrint('Verification failed: $e');
      return null;
    }
  }

  Future<List<double>> _processFaceWithQualityCheck() async {
    if (!_isInitializedCheck()) {
      throw Exception('FaceAuth not initialized');
    }

    XFile? imageFile;
    try {
      // Step 1: Image Capture
      imageFile = await _cameraController!.takePicture();

      // Step 2: Face Detection
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception('No faces found in image');
      }
      if (faces.length > 1) {
        throw Exception('Found ${faces.length} faces');
      }

      final face = faces.first;

      // Step 3: Quality Check (simplified without mesh)
      final qualityError = _checkFaceQuality(face);
      if (qualityError != null) {
        throw Exception(qualityError);
      }

      // Step 4: Embedding Generation
      return await _generateEmbedding(inputImage, face);
    } catch (e) {
      rethrow;
    } finally {
      try {
        // Clean up the captured image file
        if (imageFile != null) {
          final file = File(imageFile.path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('Error cleaning up image file: $e');
      }
    }
  }

  String? _checkFaceQuality(Face face) {
    // Basic face quality checks without mesh
    if (face.boundingBox.width < 100 || face.boundingBox.height < 100) {
      return 'Face too small';
    }

    // Check if eyes are open (if landmarks are available)
    if (face.landmarks[FaceLandmarkType.leftEye] != null &&
        face.landmarks[FaceLandmarkType.rightEye] != null) {
      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

      if (leftEyeOpen < 0.3 || rightEyeOpen < 0.3) {
        return 'Eyes not open';
      }
    }

    // Check head rotation
    if (face.headEulerAngleY!.abs() > 20 || face.headEulerAngleX!.abs() > 20) {
      return 'Face not straight';
    }

    return null;
  }

  Future<List<double>> _generateEmbedding(InputImage inputImage, Face face) async {
    // 1. Crop face using bounding box
    final croppedFace = await _cropFace(inputImage, face);

    // 2. Preprocess image
    final input = _preprocessImage(croppedFace);

    // 3. Run inference - Updated output shape
    final output = List.filled(1, List.filled(_embeddingSize, 0.0))
        .reshape([1, _embeddingSize]);
    _interpreter!.run(input, output);

    return _normalizeVector(output[0]);
  }

  Future<img.Image> _cropFace(InputImage inputImage, Face face) async {
    final imageFile = File(inputImage.filePath!);
    final image = img.decodeImage(await imageFile.readAsBytes())!;

    // Get bounding box coordinates
    final rect = face.boundingBox;

    // Expand the bounding box slightly to include more of the face
    final expandedWidth = rect.width * 1.2;
    final expandedHeight = rect.height * 1.2;
    final centerX = rect.left + rect.width / 2;
    final centerY = rect.top + rect.height / 2;

    return img.copyCrop(
      image,
      x: (centerX - expandedWidth / 2).clamp(0, image.width - expandedWidth).toInt(),
      y: (centerY - expandedHeight / 2).clamp(0, image.height - expandedHeight).toInt(),
      width: expandedWidth.clamp(1, image.width).toInt(),
      height: expandedHeight.clamp(1, image.height).toInt(),
    );
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

    return [
      List.generate(
        _inputSize,
            (y) => List.generate(
          _inputSize,
              (x) => List.generate(
            3,
                (ch) => (resized.getPixel(x, y).toList()[ch] / 127.5) - 1.0,
          ),
        ),
      )
    ];
  }

  List<double> _normalizeVector(List<double> vector) {
    final norm = sqrt(vector.map((x) => x * x).reduce((a, b) => a + b));
    return vector.map((x) => x / norm).toList();
  }


  Future<void> dispose() async {
    await _safeDispose();
  }

  Future<void> _safeDispose() async {
    try {
      await _cameraController?.dispose();
      await _faceDetector?.close();
      _interpreter?.close();
    } catch (e) {
      debugPrint('Error disposing resources: $e');
    } finally {
      _isInitialized = false;
      _cameraController = null;
      _faceDetector = null;
      _interpreter = null;
    }
  }

  bool _isInitializedCheck() {
    if (!_isInitialized || _faceDetector == null || _interpreter == null || _cameraController == null) {
      debugPrint('FaceAuth not properly initialized');
      return false;
    }
    return true;
  }


}