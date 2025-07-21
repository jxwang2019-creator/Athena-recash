import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hackathon/screen/home_screen.dart';
import 'package:hackathon/screen/login_screen.dart';
import 'package:hackathon/screen/register_screen.dart';
import 'package:hackathon/screen/welcome_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Camera initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Auth Banking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/register': (context) => RegisterScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
      // Add this to handle route generation
      onGenerateRoute: (settings) {
        // Always return to auth screen if route not recognized
        return MaterialPageRoute(builder: (context) => WelcomeScreen());
      },
    );
  }
}