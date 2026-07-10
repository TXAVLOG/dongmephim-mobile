import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/txa_api.dart';
import '../../services/txa_auth_service.dart';
import '../../services/txa_language.dart';
import '../../tv/services/tv_pairing_service.dart';
import '../../utils/txa_toast.dart';
import '../../utils/txa_format.dart';
import '../../utils/txa_platform.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import '../screens/tv_movie_detail_screen.dart';
import '../screens/tv_watch_history_screen.dart';
import '../screens/tv_favorites_screen.dart';

class TvProfileTab extends StatefulWidget {
  const TvProfileTab({super.key});

  @override
  State<TvProfileTab> createState() => _TvProfileTabState();
}

class _TvProfileTabState extends State<TvProfileTab> {
  // Common states
  bool _isLoading = false;
  Map<String, dynamic>? _packagesData;
  List<dynamic> _history = [];
  List<dynamic> _favorites = [];

  // Guest Mode Pairing variables
  String? _pairCode;
  String? _qrPayload;
  String? _activeSessionId;
  String _sessionStatus = 'pending';
  Map<String, dynamic>? _scannedUserInfo;
  Timer? _countdownTimer;
  int _timeLeft = 30;
  int _codeTimeLeft = 600;

  @override
  void initState() {
    super.initState();
    final auth = TxaAuthService();
    _startCountdownTimer();
    if (auth.isLoggedIn) {
      _loadProfileData();
    } else {
      _generateCodeData();
      _generateQrData(silent: true);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    TvPairingService().stopPolling();
    super.dispose();
  }

  // --- Logged In Mode Data Load ---
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final favsRes = await TxaApi().getFavorites(limit: 10);
      final historyRes = await TxaApi().getWatchHistory();
      final packagesRes = await TxaApi().getPackages();

      if (mounted) {
        setState(() {
          _favorites = favsRes?['data'] as List<dynamic>? ?? [];
          _history = historyRes;
          _packagesData = packagesRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading TV profile data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Guest Mode Pairing Logic ---
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
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

      if (_timeLeft == 0 && _sessionStatus == 'pending') {
        TvPairingService().stopPolling();
      }
    });
  }

  void _generateCodeData() async {
    if (mounted) {
      setState(() {
        _pairCode = null;
        _codeTimeLeft = 600;
      });
    }
    final codeData = await TvPairingService().generateCode();
    if (codeData != null && mounted) {
      setState(() {
        _pairCode = codeData['pair_code'];
      });
    }
  }

  void _generateQrData({bool silent = false}) async {
    TvPairingService().stopPolling();
    if (mounted) {
      setState(() {
        _qrPayload = null;
        _activeSessionId = null;
        _sessionStatus = 'pending';
        _scannedUserInfo = null;
        _timeLeft = 30;
      });
    }

    final qrData = await TvPairingService().generateQr();
    if (qrData != null && mounted) {
      setState(() {
        _activeSessionId = qrData['session_id'];
        _qrPayload = qrData['qr_payload'];
      });

      if (_activeSessionId != null) {
        TvPairingService().startPolling(
          sessionIds: [_activeSessionId!],
          onUpdate: (session) {
            if (!mounted) return;
            setState(() {
              _sessionStatus = session['status'];
              if (_sessionStatus == 'waiting_confirm') {
                _scannedUserInfo = session['user_info'];
              }
            });
          },
          onConfirmed: () async {
            if (!mounted) return;
            TxaToast.show(context, TxaLanguage.t('tv_login_success'));
            await TxaAuthService().initialize();
            if (mounted) {
              _loadProfileData();
            }
          },
          onFailed: (reason) {
            if (!mounted) return;
            if (!silent && !reason.contains('hết hạn') && !reason.contains('expired')) {
              TxaToast.show(context, reason, isError: true);
            }
            _generateQrData(silent: true);
          },
        );
      }
    }
  }



  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF737DFD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaAuthService>(
      builder: (context, auth, child) {
        if (!auth.isLoggedIn) {
          return _buildGuestMode();
        }

        if (_isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF737DFD)),
          );
        }

        return _buildUserDashboard(auth.user!);
      },
    );
  }

  // --- BUILD GUEST MODE (QR & Code login within profile tab) ---
  Widget _buildGuestMode() {
    final hasQrExpired = _timeLeft == 0 && _sessionStatus == 'pending';
    final hasCodeExpired = _codeTimeLeft == 0;

    return Row(
      children: [
        // Left Half: Code Link
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phonelink_setup_rounded, color: Color(0xFF737DFD), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    TxaLanguage.t('tv_code_login_title'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_pairCode == null)
                    const CircularProgressIndicator(color: Color(0xFF737DFD))
                  else if (hasCodeExpired) ...[
                    Text(TxaLanguage.t('tv_code_expired'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    const SizedBox(height: 12),
                    TvFocusableCard(
                      focusNode: TvFocusSystem.getNode('profile_refresh_code'),
                      onTap: _generateCodeData,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFF737DFD),
                        child: Text(TxaLanguage.t('tv_get_new_code'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF737DFD).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _pairCode!,
                        style: const TextStyle(
                          color: Color(0xFF737DFD),
                          fontSize: 28,
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
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  
                  // Instructions (smaller font to fit space)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(TxaLanguage.t('tv_instructions'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(TxaLanguage.t('tv_code_instruction_1'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text(TxaLanguage.t('tv_code_instruction_2'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text(TxaLanguage.t('tv_code_instruction_3'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Right Half: QR Code Link
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFA855F7), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    TxaLanguage.t('tv_scan_qr_title'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // QR Image Container (Reduced sizes to prevent overflows)
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_qrPayload != null)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: QrImageView(
                              data: _qrPayload!,
                              version: QrVersions.auto,
                              size: 118.0,
                            ),
                          )
                        else
                          const CircularProgressIndicator(color: Color(0xFFA855F7)),

                        if (_sessionStatus == 'waiting_confirm')
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  _scannedUserInfo?['name'] ?? 'Tài khoản',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                Text(
                                  TxaLanguage.t('tv_waiting_confirm'),
                                  style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                        if (hasQrExpired)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    TxaLanguage.t('tv_qr_expired'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_sessionStatus == 'pending' && !hasQrExpired)
                    Text(
                      TxaLanguage.t('tv_expired_after', replace: {
                        'time': '00:${_timeLeft.toString().padLeft(2, '0')}'
                      }),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  else if (hasQrExpired)
                    TvFocusableCard(
                      focusNode: TvFocusSystem.getNode('profile_refresh_qr'),
                      onTap: () => _generateQrData(silent: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFFA855F7),
                        child: Text(TxaLanguage.t('tv_refresh_qr'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),

                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(TxaLanguage.t('tv_instructions'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(TxaLanguage.t('tv_qr_instruction_1'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text(TxaLanguage.t('tv_qr_instruction_2'), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- BUILD USER DASHBOARD (Logged-in profile data shelves) ---
  Widget _buildUserDashboard(Map<String, dynamic> user) {
    // 1. Resolve Package styling parameters
    final userPkgId = (user['package'] ?? 'free').toString().toLowerCase();
    final packages = _packagesData?['packages'] as List<dynamic>? ?? [];
    final pkgInfo = packages.firstWhere(
      (p) => p['id'].toString().toLowerCase() == userPkgId,
      orElse: () => {
        'id': userPkgId,
        'title': userPkgId.toUpperCase(),
        'style_type': 'default',
      },
    );

    final pkgTitle = pkgInfo['title'] ?? userPkgId.toUpperCase();
    final styleType = pkgInfo['style_type'] ?? 'default';
    final customColorStr = pkgInfo['custom_color'] ?? '';
    final isPremium = userPkgId != 'free';

    Color packageColor = const Color(0xFF737DFD);
    bool isRainbow = styleType == 'rainbow_effect';

    if (styleType == 'custom_color' && customColorStr.isNotEmpty) {
      packageColor = _parseHexColor(customColorStr);
    } else if (isRainbow) {
      packageColor = Colors.amber; // fallback for non-gradient widgets
    } else if (!isPremium) {
      packageColor = const Color(0xFF94A3B8); // Gray/Slate for free
    }

    final name = user['name'] ?? user['username'] ?? 'DongMePhim Fan';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    
    // Format package remaining duration
    final expiryStr = user['package_expiry'] ?? user['expiry_date'] ?? '';
    final formattedTimeRemaining = expiryStr.isNotEmpty
        ? TxaFormat.formatRemainingTimeStr(expiryStr)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Profile info, membership status, exit emulation, language switcher, logout
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. VIP Card with Dynamic Styling
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF111827).withValues(alpha: 0.8),
                    border: Border.all(
                      color: isRainbow ? Colors.transparent : packageColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isRainbow)
                        BoxShadow(
                          color: const Color(0xFF7928CA).withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 1,
                        )
                      else
                        BoxShadow(
                          color: packageColor.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                    ],
                    gradient: isRainbow
                        ? const SweepGradient(
                            colors: [
                              Color(0xFFFF007F),
                              Color(0xFF7928CA),
                              Color(0xFF737DFD),
                              Color(0xFF00F2FE),
                              Color(0xFF4FACFE),
                              Color(0xFFF9B16E),
                              Color(0xFFFF007F),
                            ],
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Avatar with customized border
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isRainbow ? Colors.white : packageColor,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: packageColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF0C0D14),
                          child: Text(
                            initials,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // User texts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pkgTitle.toUpperCase(),
                              style: TextStyle(
                                color: isRainbow ? Colors.white : packageColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (formattedTimeRemaining != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${TxaLanguage.t('vip_remaining')}: $formattedTimeRemaining',
                                style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${TxaLanguage.t('vip_expiry_date')}: ${TxaFormat.formatDateTime(expiryStr)}',
                                style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Language Switcher Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0, bottom: 8.0),
                        child: Text(
                          TxaLanguage.t('tv_menu_profile').toUpperCase(),
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      
                      // Cài đặt ngôn ngữ buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TvFocusableCard(
                                focusNode: TvFocusSystem.getNode('lang_vi_btn'),
                                onTap: () {
                                  TxaLanguage.setLang('vi');
                                  TxaToast.show(context, TxaLanguage.t('switched_to_vi'));
                                  setState(() {});
                                },
                                scaleOnFocus: 1.05,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  color: TxaLanguage.currentLang == 'vi'
                                      ? const Color(0xFF737DFD).withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  child: const Center(
                                    child: Text(
                                      'Tiếng Việt',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TvFocusableCard(
                                focusNode: TvFocusSystem.getNode('lang_en_btn'),
                                onTap: () {
                                  TxaLanguage.setLang('en');
                                  TxaToast.show(context, TxaLanguage.t('switched_to_en'));
                                  setState(() {});
                                },
                                scaleOnFocus: 1.05,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  color: TxaLanguage.currentLang == 'en'
                                      ? const Color(0xFF737DFD).withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  child: const Center(
                                    child: Text(
                                      'English',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. App Version Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0, bottom: 8.0),
                        child: Text(
                          TxaLanguage.t('tv_app_version').toUpperCase(),
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF737DFD), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'v${TxaApi.appVersion}',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.devices_rounded, color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              TxaPlatform.isTV ? 'Android TV / Smart TV' : (TxaPlatform.isDesktop ? 'Desktop (TV Emulation)' : 'Mobile'),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Desktop Exit Emulation button
                if (TxaPlatform.isDesktop) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TvFocusableCard(
                      focusNode: TvFocusSystem.getNode('tv_exit_emulation_btn'),
                      onTap: () {
                        TxaPlatform.tvEmulationNotifier.value = false;
                        TxaToast.show(context, TxaLanguage.t('exit_tv_emulator'));
                      },
                      scaleOnFocus: 1.05,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            TxaLanguage.t('tv_exit_emulation'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // RIGHT COLUMN: Watch History & Favorites lists
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWatchHistoryShelf(),
                const SizedBox(height: 16),
                _buildFavoritesShelf(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWatchHistoryShelf() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('tv_shelf_history'),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TvFocusableCard(
                focusNode: TvFocusSystem.getNode('tv_profile_history_see_all'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const TvWatchHistoryScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TxaLanguage.t('see_all'), style: const TextStyle(color: Color(0xFF737DFD), fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF737DFD), size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final name = item['movie_name'] ?? '';
              final epName = item['episode_name'] ?? '';
              final thumbUrl = item['movie_thumb'] ?? '';
              final double currentTime = (item['current_time'] as num? ?? 0.0).toDouble();
              final double duration = (item['duration'] as num? ?? 1.0).toDouble();
              final double progressPercent = duration > 0 ? (currentTime / duration).clamp(0.0, 1.0) : 0.0;
              final node = TvFocusSystem.getNode('tv_profile_history_$index');

              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TvFocusableCard(
                  focusNode: node,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => TvMovieDetailScreen(slug: item['movie_slug'] ?? ''),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Poster
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: Colors.white12),
                          errorWidget: (c, u, e) => Container(color: Colors.white10),
                        ),
                      ),
                      
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black87, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),

                      // Text Info
                      Positioned(
                        bottom: 12,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              epName,
                              style: const TextStyle(color: Color(0xFF737DFD), fontSize: 8, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Progress Bar overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 4,
                        child: Container(
                          color: Colors.white24,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progressPercent,
                              child: Container(
                                color: const Color(0xFF737DFD),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesShelf() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('tv_shelf_favorites'),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (_favorites.isNotEmpty)
                TvFocusableCard(
                  focusNode: TvFocusSystem.getNode('tv_profile_fav_see_all'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const TvFavoritesScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(TxaLanguage.t('see_all'), style: const TextStyle(color: Color(0xFF737DFD), fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF737DFD), size: 10),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        if (_favorites.isEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  TxaLanguage.t('tv_no_favorites'),
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TvFocusableCard(
                  focusNode: TvFocusSystem.getNode('tv_profile_explore_btn'),
                  onTap: () {
                    TxaToast.show(context, TxaLanguage.t('tv_explore_hint'));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: const Color(0xFF737DFD).withValues(alpha: 0.2),
                    child: Text(TxaLanguage.t('tv_explore_now'), style: const TextStyle(color: Color(0xFF737DFD), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final movie = _favorites[index];
                final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
                final name = movie['name'] ?? '';
                final node = TvFocusSystem.getNode('tv_profile_fav_$index');

                return Container(
                  width: 110,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TvFocusableCard(
                    focusNode: node,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            width: 110,
                            placeholder: (c, u) => Container(color: Colors.white12),
                            errorWidget: (c, u, e) => Container(color: Colors.white10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
