import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
  String? _masterKey;
  List<String> _generatedKeys = [];
  int? _copiedIndex;
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
        _onKeyReceived(keyCode, message);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusText = error;
        });
        TxaToast.show(context, error, isError: true);
      },
      onPending: (statusMessage) {
        if (!mounted) return;
        setState(() {
          _isLoading = true;
          _statusText = statusMessage;
        });
      },
    );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onKeyReceived(String? keyCode, String message) {
    if (keyCode == null || keyCode.isEmpty) return;
    final master = keyCode;
    final keys = List.generate(
      15,
      (i) => '$master-${(i + 1).toString().padLeft(2, '0')}',
    );

    setState(() {
      _isLoading = false;
      _masterKey = master;
      _generatedKeys = keys;
      _statusText = message;
    });
    TxaToast.show(context, message);
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
      _statusText = 'Đang quét lịch sử đơn hàng Google Play...';
    });

    final restored = await _iapService.restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      if (restored) {
        TxaToast.show(context, TxaLanguage.t('iap_restored_success'));
      } else {
        TxaToast.show(
          context,
          'Không tìm thấy đơn hàng nào để khôi phục.',
          isError: true,
        );
      }
    }
  }

  void _copyKey(int index, String key) {
    Clipboard.setData(ClipboardData(text: key));
    setState(() {
      _copiedIndex = index;
    });
    TxaToast.show(
      context,
      TxaLanguage.t('iap_key_copied_toast', replace: {'n': '${index + 1}'}),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _copiedIndex == index) {
        setState(() => _copiedIndex = null);
      }
    });
  }

  void _exportTxt() {
    if (_generatedKeys.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('=== DONGMEPHIM - DANH SÁCH 15 MÃ KEY BYPASS ZALO ===');
    buffer.writeln('Mã Master Key: $_masterKey');
    buffer.writeln('Ngày cấp: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('--------------------------------------------------');
    for (int i = 0; i < _generatedKeys.length; i++) {
      buffer.writeln('Key #${(i + 1).toString().padLeft(2, '0')}: ${_generatedKeys[i]}');
    }
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('Hướng dẫn: Sử dụng mỗi mã Key trên 1 thiết bị để tự động duyệt Zalo qua Bot.');

    final content = buffer.toString();
    // ignore: deprecated_member_use
    Share.share(content, subject: 'Zalo_Bypass_Keys_$_masterKey.txt');
    TxaToast.show(context, TxaLanguage.t('iap_txt_exported_toast'));
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

            // Result display (Bảng 15 Mã Key thu được sau mua / restore)
            if (_generatedKeys.isNotEmpty) ...[
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 280),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            TxaLanguage.t('iap_key_table_title'),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '15 Keys',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _generatedKeys.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final keyStr = _generatedKeys[index];
                          final isCopied = _copiedIndex == index;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCopied ? Colors.green.withValues(alpha: 0.25) : const Color(0xFF1E2235),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCopied ? Colors.greenAccent : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${(index + 1).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    keyStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _copyKey(index, keyStr),
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isCopied ? Colors.green : TxaTheme.primaryColor.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isCopied ? 'Đã chép!' : TxaLanguage.t('iap_copy_key'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportTxt,
                        icon: const Icon(Icons.description_rounded, size: 16),
                        label: Text(
                          TxaLanguage.t('iap_export_txt'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_statusText != null && _generatedKeys.isEmpty) ...[
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
                        ? 'Mua Ngay qua Google Play (Ưu đãi Admin)'
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
