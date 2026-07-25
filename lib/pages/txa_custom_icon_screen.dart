import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_dynamic_icon_service.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';

class TxaCustomIconScreen extends StatefulWidget {
  const TxaCustomIconScreen({super.key});

  @override
  State<TxaCustomIconScreen> createState() => _TxaCustomIconScreenState();
}

class _TxaCustomIconScreenState extends State<TxaCustomIconScreen> {
  String _activeIconKey = 'icon_default.png';
  String _selectedIconKey = 'icon_default.png';
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadActiveIcon();
  }

  Future<void> _loadActiveIcon() async {
    final active = await TxaDynamicIconService.getActiveIconKey();
    if (mounted) {
      setState(() {
        _activeIconKey = active;
        _selectedIconKey = active;
      });
    }
  }

  bool _hasPermission(Map<String, dynamic>? user) {
    if (user == null) return false;
    if (user['custom_app_icon'] == true || user['allow_custom_icon'] == true) return true;
    final perms = user['permissions'] as Map<String, dynamic>?;
    if (perms != null && (perms['custom_app_icon'] == true || perms['custom_icon'] == true)) {
      return true;
    }
    final pkg = (user['package'] ?? 'free').toString().toLowerCase();
    if (pkg == 'custom_icon' || pkg.contains('icon') || pkg == 'vip' || pkg == 'dongphims') {
      final expiryStr = user['expiry_date'] ?? user['expiryDate'];
      if (expiryStr != null && expiryStr.toString().isNotEmpty) {
        final dt = DateTime.tryParse(expiryStr.toString());
        if (dt != null && dt.isBefore(DateTime.now())) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  Future<void> _applySelectedIcon(bool hasPerm) async {
    if (TxaPlatform.isTV) {
      TxaToast.show(context, TxaLanguage.t('tv_icon_not_supported'), isError: true);
      return;
    }

    if (!hasPerm && _selectedIconKey != 'icon_default.png') {
      TxaToast.show(context, TxaLanguage.t('custom_icon_section_desc_locked'), isError: true);
      return;
    }

    setState(() => _isApplying = true);
    TxaToast.show(context, TxaLanguage.t('applying_icon'));

    final success = await TxaDynamicIconService.setAppIcon(_selectedIconKey);
    if (!mounted) return;
    setState(() => _isApplying = false);

    if (success) {
      setState(() => _activeIconKey = _selectedIconKey);
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: TxaTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              Text(
                TxaLanguage.t('icon_change_success'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            TxaLanguage.t('icon_change_restart_notice'),
            style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TxaTheme.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      TxaToast.show(context, TxaLanguage.t('icon_change_failed'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<TxaAuthService>(context);
    final user = auth.user;
    final hasPerm = _hasPermission(user);

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TxaLanguage.t('all_icons_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (TxaPlatform.isTV)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        TxaLanguage.t('tv_icon_not_supported'),
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                TxaLanguage.t('all_icons_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(18),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: TxaDynamicIconService.availableIcons.length,
                itemBuilder: (context, index) {
                  final item = TxaDynamicIconService.availableIcons[index];
                  final iconKey = item['key']!;
                  final iconName = TxaLanguage.t(item['nameKey']!);
                  final iconDesc = TxaLanguage.t(item['descKey']!);
                  final isCurrentActive = _activeIconKey == iconKey;
                  final isSelected = _selectedIconKey == iconKey;
                  final isLocked = !hasPerm && iconKey != 'icon_default.png';

                  Color themeColor = TxaTheme.accent;
                  try {
                    final hex = item['color']!.replaceAll('#', '');
                    themeColor = Color(int.parse('FF$hex', radix: 16));
                  } catch (_) {}

                  return GestureDetector(
                    onTap: () {
                      if (isLocked) {
                        TxaToast.show(context, TxaLanguage.t('custom_icon_section_desc_locked'), isError: true);
                        return;
                      }
                      setState(() => _selectedIconKey = iconKey);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? themeColor.withValues(alpha: 0.15)
                            : const Color(0xFF161A26),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? themeColor : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    'assets/app_icons/$iconKey',
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                iconName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                iconDesc,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),

                          if (isCurrentActive)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  TxaLanguage.t('active_icon_badge'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            )
                          else if (isLocked)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Apply Action Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isApplying || TxaPlatform.isTV)
                      ? null
                      : () => _applySelectedIcon(hasPerm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isApplying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(
                          TxaLanguage.t('apply_icon_btn'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
