import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import '../services/txa_permission.dart';
import '../services/txa_notification_manager.dart';
import '../services/txa_play_update_service.dart';
import '../theme/txa_theme.dart';
import '../widgets/txa_error_widget.dart';
import '../widgets/txa_maintenance_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  String _status = '';
  bool _hasError = false;
  late AnimationController _breathingController;
  late Animation<double> _glowAnimation;
  late AnimationController _rotationController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Breathing glow animation around logo
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.9).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Rotating outer sweep shimmer ring
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _startInitialization();
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('dongmephim.online');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startInitialization() async {
    setState(() {
      _hasError = false;
      _status = TxaLanguage.t('connecting'); // "Đang kết nối..."
      _progress = 0.15;
    });

    // 1. Connection check
    bool isConnected = await _checkInternet();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    // 2. Fetch configurations / check update & maintenance
    setState(() {
      _status = TxaLanguage.t('splash_config_system'); // "Cấu hình hệ thống..."
      _progress = 0.4;
    });

    Map<String, dynamic>? checkUpdate;
    try {
      checkUpdate = await TxaApi().getCheckUpdate();
      if (checkUpdate == null) {
        throw Exception("Cannot load system configuration");
      }

      // Check Google Play In-App Update immediately on Splash Screen
      await TxaPlayUpdateService.checkInAppUpdateOnSplash();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    // 3. Maintenance check
    if (checkUpdate['maintenance_mode'] == true) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TxaMaintenanceScreen(
              message: checkUpdate!['maintenance_message'] as String?,
            ),
          ),
        );
      }
      return;
    }

    // 4. Notification & Exact Alarm Permission Check & Request
    setState(() {
      _status = TxaLanguage.t('splash_check_permissions'); // "Kiểm tra quyền truy cập..."
      _progress = 0.6;
    });
    
    try {
      await TxaPermission.requestNotificationAndAlarmPermissions();
      await TxaNotificationManager.instance.init();
    } catch (e) {
      // Fail silently if not supported or error occurs
    }

    // 4.1. Battery Optimization Bypass Request
    try {
      if (Platform.isAndroid) {
        final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
        if (!isIgnoring) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
    } catch (e) {
      // Fail silently
    }

    // 5. Language Init
    setState(() {
      _status = TxaLanguage.t('splash_init_language'); // "Khởi tạo ngôn ngữ..."
      _progress = 0.8;
    });
    await TxaLanguage.init();

    setState(() {
      _status = TxaLanguage.t('success');
      _progress = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathingController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: TxaErrorWidget(
          onRetry: _startInitialization,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Color(0x24737DFD), // Subtle accent glow
                    Color(0x0009090B),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with Rotating Glow Ring and Breathing Pulse Effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating Sweep Shimmer Ring (Outer)
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              TxaTheme.accent.withValues(alpha: 0.8),
                              TxaTheme.purple.withValues(alpha: 0.2),
                              TxaTheme.accent.withValues(alpha: 0.05),
                              TxaTheme.purple.withValues(alpha: 0.2),
                              TxaTheme.accent.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Breathing Backlight Glow (Inner)
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 125,
                          height: 125,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            boxShadow: [
                              BoxShadow(
                                color: TxaTheme.accent.withValues(
                                  alpha: _glowAnimation.value * 0.4,
                                ),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: TxaTheme.purple.withValues(
                                  alpha: _glowAnimation.value * 0.3,
                                ),
                                blurRadius: 30,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Transparent Dark Glass Card Behind Logo
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: 126,
                          height: 126,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    // Animated GIF Logo in Center
                    Image.asset(
                      'assets/logo_splash.gif',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const SizedBox(height: 52),

                // Liquid Glass Progress Bar
                TxaTheme.liquidGlassPill(
                  radius: 8,
                  child: Container(
                    width: 250,
                    height: 10,
                    padding: const EdgeInsets.all(1.5),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 247 * _progress,
                          decoration: BoxDecoration(
                            gradient: TxaTheme.brandGradient,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: TxaTheme.accent.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 0.5,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TxaTheme.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
