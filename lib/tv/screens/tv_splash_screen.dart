import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/txa_language.dart';
import '../../services/txa_api.dart';
import '../../services/txa_notification_manager.dart';
import '../../utils/txa_platform.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import '../services/tv_device_service.dart';
import '../../widgets/txa_error_widget.dart';
import '../../widgets/txa_maintenance_screen.dart';
import 'tv_home_screen.dart';

class TvSplashScreen extends StatefulWidget {
  const TvSplashScreen({super.key});

  @override
  State<TvSplashScreen> createState() => _TvSplashScreenState();
}

class _TvSplashScreenState extends State<TvSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  String _status = '';
  double _progress = 0.0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTvInit();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('dongmephim.online');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startTvInit() async {
    setState(() {
      _hasError = false;
      _status = TxaLanguage.t('connecting'); // "Đang kết nối..."
      _progress = 0.2;
    });

    // 1. Samsung TV check
    if (TxaPlatform.isSamsungTV) {
      setState(() {
        _status = TxaLanguage.t('tv_unsupported_device');
        _progress = 1.0;
      });
      _showSamsungBlockDialog();
      return;
    }

    // 2. Internet Connection check
    bool isConnected = await _checkInternet();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    // Initialize TV Device registration on Supabase
    setState(() {
      _status = TxaLanguage.t('tv_registering_device');
      _progress = 0.4;
    });
    try {
      await TvDeviceService().initialize();
    } catch (e) {
      debugPrint('Device registration error: $e');
    }

    // Fetch configurations / check update & maintenance
    setState(() {
      _status = TxaLanguage.t('tv_loading_config');
      _progress = 0.7;
    });
    
    Map<String, dynamic>? checkUpdate;
    try {
      checkUpdate = await TxaApi().getCheckUpdate();
      if (checkUpdate == null) {
        throw Exception("Cannot load system configuration");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
      return;
    }

    // Maintenance check
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

    try {
      await TxaNotificationManager.instance.init();
    } catch (_) {}

    setState(() {
      _status = TxaLanguage.t('tv_init_success');
      _progress = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Route directly to TvHomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TvHomeScreen()),
    );
  }

  Future<void> _showSamsungBlockDialog() async {
    final exitNode = TvFocusSystem.getNode('samsung_exit_btn');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Text(TxaLanguage.t('tv_unsupported_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            TxaLanguage.t('tv_samsung_block_msg'),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.5),
          ),
          actions: [
            TvFocusableCard(
              focusNode: exitNode,
              onTap: () {
                SystemNavigator.pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: Colors.redAccent,
                child: Text(
                  TxaLanguage.t('tv_exit_app'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF090A0F),
        body: TxaErrorWidget(
          onRetry: _startTvInit,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing breathing logo in TV format
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF737DFD).withValues(
                          alpha: _glowAnimation.value * 0.45,
                        ),
                        blurRadius: 50,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ClipOval(
                child: Container(
                  color: Colors.black45,
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/logo_splash.gif',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // TV Glass Progress indicator
            Container(
              width: 320,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 318 * _progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF737DFD), Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              _status,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

