import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_iap_service.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';

class TxaZaloBypassModal extends StatefulWidget {
  const TxaZaloBypassModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const TxaZaloBypassModal(),
    );
  }

  @override
  State<TxaZaloBypassModal> createState() => _TxaZaloBypassModalState();
}

class _TxaZaloBypassModalState extends State<TxaZaloBypassModal> {
  final TxaIapService _iapService = TxaIapService();
  bool _isLoading = false;
  String? _purchasedKey;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _initIap();
  }

  Future<void> _initIap() async {
    setState(() => _isLoading = true);
    await _iapService.initialize(
      onSuccess: (keyCode, message) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _purchasedKey = keyCode;
          _statusText = message;
        });
        TxaToast.show(context, message);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusText = error;
        });
        TxaToast.show(context, error, isError: true);
      },
    );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBuy(bool isAdmin) async {
    setState(() {
      _isLoading = true;
      _statusText = null;
    });

    final productId = isAdmin
        ? TxaIapService.productIdAdmin
        : TxaIapService.productIdNormal;

    final success = await _iapService.buyProduct(productId);
    if (!success && mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
      _statusText = null;
    });

    await _iapService.restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      TxaToast.show(context, TxaLanguage.t('iap_restored_success'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    final user = auth.user;
    final bool isAdmin = user != null &&
        (user['role'] == 'admin' || user['roles'] == 'admin' || user['username'] == 'admin');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151828),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: TxaTheme.primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: TxaTheme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Icon Air Drop
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    TxaTheme.primaryColor,
                    Color(0xFF8B5CF6),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: TxaTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                  )
                ],
              ),
              child: const Icon(
                Icons.vpn_key_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              TxaLanguage.t('iap_zalo_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Badge Admin nếu có
            if (isAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      TxaLanguage.t('iap_admin_badge'),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Description
            Text(
              TxaLanguage.t('iap_zalo_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Result display (Mã Key thu được sau mua)
            if (_purchasedKey != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MÃ KEY ZALO CỦA BẠN:',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _purchasedKey!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _purchasedKey!));
                        TxaToast.show(context, 'Đã sao chép mã Key!');
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(TxaLanguage.t('iap_copy_key')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_statusText != null && _purchasedKey == null) ...[
              Text(
                _statusText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _handleBuy(isAdmin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    isAdmin
                        ? 'Mua Ngay qua Google Play (3,000đ)'
                        : 'Mua Ngay qua Google Play',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _handleRestore,
                child: Text(
                  TxaLanguage.t('iap_restore_purchases'),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                TxaLanguage.t('cancel'),
                style: const TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
