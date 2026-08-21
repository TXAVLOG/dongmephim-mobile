import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_language.dart';
import '../services/txa_version.dart';
import '../services/txa_play_update_service.dart';
import '../utils/txa_platform.dart';
import '../tv/widgets/tv_focusable_card.dart';

class TxaForceUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  final String minVersion;

  const TxaForceUpdateScreen({
    super.key,
    required this.updateInfo,
    required this.minVersion,
  });

  @override
  State<TxaForceUpdateScreen> createState() => _TxaForceUpdateScreenState();
}

class _TxaForceUpdateScreenState extends State<TxaForceUpdateScreen> {
  final FocusNode _updateFocusNode = FocusNode();
  final FocusNode _exitFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (TxaPlatform.isTV) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _updateFocusNode.dispose();
    _exitFocusNode.dispose();
    super.dispose();
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
    final latestVersion = (widget.updateInfo['latest_version'] ?? widget.updateInfo['app_version'] ?? widget.minVersion).toString().trim();
    final changelog = (widget.updateInfo['changelog'] ?? widget.updateInfo['app_release_notes'] ?? '').toString().trim();

    final title = TxaLanguage.t('force_update_title').isNotEmpty
        ? TxaLanguage.t('force_update_title')
        : 'Yêu cầu cập nhật ứng dụng';
    final desc = TxaLanguage.t('force_update_desc')
        .replaceAll('%current%', TxaVersion.version)
        .replaceAll('%latest%', latestVersion);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Stack(
          children: [
            // Background ambient glow
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.0,
                    colors: [
                      Color(0x33737DFD), // Primary accent glow
                      Color(0x0009090B),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13131A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF737DFD).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF737DFD).withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rocket / Update Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF737DFD), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF737DFD).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Version Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF737DFD).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF737DFD).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  const Text(
                                    'v${TxaVersion.version}',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Color(0xFF737DFD), size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  'v$latestVersion',
                                  style: const TextStyle(
                                    color: Color(0xFF737DFD),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          Text(
                            desc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Changelog Box if present
                          if (changelog.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 140),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF09090B).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12, width: 0.5),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  changelog,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Action Buttons
                          if (TxaPlatform.isTV) ...[
                            TvFocusableCard(
                              focusNode: _updateFocusNode,
                              onTap: () => TxaPlayUpdateService.handleMultiplatformUpdate(
                                context,
                                widget.updateInfo,
                                latestVersion,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF737DFD),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    TxaLanguage.t('force_update_btn'),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TvFocusableCard(
                              focusNode: _exitFocusNode,
                              onTap: _exitApp,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    TxaLanguage.t('force_update_exit'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF737DFD),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => TxaPlayUpdateService.handleMultiplatformUpdate(
                                  context,
                                  widget.updateInfo,
                                  latestVersion,
                                ),
                                child: Text(
                                  TxaLanguage.t('force_update_btn'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _exitApp,
                              child: Text(
                                TxaLanguage.t('force_update_exit'),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
