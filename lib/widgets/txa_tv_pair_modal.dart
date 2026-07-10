import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/txa_theme.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../utils/txa_toast.dart';
import '../services/txa_language.dart';
import '../pages/txa_tv_confirm_screen.dart';

class TxaTvPairModal extends StatefulWidget {
  const TxaTvPairModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const TxaTvPairModal(),
    );
  }

  @override
  State<TxaTvPairModal> createState() => _TxaTvPairModalState();
}

class _TxaTvPairModalState extends State<TxaTvPairModal> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Clear error on new input
      if (_errorMessage != null) {
        setState(() {
          _errorMessage = null;
        });
      }

      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submitPairCode();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _submitPairCode() async {
    final digits = _controllers.map((c) => c.text.trim()).join();
    if (digits.length < 4) {
      setState(() {
        _errorMessage = TxaLanguage.t('tv_pair_code_invalid');
      });
      return;
    }

    final fullCode = 'TXTV$digits';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = TxaAuthService().token;
      if (token == null) {
        setState(() {
          _errorMessage = TxaLanguage.t('login_on_phone_first');
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': 'pair_by_code',
          'pair_code': fullCode,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final sessionId = data?['session_id'] as String?;
          final tvDevice = data?['tv_device'] as Map<String, dynamic>?;

          if (sessionId != null && tvDevice != null && mounted) {
            // Navigate to confirm screen so user explicitly approves the pairing
            Navigator.pop(context); // Close this modal first
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => TxaTvConfirmScreen(
                  sessionId: sessionId,
                  tvDevice: tvDevice,
                ),
              ),
            );
          } else if (mounted) {
            // Fallback: if no session data returned, just show success
            Navigator.pop(context);
            TxaToast.show(context, TxaLanguage.t('tv_paired_success'));
          }
          return;
        } else {
          setState(() {
            _errorMessage = body['message'] ?? TxaLanguage.t('tv_pair_code_incorrect');
          });
        }
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _errorMessage = body['message'] ?? TxaLanguage.t('tv_pair_code_expired_msg');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = TxaLanguage.t('server_conn_error_retry');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TxaTheme.secondaryBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tv_rounded, color: TxaTheme.accent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      TxaLanguage.t('tv_login_title_modal'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                )
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            
            Text(
              TxaLanguage.t('tv_login_enter_code_desc'),
              style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Code Inputs: TXTV + [ ][ ][ ][ ]
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Static Prefix Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'TXTV',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 4 Digit Input Fields
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      width: 44,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: TxaTheme.accent, width: 2),
                          ),
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          filled: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    );
                  }),
                )
              ],
            ),
            
            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            ],

            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(TxaLanguage.t('cancel_btn'), style: const TextStyle(color: TxaTheme.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPairCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : Text(TxaLanguage.t('confirm_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
