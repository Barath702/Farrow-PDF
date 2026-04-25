import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static int? _cachedSdkVersion;

  /// Check if storage permission is needed for the current platform
  static bool get needsStoragePermission {
    if (Platform.isLinux) return false;
    if (Platform.isAndroid) return true;
    return false;
  }

  /// Get Android SDK version with caching
  static Future<int> _getAndroidSdkVersion() async {
    if (_cachedSdkVersion != null) return _cachedSdkVersion!;

    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _cachedSdkVersion = androidInfo.version.sdkInt;
        return _cachedSdkVersion!;
      } catch (e) {
        return 30; // Default to Android 11 if we can't detect
      }
    }
    return 0;
  }

  /// Request all necessary storage permissions based on Android version
  static Future<bool> requestStoragePermissions() async {
    if (Platform.isLinux) return true;
    if (!Platform.isAndroid) return true;

    final sdkVersion = await _getAndroidSdkVersion();

    if (sdkVersion >= 33) {
      // Android 13+ (API 33+): Request media permissions and manage external storage
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      final manageStorage = await Permission.manageExternalStorage.request();

      return photos.isGranted || videos.isGranted || manageStorage.isGranted;
    } else if (sdkVersion >= 30) {
      // Android 11-12 (API 30-32): Request manage external storage
      final manageStorage = await Permission.manageExternalStorage.request();
      return manageStorage.isGranted;
    } else {
      // Android 10 and below (API < 30): Request traditional storage permission
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
  }

  /// Check if storage permissions are granted
  static Future<bool> areStoragePermissionsGranted() async {
    if (Platform.isLinux) return true;
    if (!Platform.isAndroid) return true;

    final sdkVersion = await _getAndroidSdkVersion();

    if (sdkVersion >= 33) {
      // Android 13+: Check media permissions
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final manageStorage = await Permission.manageExternalStorage.status;

      return photos.isGranted || videos.isGranted || manageStorage.isGranted;
    } else if (sdkVersion >= 30) {
      // Android 11-12: Check manage external storage
      final manageStorage = await Permission.manageExternalStorage.status;
      return manageStorage.isGranted;
    } else {
      // Android 10 and below: Check storage permission
      final storage = await Permission.storage.status;
      return storage.isGranted;
    }
  }

  /// Check if permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied() async {
    if (Platform.isLinux) return false;
    if (!Platform.isAndroid) return false;

    final sdkVersion = await _getAndroidSdkVersion();

    if (sdkVersion >= 33) {
      final photos = await Permission.photos.status;
      return photos.isPermanentlyDenied;
    } else if (sdkVersion >= 30) {
      final manageStorage = await Permission.manageExternalStorage.status;
      return manageStorage.isPermanentlyDenied;
    } else {
      final storage = await Permission.storage.status;
      return storage.isPermanentlyDenied;
    }
  }

  /// Show permission rationale dialog before requesting
  static Future<bool> showPermissionRationaleAndRequest(BuildContext context) async {
    final sdkVersion = await _getAndroidSdkVersion();

    // Show rationale dialog first
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Storage Access Required',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          sdkVersion >= 30
              ? 'RedReader needs access to all files to find and display your PDF documents. This permission is required to scan your device for PDF files.'
              : 'RedReader needs storage access to find and display your PDF files on your device.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Not Now',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );

    return shouldProceed ?? false;
  }

  /// Show dialog for permanently denied permission
  static void showPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Storage permission has been permanently denied. Please open app settings and enable storage access to use RedReader.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }

  /// Main permission flow - call this at app startup
  static Future<bool> handleStoragePermission(BuildContext context) async {
    if (Platform.isLinux) return true;

    // Check if already granted
    if (await areStoragePermissionsGranted()) {
      return true;
    }

    // Check if permanently denied
    if (await isPermissionPermanentlyDenied()) {
      if (context.mounted) {
        showPermanentlyDeniedDialog(context);
      }
      return false;
    }

    // Show rationale and request
    if (context.mounted) {
      final proceed = await showPermissionRationaleAndRequest(context);
      if (!proceed) return false;
    }

    // Request permissions
    final granted = await requestStoragePermissions();

    if (!granted && context.mounted) {
      // Check if permanently denied after request
      if (await isPermissionPermanentlyDenied()) {
        showPermanentlyDeniedDialog(context);
      }
    }

    return granted;
  }
}
