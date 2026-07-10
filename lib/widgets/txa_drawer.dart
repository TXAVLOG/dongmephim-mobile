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
import '../utils/txa_rich_text.dart';
import '../pages/txa_update_history_screen.dart';

class TxaDrawer extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  const TxaDrawer({super.key, this.onSelectTab});

  @override
  State<TxaDrawer> createState() => _TxaDrawerState();
}

class _TxaDrawerState extends State<TxaDrawer> {
  bool _checkingUpdate = false;

  void _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    TxaToast.show(context, TxaLanguage.t('checking_update'));

    try {
      final info = await TxaApi().getCheckUpdate();
      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (info != null) {
        final String serverVersion = info['app_version'] ?? TxaVersion.version;
        if (serverVersion != TxaVersion.version) {
          // New update available
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          TxaTheme.secondaryBg.withValues(alpha: 0.95),
                          TxaTheme.cardBg.withValues(alpha: 0.92),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: TxaTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.system_update_rounded, color: TxaTheme.accent, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TxaLanguage.t('update_available'),
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'v${TxaVersion.version} → v$serverVersion',
                                    style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 12),

                        // Changelog title
                        Text(
                          TxaLanguage.t('whats_new'),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Changelog content with markdown/HTML support
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: TxaRichTextParser.parse(
                                (info['app_release_notes'] ?? '').toString(),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  TxaLanguage.t('later'),
                                  style: const TextStyle(color: TxaTheme.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  TxaToast.show(context, 'Downloading update...');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TxaTheme.accent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(TxaLanguage.t('update_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
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

                          // Movie Request Button
                          _buildDrawerTile(
                            icon: Icons.movie_filter_rounded,
                            title: TxaLanguage.t('request_movie'),
                            subtitle: TxaLanguage.currentLang == 'vi' ? 'Yêu cầu phim bạn muốn xem' : 'Request a movie you want to watch',
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              _showMovieRequestDialog();
                            },
                          ),

                          // Check Update
                          _buildDrawerTile(
                            icon: Icons.system_update_rounded,
                            title: TxaLanguage.t('check_update'),
                            subtitle: _checkingUpdate ? 'Loading...' : 'Kiểm tra phiên bản mới',
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
    required IconData icon,
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
            leading: Icon(icon, color: TxaTheme.accent, size: 22),
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
