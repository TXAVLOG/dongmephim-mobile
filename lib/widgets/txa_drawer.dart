import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_version.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../pages/txa_update_history_screen.dart';
import '../services/txa_play_update_service.dart';
import '../features/download/ui/downloaded_films_screen.dart';

import 'package:url_launcher/url_launcher.dart';

class TxaDrawer extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const TxaDrawer({super.key, this.onSelectTab});

  @override
  State<TxaDrawer> createState() => _TxaDrawerState();
}

class _TxaDrawerState extends State<TxaDrawer> {
  bool _checkingUpdate = false;
  String? _discordUrl;
  bool _discordEnable = false;

  @override
  void initState() {
    super.initState();
    _loadDiscordSettings();
  }

  void _loadDiscordSettings() async {
    try {
      final info = await TxaApi().getCheckUpdate();
      if (info != null && mounted) {
        setState(() {
          _discordUrl = info['discord_server_url']?.toString();
          _discordEnable = (info['discord_server_enable'] == true || info['discord_server_enable']?.toString() == 'true');
        });
      }
    } catch (_) {}
  }

  void _checkUpdate() async {
    setState(() => _checkingUpdate = true);

    TxaToast.show(context, TxaLanguage.t('checking_update'));

    try {
      final info = await TxaApi().getCheckUpdate();
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (info != null) {
        final String serverVersion = (info['app_version'] ?? TxaVersion.version).toString().trim();
        if (TxaPlayUpdateService.isVersionLower(TxaVersion.version, serverVersion)) {
          // Có bản cập nhật mới -> hiển thị modal
          TxaPlayUpdateService.showUpdateDialog(context, info, serverVersion);
        } else {
          TxaToast.show(
            context,
            TxaLanguage.t('up_to_date', replace: {'version': TxaVersion.version}),
          );
        }
      } else {
        TxaToast.show(context, TxaLanguage.t('update_error'), isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingUpdate = false);
        TxaToast.show(context, TxaLanguage.t('update_error'), isError: true);
      }
    }
  }

  void _toggleLanguage() async {
    final current = TxaLanguage.currentLang;
    final next = current == 'vi' ? 'en' : 'vi';
    await TxaLanguage.setLang(next);
    if (mounted) {
      TxaToast.show(
        context,
        '${TxaLanguage.t('select_language')}: ${TxaLanguage.t(next == 'vi' ? 'vi_lang' : 'en_lang')}',
      );
    }
  }

  void _showMovieRequestDialog() {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: TxaTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            TxaLanguage.t('login_prompt_title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            TxaLanguage.t('login_prompt_desc'),
            style: const TextStyle(color: TxaTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: TxaTheme.textSecondary),
              child: Text(TxaLanguage.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (widget.onSelectTab != null) {
                  widget.onSelectTab!(4); // Switch to Profile tab
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TxaTheme.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(TxaLanguage.t('login_now')),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final originNameController = TextEditingController();
    final yearController = TextEditingController();
    final linkController = TextEditingController();
    final authorController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmitting = false;
        String? nameError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitRequest() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() {
                  nameError = TxaLanguage.t('enter_film_name');
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                nameError = null;
              });

              try {
                final response = await TxaApi().submitMovieRequest(
                  name: name,
                  originName: originNameController.text.trim(),
                  publishYear: yearController.text.trim(),
                  link: linkController.text.trim(),
                  author: authorController.text.trim(),
                );

                if (response != null && response['success'] == true) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    TxaToast.show(context, TxaLanguage.t('request_success'));
                  }
                } else {
                  if (context.mounted) {
                    setDialogState(() {
                      isSubmitting = false;
                    });
                    final msg = response?['message'] ?? TxaLanguage.t('request_failed');
                    TxaToast.show(context, msg, isError: true);
                  }
                }
              } catch (_) {
                if (context.mounted) {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                  TxaToast.show(context, TxaLanguage.t('request_failed'), isError: true);
                }
              }
            }

            return AlertDialog(
              backgroundColor: TxaTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.movie_filter_rounded, color: TxaTheme.accent, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    TxaLanguage.t('request_movie'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Film Name Field
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (val) {
                          if (nameError != null && val.trim().isNotEmpty) {
                            setDialogState(() => nameError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: TxaLanguage.t('film_name'),
                          labelStyle: TextStyle(color: nameError != null ? Colors.red : TxaTheme.textSecondary, fontSize: 12),
                          errorText: nameError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 10),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: nameError != null ? Colors.red : Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: nameError != null ? Colors.red : TxaTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Origin Name Field
                      TextField(
                        controller: originNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: TxaLanguage.t('original_name'),
                          labelStyle: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: TxaTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Release Year Field
                      TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: TxaLanguage.t('publish_year'),
                          labelStyle: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: TxaTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Link Field
                      TextField(
                        controller: linkController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: TxaLanguage.t('link_phim'),
                          labelStyle: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: TxaTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Author Field
                      TextField(
                        controller: authorController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: TxaLanguage.t('author'),
                          labelStyle: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: TxaTheme.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: TxaTheme.textSecondary),
                  child: Text(TxaLanguage.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(TxaLanguage.t('submit')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaLanguage>(
      builder: (context, lang, child) {
        return Drawer(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: TxaTheme.primaryBg.withValues(alpha: 0.72),
                border: const Border(
                  right: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Drawer Header
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            TxaLanguage.t('app_name'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TxaLanguage.t('app_slogan'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12),

                    // Drawer Items List
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Language Switcher
                          _buildDrawerTile(
                            icon: Icons.translate_rounded,
                            title: TxaLanguage.t('language'),
                            subtitle: TxaLanguage.t(TxaLanguage.currentLang == 'vi' ? 'vi_lang' : 'en_lang'),
                            onTap: _toggleLanguage,
                          ),

                          // Discord Server Button (Conditional)
                          if (_discordEnable && _discordUrl != null && _discordUrl!.isNotEmpty)
                            _buildDrawerTile(
                              customLeading: buildDiscordIcon(),
                              title: TxaLanguage.t('discord_server'),
                              subtitle: TxaLanguage.t('join_discord_server'),
                              onTap: () async {
                                String urlStr = _discordUrl!.trim();
                                if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
                                  urlStr = 'https://$urlStr';
                                }
                                try {
                                  final uri = Uri.parse(urlStr);
                                  bool launched = false;
                                  try {
                                    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } catch (_) {
                                    launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
                                  }
                                  if (!launched && context.mounted) {
                                    TxaToast.show(context, TxaLanguage.t('cannot_open_discord_link'), isError: true);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    TxaToast.show(context, TxaLanguage.t('error_open_link').replaceAll('%error%', '$e'), isError: true);
                                  }
                                }
                              },
                            ),

                          // Movie Request Button
                          _buildDrawerTile(
                            icon: Icons.movie_filter_rounded,
                            title: TxaLanguage.t('request_movie'),
                            subtitle: TxaLanguage.t('request_movie_subtitle'),
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              _showMovieRequestDialog();
                            },
                          ),

                          // Downloaded Movies
                          _buildDrawerTile(
                            icon: Icons.download_done_rounded,
                            title: TxaLanguage.t('downloaded_movies'),
                            subtitle: TxaLanguage.t('offline_mode'),
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const DownloadedFilmsScreen(),
                                ),
                              );
                            },
                          ),

                          // Check Update
                          _buildDrawerTile(
                            icon: Icons.system_update_rounded,
                            title: TxaLanguage.t('check_update'),
                            subtitle: _checkingUpdate ? 'Loading...' : TxaLanguage.t('check_update_subtitle'),
                            onTap: _checkUpdate,
                          ),

                          // Version Timeline Trigger
                          _buildDrawerTile(
                            icon: Icons.history_rounded,
                            title: TxaLanguage.t('update_history'),
                            subtitle: TxaLanguage.t('current_version', replace: {'version': TxaVersion.version}),
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const UpdateHistoryScreen(),
                                ),
                              );
                            },
                          ),

                          // TV Emulation (Desktop Only)
                          if (TxaPlatform.isDesktop)
                            _buildDrawerTile(
                              icon: Icons.tv_rounded,
                              title: TxaLanguage.t('tv_smarttv_enable'),
                              subtitle: TxaLanguage.t('tv_smarttv_desc'),
                              onTap: () {
                                Navigator.pop(context); // Close Drawer
                                TxaPlatform.tvEmulationNotifier.value = true;
                                TxaToast.show(context, TxaLanguage.t('tv_smarttv_enable'));
                              },
                            ),
                        ],
                      ),
                    ),

                    // Footer Version Label
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        '© 2026 DongMePhim Mobile • v${TxaVersion.version}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerTile({
    IconData? icon,
    Widget? customLeading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white.withValues(alpha: 0.03),
          child: ListTile(
            onTap: onTap,
            leading: customLeading ?? (icon != null ? Icon(icon, color: TxaTheme.accent, size: 22) : null),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
          ),
        ),
      ),
    );
  }
}

Widget buildDiscordIcon({double size = 22}) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: DiscordIconPainter(),
    ),
  );
}

class DiscordIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5865F2)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    path.moveTo(w * 0.86, h * 0.13);
    path.cubicTo(w * 0.77, h * 0.08, w * 0.67, h * 0.05, w * 0.57, h * 0.03);
    path.lineTo(w * 0.56, h * 0.06);
    path.cubicTo(w * 0.67, h * 0.09, w * 0.78, h * 0.14, w * 0.87, h * 0.22);
    path.cubicTo(w * 0.77, h * 0.71, w * 0.59, h * 0.89, w * 0.51, h * 0.96);
    path.lineTo(w * 0.49, h * 0.96);
    path.cubicTo(w * 0.41, h * 0.89, w * 0.23, h * 0.71, w * 0.13, h * 0.22);
    path.cubicTo(w * 0.22, h * 0.14, w * 0.33, h * 0.09, w * 0.44, h * 0.06);
    path.lineTo(w * 0.43, h * 0.03);
    path.cubicTo(w * 0.33, h * 0.05, w * 0.23, h * 0.08, w * 0.14, h * 0.13);
    path.cubicTo(w * 0.03, h * 0.38, -0.02, h * 0.63, 0.01, h * 0.88);
    path.cubicTo(w * 0.12, h * 0.96, w * 0.27, h * 1.0, w * 0.38, h * 1.0);
    path.lineTo(w * 0.41, h * 0.93);
    path.cubicTo(w * 0.34, h * 0.91, w * 0.27, h * 0.87, w * 0.21, h * 0.82);
    path.lineTo(w * 0.23, h * 0.8);
    path.cubicTo(w * 0.41, h * 0.89, w * 0.59, h * 0.89, w * 0.77, h * 0.8);
    path.lineTo(w * 0.79, h * 0.82);
    path.cubicTo(w * 0.73, h * 0.87, w * 0.66, h * 0.91, w * 0.59, h * 0.93);
    path.lineTo(w * 0.62, h * 1.0);
    path.cubicTo(w * 0.73, h * 1.0, w * 0.88, h * 0.96, w * 0.99, h * 0.88);
    path.cubicTo(w * 1.02, h * 0.63, w * 0.97, h * 0.38, w * 0.86, h * 0.13);
    
    final eyeLeft = Path()
      ..addOval(Rect.fromLTWH(w * 0.28, h * 0.42, w * 0.14, h * 0.14));
    final eyeRight = Path()
      ..addOval(Rect.fromLTWH(w * 0.58, h * 0.42, w * 0.14, h * 0.14));
      
    canvas.drawPath(path, paint);
    
    final eyePaint = Paint()
      ..color = const Color(0xFF1E1E2C)
      ..style = PaintingStyle.fill;
    canvas.drawPath(eyeLeft, eyePaint);
    canvas.drawPath(eyeRight, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
