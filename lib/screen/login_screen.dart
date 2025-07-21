import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../model/face_account.dart';
import '../widget/camera_preview_widget.dart';
import 'face_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late FaceAuth _faceAuth;
  bool _isProcessing = false;
  bool _cameraInitialized = false;
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _initializeFaceAuth();
  }

  Future<void> _initializeFaceAuth() async {
    _faceAuth = FaceAuth();
    try {
      await _faceAuth.initialize();
      setState(() => _cameraInitialized = true);
    } catch (e) {
      setState(() => _currentError = 'Camera initialization failed: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _faceAuth.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      final account = await _faceAuth.verifyUser();
      if (account != null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => _currentError = 'No matching account found. Please register.');
      }
    } catch (e) {
      setState(() => _currentError = 'Login failed: ${e.toString()}');
    }

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Column(
        children: [
          if (_currentError != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _currentError!,
                style: TextStyle(color: Colors.red),
              ),
            ),
          // Expanded camera preview with face circle overlay
          Expanded(
            child: Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera preview (full screen)
                  if (_cameraInitialized)
                    FullScreenCameraPreview(controller: _faceAuth.cameraController!)
                  else
                    const Center(child: CircularProgressIndicator()),

                  // Face circle overlay
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scan Face Button (at the bottom)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _attemptLogin,
                    child: _isProcessing
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text("Scan Face"),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back to Welcome Screen"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}