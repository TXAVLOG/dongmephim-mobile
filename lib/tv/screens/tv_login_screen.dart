import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/txa_language.dart';
import '../../utils/txa_toast.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import '../services/tv_pairing_service.dart';
import 'tv_home_screen.dart';

class TvLoginScreen extends StatefulWidget {
  const TvLoginScreen({super.key});

  @override
  State<TvLoginScreen> createState() => _TvLoginScreenState();
}

class _TvLoginScreenState extends State<TvLoginScreen> {
  // Session variables
  String? _pairCode;
  String? _qrPayload;
  String _sessionStatus = 'pending';
  
  Map<String, dynamic>? _scannedUserInfo;

  // Timers
  Timer? _countdownTimer;
  int _timeLeft = 30; // 30s countdown for QR as requested
  int _codeTimeLeft = 600; // 10 minutes for Code

  // Focus nodes
  late FocusNode _refreshCodeNode;
  late FocusNode _refreshQrNode;
  late FocusNode _skipNode;

  @override
  void initState() {
    super.initState();
    _refreshCodeNode = TvFocusSystem.getNode('login_refresh_code');
    _refreshQrNode = TvFocusSystem.getNode('login_refresh_qr');
    _skipNode = TvFocusSystem.getNode('login_skip');

    // Automatically generate pairing codes on open
    _generatePairingData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    TvPairingService().stopPolling();
    super.dispose();
  }

  void _generatePairingData() async {
    TvPairingService().stopPolling();
    _countdownTimer?.cancel();

    setState(() {
      _pairCode = null;
      _qrPayload = null;
      _sessionStatus = 'pending';
      _scannedUserInfo = null;
      _timeLeft = 30;
      _codeTimeLeft = 600;
    });

    String? codeSessionId;
    String? qrSessionId;

    // 1. Generate pairing Code
    final codeData = await TvPairingService().generateCode();
    if (codeData != null && mounted) {
      setState(() {
        _pairCode = codeData['pair_code'];
        codeSessionId = codeData['session_id'];
      });
    }

    // 2. Generate QR session
    final qrData = await TvPairingService().generateQr();
    if (qrData != null && mounted) {
      setState(() {
        qrSessionId = qrData['session_id'];
        _qrPayload = qrData['qr_payload'];
      });
    }

    // Start polling status of active sessions
    final sessionsToPoll = <String>[];
    if (codeSessionId != null) sessionsToPoll.add(codeSessionId!);
    if (qrSessionId != null) sessionsToPoll.add(qrSessionId!);

    if (sessionsToPoll.isNotEmpty) {
      TvPairingService().startPolling(
        sessionIds: sessionsToPoll,
        onUpdate: (session) {
          if (!mounted) return;
          setState(() {
            if (session['status'] == 'confirmed' || session['status'] == 'waiting_confirm') {
              _sessionStatus = session['status'];
              _scannedUserInfo = session['user_info'];
            }
          });
        },
        onConfirmed: () {
          if (!mounted) return;
          TxaToast.show(context, TxaLanguage.t('tv_login_success'));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TvHomeScreen()),
          );
        },
        onFailed: (reason) {
          if (!mounted) return;
          TxaToast.show(context, reason, isError: true);
          // Regenerate
          _generatePairingData();
        },
      );
    }

    // Start 1-second interval countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0 && _sessionStatus == 'pending') {
          _timeLeft--;
        }
        if (_codeTimeLeft > 0) {
          _codeTimeLeft--;
        }
      });

      if (_timeLeft == 0 && _codeTimeLeft == 0 && _sessionStatus == 'pending') {
        TvPairingService().stopPolling();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQrExpired = _timeLeft == 0 && _sessionStatus == 'pending';
    final hasCodeExpired = _codeTimeLeft == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TV App Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.movie_filter_rounded, color: Color(0xFF737DFD), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'DongMePhim TV',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    TxaLanguage.t('app_slogan'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Split Layout: Code vs QR
              Expanded(
                child: Row(
                  children: [
                    // LEFT HALF: Code Pairing
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phonelink_setup_rounded, color: Color(0xFF737DFD), size: 40),
                            const SizedBox(height: 10),
                            Text(
                              TxaLanguage.t('tv_code_login_title'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            
                            // Pairing Code display box
                            if (_pairCode == null)
                              const CircularProgressIndicator(color: Color(0xFF737DFD))
                            else if (hasCodeExpired) ...[
                              Text(TxaLanguage.t('tv_code_expired'), style: const TextStyle(color: Colors.redAccent)),
                              const SizedBox(height: 12),
                              TvFocusableCard(
                                focusNode: _refreshCodeNode,
                                onTap: _generatePairingData,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  color: const Color(0xFF737DFD),
                                  child: Text(TxaLanguage.t('tv_get_new_code'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF737DFD).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  _pairCode!,
                                  style: const TextStyle(
                                    color: Color(0xFF737DFD),
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                TxaLanguage.t('tv_expired_after', replace: {
                                  'time': '${(_codeTimeLeft ~/ 60).toString().padLeft(2, '0')}:${(_codeTimeLeft % 60).toString().padLeft(2, '0')}'
                                }),
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            
                            // Instructions
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(TxaLanguage.t('tv_instructions'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(TxaLanguage.t('tv_code_instruction_1'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                Text(TxaLanguage.t('tv_code_instruction_2'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                Text(TxaLanguage.t('tv_code_instruction_3'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),

                    // RIGHT HALF: QR Pairing
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFA855F7), size: 40),
                            const SizedBox(height: 10),
                            Text(
                              TxaLanguage.t('tv_scan_qr_title'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            // QR Image Container with Blur & Scanned UI
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // QR Code itself
                                  if (_qrPayload != null)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: QrImageView(
                                        data: _qrPayload!,
                                        version: QrVersions.auto,
                                        size: 120.0,
                                        embeddedImage: const AssetImage('assets/logo.png'),
                                        embeddedImageStyle: const QrEmbeddedImageStyle(
                                          size: Size(24, 24),
                                        ),
                                      ),
                                    )
                                  else
                                    const CircularProgressIndicator(color: Color(0xFFA855F7)),

                                  // Overlay if waiting confirm (blurs and shows user details)
                                  if (_sessionStatus == 'waiting_confirm')
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.88),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 24),
                                          const SizedBox(height: 8),
                                          Text(
                                            _scannedUserInfo?['name'] ?? 'Tài khoản',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Text(
                                            TxaLanguage.t('tv_waiting_confirm'),
                                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Overlay if QR expired
                                  if (hasQrExpired)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 36),
                                            const SizedBox(height: 8),
                                            Text(
                                              TxaLanguage.t('tv_qr_expired'),
                                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Timer / Countdown
                            if (_sessionStatus == 'pending' && !hasQrExpired)
                              Text(
                                TxaLanguage.t('tv_expired_after', replace: {
                                  'time': '00:${_timeLeft.toString().padLeft(2, '0')}'
                                }),
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                              )
                            else if (hasQrExpired)
                              TvFocusableCard(
                                focusNode: _refreshQrNode,
                                onTap: _generatePairingData,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  color: const Color(0xFFA855F7),
                                  child: Text(TxaLanguage.t('tv_refresh_qr'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),

                            const SizedBox(height: 12),
                            // Instructions
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(TxaLanguage.t('tv_instructions'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(TxaLanguage.t('tv_qr_instruction_1'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                Text(TxaLanguage.t('tv_qr_instruction_2'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                Text(TxaLanguage.t('tv_qr_instruction_3'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Option: Skip Login
              Center(
                child: TvFocusableCard(
                  focusNode: _skipNode,
                  onTap: () {
                    TxaToast.show(context, TxaLanguage.t('tv_guest_mode_msg'));
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const TvHomeScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    color: Colors.white.withValues(alpha: 0.05),
                    child: Text(
                      TxaLanguage.t('tv_skip_login'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
