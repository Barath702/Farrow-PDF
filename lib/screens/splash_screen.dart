import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/permission_service.dart';
import '../services/file_scanner_service.dart';
import '../providers/pdf_library_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Initializing...';
  bool _isScanning = false;
  bool _permissionGranted = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Linux doesn't need storage permission
    if (Platform.isLinux) {
      setState(() {
        _permissionGranted = true;
        _status = 'Scanning for PDF files...';
        _isScanning = true;
      });
      await _scanForPdfs();
      return;
    }

    // Check and request storage permission
    setState(() {
      _status = 'Checking permissions...';
    });

    final hasPermission = await PermissionService.areStoragePermissionsGranted();

    if (hasPermission) {
      setState(() {
        _permissionGranted = true;
        _status = 'Scanning for PDF files...';
        _isScanning = true;
      });
      await _scanForPdfs();
    } else {
      // Show permission request
      if (mounted) {
        final proceed = await PermissionService.showPermissionRationaleAndRequest(context);
        if (!proceed) {
          setState(() {
            _status = 'Storage permission is required to use Farrow';
            _isScanning = false;
          });
          return;
        }

        final granted = await PermissionService.requestStoragePermissions();

        if (granted) {
          setState(() {
            _permissionGranted = true;
            _status = 'Scanning for PDF files...';
            _isScanning = true;
          });
          await _scanForPdfs();
        } else {
          // Check if permanently denied
          final permanentlyDenied = await PermissionService.isPermissionPermanentlyDenied();
          if (permanentlyDenied && mounted) {
            PermissionService.showPermanentlyDeniedDialog(context);
          }
          setState(() {
            _status = 'Storage permission is required to use Farrow';
            _isScanning = false;
          });
        }
      }
    }
  }

  Future<void> _scanForPdfs() async {
    try {
      // Scan for PDF files
      final scannedFiles = await FileScannerService.scanForPdfFiles();

      // Import scanned PDFs into library
      if (scannedFiles.isNotEmpty && mounted) {
        // Note: In a real app, you'd use a provider here
        // For now, we just scan and cache
      }

      // Preload metadata during splash screen
      if (mounted) {
        setState(() {
          _status = 'Loading thumbnails...';
        });
        await context.read<PdfLibraryProvider>().preloadPdfMetadata();
      }

      if (mounted) {
        // Navigate to main app
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error scanning for PDFs. Please try again.';
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App icon/logo with animation
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Image.asset(
                'assets/icon/app_icon.png',
                height: 100,
              ),
            ),
            const SizedBox(height: 32),
            // App name
            Text(
              'Farrow',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF READER',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.onSecondaryContainer,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 48),
            // Status and loading
            if (_isScanning) ...[
              const CircularProgressIndicator(
                color: AppColors.primaryContainer,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSecondaryContainer,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Retry button if failed
            if (!_isScanning && !_permissionGranted)
              ElevatedButton(
                onPressed: _initializeApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Grant Permission'),
              ),
          ],
        ),
      ),
    );
  }
}
