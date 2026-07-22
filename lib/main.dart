import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'theme/txa_theme.dart';
import 'services/txa_language.dart';
import 'services/txa_auth_service.dart';
import 'services/txa_ads_service.dart';
import 'widgets/splash_screen.dart';
import 'widgets/txa_error_widget.dart';
import 'pages/home_screen.dart';
import 'utils/txa_logger.dart';
import 'utils/txa_platform.dart';
import 'tv/tv_app.dart';
import 'utils/txa_toast.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? launchFilePath;

void main(List<String> args) async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Start logger immediately on line 1 to capture startup logs before any crash
    TxaLogger.init();

    // Custom ErrorWidget builder to catch Flutter UI crashes globally
    ErrorWidget.builder = (FlutterErrorDetails details) {
      TxaLogger.log(
        'FLUTTER UI CRASH: ${details.exceptionAsString()}\n${details.stack}',
        type: 'crash',
      );
      return TxaErrorWidget(errorDetails: details);
    };

    // Initialize MediaKit for Windows only
    if (TxaPlatform.isDesktop && Platform.isWindows) {
      try {
        VideoPlayerMediaKit.ensureInitialized(
          windows: true,
        );
      } catch (e) {
        debugPrint('Failed to initialize VideoPlayerMediaKit: $e');
      }
    }

    if (args.isNotEmpty) {
      launchFilePath = args[0];
    }

    // Set system UI to edge-to-edge for premium liquid transparent bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    await TxaPlatform.init(); // Detect if running on TV
    await TxaLanguage.init();
    
    // Initialize local notification manager (desktop only)
    if (TxaPlatform.isDesktop) {
      try {
        await localNotifier.setup(
          appName: 'DongMePhim',
        );
      } catch (e) {
        TxaLogger.log('LocalNotifier setup error: $e');
      }
    }

    final authService = TxaAuthService();
    await authService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TxaLanguage>.value(value: TxaLanguage()),
          ChangeNotifierProvider<TxaAuthService>.value(value: authService),
        ],
        child: const DongPhimApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    TxaLogger.log('UNCAUGHT ASYNC CRASH: $error\n$stack', type: 'crash');
  });
}

class DongPhimApp extends StatelessWidget {
  const DongPhimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TxaPlatform.tvEmulationNotifier,
      builder: (context, isEmulated, child) {
        if (TxaPlatform.isTV) {
          return const DongPhimTvApp();
        }
        
        return Consumer<TxaLanguage>(
          builder: (context, lang, child) {
            return MaterialApp(
              title: 'DongMePhim',
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              theme: TxaTheme.darkTheme.copyWith(
                textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
              ),
              home: const MainEntry(),
            );
          },
        );
      },
    );
  }
}


class MainEntry extends StatefulWidget {
  const MainEntry({super.key});

  @override
  State<MainEntry> createState() => _MainEntryState();
}

class _MainEntryState extends State<MainEntry> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
          // Schedule 5s App Start Ad (checks VIP status & AdMob settings)
          TxaAdsService().scheduleAppStartAd();

          // Hiện toast chặn file video sau khi splash xong
          if (launchFilePath != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              TxaToast.show(
                context,
                TxaLanguage.t('video_file_blocked'),
                isError: true,
              );
              TxaLogger.log(
                'Blocked external video file: $launchFilePath',
                type: 'app',
              );
              launchFilePath = null;
            });
          }
        },
      );
    }
    return const HomeScreen();
  }
}
