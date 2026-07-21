import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/google/txa_google_auth_factory.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_logger.dart';

class TxaGoogleAuthModal extends StatefulWidget {
  const TxaGoogleAuthModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const TxaGoogleAuthModal(),
    );
  }

  @override
  State<TxaGoogleAuthModal> createState() => _TxaGoogleAuthModalState();
}

class _TxaGoogleAuthModalState extends State<TxaGoogleAuthModal> {
  String _statusMessage = TxaLanguage.t('initializing_connection');

  @override
  void initState() {
    super.initState();
    _startAuthFlow();
  }

  Future<void> _startAuthFlow() async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = TxaLanguage.t('opening_google_login');
      });

      final strategy = TxaGoogleAuthFactory.create();
      final tokens = await strategy.authenticate(context);

      if (!mounted) return;
      setState(() {
        _statusMessage = TxaLanguage.t('authenticating_system');
      });

      final auth = Provider.of<TxaAuthService>(context, listen: false);
      final result = await auth.loginWithGoogle(
        idToken: tokens['idToken'],
        accessToken: tokens['accessToken'],
      );

      if (!mounted) return;

      if (result['success'] == true) {
        TxaToast.show(context, result['message'] ?? TxaLanguage.t('login_success'));
        Navigator.of(context).pop(true);
      } else if (result['isNewGoogleUser'] == true) {
        // Có thể navigate qua trang đăng ký Google nếu cần, ở đây hiện thông báo
        TxaToast.show(context, result['message'] ?? TxaLanguage.t('google_login_not_registered'));
        Navigator.of(context).pop(false);
      } else {
        TxaToast.show(context, result['message'] ?? TxaLanguage.t('google_login_failed'));
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      TxaLogger.log('Google Auth flow error: $e', type: 'auth');
      if (mounted) {
        final errorMsg = TxaLanguage.t('google_login_conn_error', replace: {'e': e.toString().replaceAll('Exception: ', '')});
        TxaToast.show(context, errorMsg, isError: true);
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/google.png', width: 48, height: 48),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: TxaTheme.accent),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
