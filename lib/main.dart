import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:app_links/app_links.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'theme/txa_theme.dart';
import 'services/txa_language.dart';
import 'services/txa_auth_service.dart';
import 'services/txa_ads_service.dart';
import 'services/txa_dynamic_icon_service.dart';
import 'features/download/services/txa_download_manager.dart';
import 'widgets/splash_screen.dart';
import 'widgets/txa_error_widget.dart';
import 'widgets/txa_modal.dart';
import 'widgets/txa_update_changelog_modal.dart';
import 'pages/home_screen.dart';
import 'utils/txa_logger.dart';
import 'utils/txa_navigator.dart';
import 'utils/txa_platform.dart';
import 'tv/tv_app.dart';
import 'utils/txa_toast.dart';

export 'utils/txa_navigator.dart' show navigatorKey;
String? launchFilePath;

void main(List<String> args) async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Start logger immediately on line 1 to capture startup logs before any crash
    TxaLogger.init();
    TxaLogger.log('Startup: Logger initialized', type: 'app');

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
        TxaLogger.log('Startup: Initializing MediaKit...', type: 'app');
        VideoPlayerMediaKit.ensureInitialized(
          windows: true,
        );
        TxaLogger.log('Startup: MediaKit initialized', type: 'app');
      } catch (e) {
        debugPrint('Failed to initialize VideoPlayerMediaKit: $e');
        TxaLogger.log('Startup: MediaKit Init Error: $e', type: 'crash');
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

    try {
      TxaLogger.log('Startup: Initializing TxaPlatform...', type: 'app');
      await TxaPlatform.init(); // Detect if running on TV
      TxaLogger.log('Startup: TxaPlatform initialized', type: 'app');

      TxaLogger.log('Startup: Initializing TxaLanguage...', type: 'app');
      await TxaLanguage.init();
      TxaLogger.log('Startup: TxaLanguage initialized', type: 'app');
    } catch (e, s) {
      TxaLogger.log('Startup: Platform/Language Init Crash: $e\n$s', type: 'crash');
      rethrow;
    }

    // Initialize local notification manager (desktop only)
    if (TxaPlatform.isDesktop) {
      try {
        TxaLogger.log('Startup: Setting up LocalNotifier...', type: 'app');
        await localNotifier.setup(
          appName: 'DongMePhim',
        );
        TxaLogger.log('Startup: LocalNotifier setup complete', type: 'app');
      } catch (e) {
        TxaLogger.log('Startup: LocalNotifier setup error: $e', type: 'crash');
      }
    }

    TxaAuthService? authService;
    try {
      TxaLogger.log('Startup: Initializing TxaAuthService...', type: 'app');
      authService = TxaAuthService();
      await authService.initialize();
      TxaLogger.log('Startup: TxaAuthService initialized', type: 'app');
    } catch (e, s) {
      TxaLogger.log('Startup: AuthService Init Crash: $e\n$s', type: 'crash');
      rethrow;
    }

    TxaLogger.log('Startup: Calling runApp...', type: 'app');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TxaLanguage>.value(value: TxaLanguage()),
          ChangeNotifierProvider<TxaAuthService>.value(value: authService),
          ChangeNotifierProvider<TxaDownloadManager>.value(value: TxaDownloadManager()),
        ],
        child: const DongPhimApp(),
      ),
    );
    TxaLogger.log('Startup: runApp called successfully', type: 'app');
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
              builder: (context, child) {
                final mediaQueryData = MediaQuery.of(context);
                final clampedTextScale = mediaQueryData.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.15,
                );
                return MediaQuery(
                  data: mediaQueryData.copyWith(textScaler: clampedTextScale),
                  child: child ?? const SizedBox.shrink(),
                );
              },
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
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    try {
      final appLinks = AppLinks();
      _linkSubscription = appLinks.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      TxaLogger.log('Error initializing AppLinks: $e', type: 'app');
    }
  }

  void _handleDeepLink(Uri uri) {
    TxaLogger.log('Received deep link: $uri', type: 'app');
    final path = uri.path;
    final host = uri.host;

    if (host == 'payment-status' || path.contains('payment-status') || path.contains('checkout/callback')) {
      final status = uri.queryParameters['status'] ?? 'approved';
      final txid = uri.queryParameters['txid'] ?? '';
      
      final isSuccess = status == 'approved' || status == 'success' || status == 'completed';
      final msg = isSuccess
          ? 'Thanh toán SePay thành công! Đơn hàng #$txid đã được kích hoạt.'
          : 'Giao dịch SePay #$txid chưa hoàn tất hoặc đã bị hủy.';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          TxaToast.show(ctx, msg, isError: !isSuccess);
        }
      });
    }
  }

  Future<void> _checkIOSVersionAndShowModal() async {
    if (!Platform.isIOS) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final systemVersion = iosInfo.systemVersion; // e.g. "17.4", "18.0", "27.0"
      final majorVersion = int.tryParse(systemVersion.split('.').first) ?? 0;

      // Check if running on iOS 17 or higher (or iOS 27 / new releases)
      if (majorVersion >= 17) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final ctx = navigatorKey.currentContext;
          if (ctx == null || !ctx.mounted) return;

          final msg = TxaLanguage.t('ios_version_warning_msg', replace: {'ver': systemVersion});

          await TxaModal.show<void>(
            ctx,
            title: TxaLanguage.t('ios_version_warning_title'),
            barrierDismissible: false,
            showClose: false,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 42),
                ),
                const SizedBox(height: 16),
                Text(
                  msg,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  final navCtx = navigatorKey.currentContext ?? ctx;
                  Navigator.of(navCtx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 46),
                ),
                child: Text(
                  TxaLanguage.t('ios_version_warning_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          );
        });
      }
    } catch (e) {
      TxaLogger.log('Error checking iOS version: $e', type: 'app');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () async {
          setState(() {
            _showSplash = false;
          });
          // Schedule 5s App Start Ad (checks VIP status & AdMob settings)
          TxaAdsService().scheduleAppStartAd();

          // Run app start app icon check
          final user = Provider.of<TxaAuthService>(context, listen: false).user;
          final wasReset = await TxaDynamicIconService.checkAndRevertExpiredOrUnlicensedIcon(user);
          if (wasReset) {
            final navCtx = navigatorKey.currentContext;
            if (navCtx != null && navCtx.mounted) {
              TxaToast.show(navCtx, TxaLanguage.t('icon_expired_reverted'), isError: true);
            }
          }

          // Check iOS version and show TxaModal warning right after splash
          _checkIOSVersionAndShowModal();

          // Show Update Changelog Modal if first launch after version update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = navigatorKey.currentContext ?? context;
            TxaUpdateChangelogModal.checkAndShow(ctx);
          });

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
