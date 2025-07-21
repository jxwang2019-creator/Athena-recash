// import 'dart:math';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
//
// import 'face_account.dart';
// import 'face_auth.dart';
//
// class AuthScreen extends StatefulWidget {
//   @override
//   _AuthScreenState createState() => _AuthScreenState();
// }
//
// class _AuthScreenState extends State<AuthScreen> {
//   late FaceAuth _faceAuth;
//   bool _isLoading = true;
//   String? _currentError;
//   int _processingStep = 0; // 0 = detecting, 1 = registering, 2 = verifying
//   final List<String> _processingMessages = [
//     "Looking for your face...",
//     "Registering your face...",
//     "Verifying your identity..."
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _initialize();
//   }
//
//   Future<void> _initialize() async {
//     await AccountManager.init();
//     _faceAuth = FaceAuth();
//     try {
//       await _faceAuth.initialize();
//       _startFaceProcessing();
//       setState(() => _isLoading = false);
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _currentError = 'Camera initialization failed';
//       });
//     }
//   }
//
//   Future<void> _startFaceProcessing() async {
//     while (mounted) {
//       // Continue processing while widget is active
//       setState(() {
//         _processingStep = 0;
//         _currentError = null;
//       });
//
//       try {
//         // Step 1: Try to find existing account
//         setState(() => _processingStep = 2);
//         final existingAccount = await _faceAuth.verifyUser();
//
//         if (existingAccount != null) {
//           AccountManager.currentAccount = existingAccount;
//           if (mounted) Navigator.pushReplacementNamed(context, '/home');
//           return;
//         }
//
//         // Step 2: If no account found, start registration
//         setState(() => _processingStep = 1);
//         final result = await _faceAuth.captureEnrollmentSample();
//
//         result.fold(
//           (error) => setState(() => _currentError = error),
//           (_) async {
//             final enrollmentResult = await _faceAuth.finalizeEnrollment();
//             enrollmentResult.fold(
//                   (error) => setState(() => _currentError = error),
//                   (newAccount) async {
//                 await _handleSuccessfulAuth(newAccount);
//               },
//             );
//           },
//         );
//       } catch (e) {
//         setState(() => _currentError = 'Processing failed. Try again.');
//       }
//
//       await Future.delayed(Duration(seconds: 2));
//     }
//   }
//
//   Future<void> _handleSuccessfulAuth(FaceAccount account) async {
//     // Ensure account is set as current BEFORE navigation
//     AccountManager.currentAccount = account;
//     await AccountManager.saveAccounts();
//
//     if (mounted) {
//       Navigator.pushReplacementNamed(context, '/home');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Face Authentication')),
//       body: Column(
//         children: [
//           Expanded(
//             child: _faceAuth.isInitialized
//                 ? Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       CameraPreview(_faceAuth.cameraController!),
//                       if (_isLoading || _processingStep > 0)
//                         Container(
//                           color: Colors.black54,
//                           child: Center(
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 const CircularProgressIndicator(),
//                                 const SizedBox(height: 20),
//                                 Text(
//                                   _processingMessages[_processingStep],
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 20,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       _buildFacePositionGuide(),
//                     ],
//                   )
//                 : const Center(child: Text('Camera not available')),
//           ),
//           if (_currentError != null)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 20),
//               child: Text(
//                 _currentError!,
//                 style: const TextStyle(color: Colors.red, fontSize: 16),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFacePositionGuide() {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final circleSize = min(screenWidth * 0.7, 300.0).toDouble();
//
//     return IgnorePointer(
//       child: Container(
//         width: circleSize,
//         height: circleSize,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           border: Border.all(
//             color: Colors.white.withOpacity(0.3),
//             width: 2.0,
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _faceAuth.dispose();
//     super.dispose();
//   }
// }
