import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../model/face_account.dart';
import '../widget/camera_preview_widget.dart';
import 'face_auth.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late FaceAuth _faceAuth;
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _cameraInitialized = false;
  String? _currentError;

  final List<String> _steps = [
    "Look straight ahead (Neutral)",
    "Turn head slightly left",
    "Turn head slightly right",
    "Look slightly up",
    "Look slightly down"
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    if (_cameraInitialized) {
      _faceAuth.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeFaceAuth() async {
    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      _faceAuth = FaceAuth();
      await _faceAuth.initialize();
      setState(() => _cameraInitialized = true);
    } catch (e) {
      setState(() => _currentError = 'Camera initialization failed: ${e.toString()}');
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _captureStep() async {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      await _initializeFaceAuth(); // Initialize camera only when proceeding to face capture
      if (!_cameraInitialized) return; // Don't proceed if camera failed to initialize
    }

    setState(() {
      _isProcessing = true;
      _currentError = null;
    });

    try {
      final result = await _faceAuth.captureEnrollmentSample();

      result.fold(
            (error) => setState(() => _currentError = error),
            (_) {
          setState(() {
            if (_currentStep <= _steps.length - 1) {
              _currentStep++;
            } else {
              _completeRegistration();
            }
          });
        },
      );
    } catch (e) {
      setState(() => _currentError = 'Capture failed: ${e.toString()}');
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _completeRegistration() async {
    setState(() => _isProcessing = true);

    final result = await _faceAuth.finalizeEnrollment(
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    result.fold(
          (error) => setState(() => _currentError = error),
          (account) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
    );

    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registration")),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentStep + 1) / (_steps.length + 1),
            ),
            if (_currentError != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _currentError!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _currentStep == 0
                    ? _buildUserInfoForm()
                    : _buildFaceCaptureStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name*',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isProcessing ? null : _captureStep,
            child: _isProcessing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text("Continue to Face Registration"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceCaptureStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            children: [
              Text(
                _steps[_currentStep - 1],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Make sure your face is well-lit and clearly visible",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_cameraInitialized)
                  FullScreenCameraPreview(controller: _faceAuth.cameraController!)
                else
                  const CircularProgressIndicator(),

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

        Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _captureStep,
            child: _isProcessing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(_currentStep == _steps.length ? "Complete Registration" : "Capture"),
          ),
        ),
        if (_currentStep > 1)
          TextButton(
            onPressed: _isProcessing ? null : () => setState(() => _currentStep--),
            child: const Text("Retry Previous Step"),
          ),
      ],
    );
  }
}