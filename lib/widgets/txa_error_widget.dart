import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_device_info.dart';
import '../main.dart';

class TxaErrorWidget extends StatelessWidget {
  final FlutterErrorDetails? errorDetails;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenOffline;

  const TxaErrorWidget({
    super.key,
    this.errorDetails,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.onOpenOffline,
  });

  String get _errorString {
    if (errorDetails != null) {
      return '${errorDetails!.exceptionAsString()}\n\n${errorDetails!.stack}';
    }
    if (error != null) {
      return '$error\n\n${stackTrace ?? ''}';
    }
    return 'Lỗi không xác định / Unknown Exception';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If rendered inside a tiny/constrained area (e.g. ad container or small card), render a safe compact fallback
        if (constraints.maxHeight < 220 || constraints.maxWidth < 260) {
          return _buildCompactError(context);
        }
        return _buildFullScreenError(context);
      },
    );
  }

  Widget _buildCompactError(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  TxaLanguage.t('app_crash_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRetry,
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenError(BuildContext context) {
    return Material(
      color: TxaTheme.primaryBg,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // Warning Glass Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: Colors.redAccent,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                TxaLanguage.t('app_crash_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle Description
              Text(
                TxaLanguage.t('app_crash_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Scrollable Error Details Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141724),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText(
                        _errorString,
                        style: const TextStyle(
                          color: Color(0xFFFF8A8A),
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Buttons Action Bar
              Column(
                children: [
                  Row(
                    children: [
                      // Share Log Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await TxaLogger.shareLogs('crash');
                          },
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: Text(
                            TxaLanguage.t('app_crash_share_log'),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TxaTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Copy Error Details Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final header = await TxaDeviceInfo.getFormattedHeader(
                              logType: 'CRASH',
                              timestamp: DateTime.now().toString().split('.').first,
                              status: 'FAILED / APP CRASH',
                            );
                            final fullText = '''$header
• Chi Tiết Lỗi / Traceback:
$_errorString
=========================================
''';
                            await Clipboard.setData(ClipboardData(text: fullText));
                            if (context.mounted) {
                              TxaToast.show(context, TxaLanguage.t('app_crash_copied'));
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(
                            TxaLanguage.t('app_crash_copy_details'),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (onOpenOffline != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onOpenOffline,
                        icon: const Icon(Icons.download_for_offline_rounded, size: 20, color: Colors.black),
                        label: Text(
                          TxaLanguage.t('watch_offline_btn'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TxaTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Restart App / Retry Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (onRetry != null) {
                          onRetry!.call();
                        } else {
                          navigatorKey.currentState?.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (ctx) => const MainEntry()),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        TxaLanguage.t('app_crash_restart_app'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
