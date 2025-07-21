import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> hasAllPermissions() async {
    return await Permission.camera.isGranted &&
        await Permission.storage.isGranted;
  }

  // Combined request to prevent multiple dialogs
  static Future<bool> requestAllPermissions() async {
    final results = await [
      Permission.camera,
      Permission.storage,
    ].request();

    return results[Permission.camera]?.isGranted == true &&
        results[Permission.storage]?.isGranted == true;
  }
}