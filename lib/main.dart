import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/pdf_library_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/reader_provider.dart';
import 'providers/reading_progress_provider.dart';
import 'providers/search_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RedReaderApp());
}

class RedReaderApp extends StatelessWidget {
  const RedReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set preferred orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReadingProgressProvider()),
        ChangeNotifierProvider(create: (_) => PdfLibraryProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProxyProvider<ReadingProgressProvider, ReaderProvider>(
          create: (_) => ReaderProvider(),
          update: (_, progressProvider, readerProvider) {
            readerProvider ??= ReaderProvider();
            readerProvider.setProgressProvider(progressProvider);
            return readerProvider;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'RedReader',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
