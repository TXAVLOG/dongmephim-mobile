import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import '../utils/txa_platform.dart';
import '../tv/widgets/tv_focusable_card.dart';
import '../tv/navigation/tv_focus_system.dart';
import '../main.dart';
import '../tv/screens/tv_splash_screen.dart';

class TxaMaintenanceScreen extends StatefulWidget {
  final String? message;

  const TxaMaintenanceScreen({
    super.key,
    this.message,
  });

  @override
  State<TxaMaintenanceScreen> createState() => _TxaMaintenanceScreenState();
}

class _TxaMaintenanceScreenState extends State<TxaMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  Timer? _pollingTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Rotate the gears continuously
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Poll server every 30 seconds to check if maintenance has ended
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkMaintenanceStatus();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkMaintenanceStatus() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    try {
      final info = await TxaApi().getCheckUpdate();
      if (info != null && info['maintenance_mode'] != true) {
        // Maintenance is over! Restart to splash screen
        _pollingTimer?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => TxaPlatform.isTV
                  ? const TvSplashScreen()
                  : const MainEntry(),
            ),
            (route) => false,
          );
        }
      }
    } catch (_) {
      // Ignore network errors during polling
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _exitApp() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = TxaLanguage.t('maintenance_title');
    final desc = widget.message ?? TxaLanguage.t('maintenance_msg');

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Spinning Gears CustomPaint
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return SizedBox(
                    width: 160,
                    height: 120,
                    child: CustomPaint(
                      painter: _GearsPainter(_rotationController.value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Polling status loader indicator
              if (_isChecking) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF737DFD),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  TxaLanguage.currentLang == 'vi'
                      ? 'Đang kiểm tra lại trạng thái...'
                      : 'Rechecking status...',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
                const SizedBox(height: 24),
              ],

              // Exit Button
              _buildExitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    final btnText = TxaLanguage.t('exit_app');

    if (TxaPlatform.isTV) {
      final focusNode = TvFocusSystem.getNode('maintenance_exit_btn');
      return SizedBox(
        width: 180,
        height: 46,
        child: TvFocusableCard(
          focusNode: focusNode,
          onTap: _exitApp,
          scaleOnFocus: 1.05,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Colors.redAccent.withValues(alpha: 0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  btnText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _exitApp,
      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
      label: Text(btnText),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
        ),
      ),
    );
  }
}

class _GearsPainter extends CustomPainter {
  final double rotation;

  _GearsPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final centerBig = Offset(size.width * 0.42, size.height * 0.45);
    final centerSmall = Offset(size.width * 0.60, size.height * 0.65);

    // Paint configs
    final gearPaint = Paint()
      ..color = const Color(0xFF475569) // Slate Gray
      ..style = PaintingStyle.fill;

    final smallGearPaint = Paint()
      ..color = const Color(0xFF737DFD) // Accent Blue
      ..style = PaintingStyle.fill;

    final holePaint = Paint()
      ..color = const Color(0xFF0C0D14) // Match background
      ..style = PaintingStyle.fill;

    // Draw Big Gear (Rotates counter-clockwise)
    canvas.save();
    canvas.translate(centerBig.dx, centerBig.dy);
    canvas.rotate(-rotation * 2 * 3.14159);
    _drawGear(canvas, 32.0, 8.0, 8, gearPaint);
    canvas.drawCircle(Offset.zero, 10.0, holePaint);
    canvas.restore();

    // Draw Small Gear (Rotates clockwise, faster)
    canvas.save();
    canvas.translate(centerSmall.dx, centerSmall.dy);
    canvas.rotate(rotation * 2 * 3.14159 * 1.77 + 0.3); // Gear ratio speed diff & offset
    _drawGear(canvas, 18.0, 5.0, 6, smallGearPaint);
    canvas.drawCircle(Offset.zero, 6.0, holePaint);
    canvas.restore();
  }

  void _drawGear(Canvas canvas, double radius, double teethDepth, int teethCount, Paint paint) {
    // Draw center core
    canvas.drawCircle(Offset.zero, radius - teethDepth / 2, paint);

    // Draw teeth
    final double angleStep = 2 * 3.14159 / teethCount;
    for (int i = 0; i < teethCount; i++) {
      canvas.save();
      canvas.rotate(i * angleStep);

      // Draw trapezoidal tooth pointing outwards
      final path = Path()
        ..moveTo(-radius * 0.25, -radius)
        ..lineTo(-radius * 0.15, -radius - teethDepth)
        ..lineTo(radius * 0.15, -radius - teethDepth)
        ..lineTo(radius * 0.25, -radius)
        ..close();
      canvas.drawPath(path, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GearsPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
