import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/main_shell.dart';
import '../screens/splash_screen.dart';
import '../screens/viewer/pdf_viewer_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static int _getIndexFromPath(String path) {
    switch (path) {
      case '/home':
        return 0;
      case '/history':
        return 1;
      case '/bookmarks':
        return 2;
      case '/settings':
        return 3;
      default:
        return 0;
    }
  }

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // Splash screen for permission and initial scan
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // Main shell with tabs
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const MainShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/bookmarks',
        name: 'bookmarks',
        builder: (context, state) => const MainShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const MainShell(initialIndex: 3),
      ),
      // PDF Viewer route (full screen, not part of shell)
      GoRoute(
        path: '/viewer/:pdfId',
        name: 'viewer',
        builder: (context, state) {
          final pdfId = state.pathParameters['pdfId']!;
          final startPage = int.tryParse(state.uri.queryParameters['page'] ?? '');
          return PdfViewerScreen(
            pdfId: pdfId,
            startPage: startPage,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found: ${state.uri.path}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
