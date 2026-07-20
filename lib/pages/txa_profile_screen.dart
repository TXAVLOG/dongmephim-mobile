import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../services/txa_favorite_manager.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import '../utils/txa_platform.dart';
import '../widgets/txa_tv_pair_modal.dart';
import 'txa_movie_detail_screen.dart';
import 'txa_qr_scan_screen.dart';
import 'txa_favorites_list_screen.dart';
import 'txa_watch_history_screen.dart';
import 'txa_payment_history_screen.dart';

class TxaProfileScreen extends StatefulWidget {
  const TxaProfileScreen({super.key});

  @override
  State<TxaProfileScreen> createState() => _TxaProfileScreenState();
}

class _TxaProfileScreenState extends State<TxaProfileScreen> {
  // Login Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loginLoading = false;

  // Focus Nodes & Error States
  final _identityFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String? _identityError;
  String? _passwordError;

  // Cache/Data Loading States for Logged In User
  bool _cabinetLoading = true;
  List<dynamic> _favorites = [];
  List<dynamic> _history = [];
  List<dynamic> _payments = [];
  Map<String, dynamic>? _packagesData;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (auth.isLoggedIn) {
      _loadCabinetData();
    }
    TxaFavoriteManager().favorites.addListener(_onFavoritesChanged);

    // Add focus listeners to clear errors on click
    _identityFocusNode.addListener(() {
      if (_identityFocusNode.hasFocus && _identityError != null) {
        setState(() {
          _identityError = null;
        });
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus && _passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    });
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (auth.isLoggedIn) {
      // Reload favorites from API to get fresh data
      _loadCabinetData();
    }
  }

  @override
  void dispose() {
    TxaFavoriteManager().favorites.removeListener(_onFavoritesChanged);
    _identityController.dispose();
    _passwordController.dispose();
    _identityFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCabinetData() async {
    if (!mounted) return;
    setState(() {
      _cabinetLoading = true;
    });
    try {
      final auth = Provider.of<TxaAuthService>(context, listen: false);
      await auth.refreshUser();

      final favsRes = await TxaApi().getFavorites(limit: 15);
      final historyRes = await TxaApi().getWatchHistory();
      final paymentsRes = await TxaApi().getPayments();
      final packagesRes = await TxaApi().getPackages();

      if (mounted) {
        setState(() {
          _favorites = favsRes?['data'] as List<dynamic>? ?? [];
          _history = historyRes;
          _payments = paymentsRes;
          _packagesData = packagesRes;
          _cabinetLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cabinetLoading = false;
        });
        TxaToast.show(context, TxaLanguage.t('error_loading_data'), isError: true);
      }
    }
  }

  Future<void> _handleLogin() async {
    bool hasError = false;
    setState(() {
      if (_identityController.text.trim().isEmpty) {
        _identityError = TxaLanguage.t('error_empty_fields');
        hasError = true;
      } else {
        _identityError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = TxaLanguage.t('error_empty_fields');
        hasError = true;
      } else {
        _passwordError = null;
      }
    });

    if (hasError) return;
    
    setState(() {
      _loginLoading = true;
    });

    final auth = Provider.of<TxaAuthService>(context, listen: false);
    final result = await auth.login(
      _identityController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _loginLoading = false;
      });

      if (result['success'] == true) {
        TxaToast.show(context, TxaLanguage.t('login_success'), isError: false);
        _identityController.clear();
        _passwordController.clear();
        _loadCabinetData();
      } else {
        if (result['isNotVerified'] == true) {
          _showVerificationRequiredDialog(result['message'] ?? '');
        } else {
          final errorMsg = result['message'] ?? TxaLanguage.t('error_login');
          setState(() {
            if (errorMsg.toString().toLowerCase().contains('mật khẩu') ||
                errorMsg.toString().toLowerCase().contains('password')) {
              _passwordError = errorMsg;
            } else {
              _identityError = errorMsg;
            }
          });
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          TxaLanguage.t('logout'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          TxaLanguage.t('logout_confirm'),
          style: const TextStyle(color: TxaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              TxaLanguage.t('ok'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final auth = Provider.of<TxaAuthService>(context, listen: false);
      await auth.logout();
      if (!mounted) return;
      TxaToast.show(context, TxaLanguage.t('logout_success'));
      setState(() {
        _favorites.clear();
        _history.clear();
        _payments.clear();
        _packagesData = null;
      });
    }
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: TxaTheme.accent, size: 28),
            const SizedBox(width: 12),
            Text(
              TxaLanguage.t('register'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          TxaLanguage.t('register_website_msg'),
          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('close'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('${TxaApi.baseUrl}/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (ctx.mounted) {
                  TxaToast.show(ctx, TxaLanguage.t('not_open_link'), isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TxaLanguage.t('go_to_website'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVerificationRequiredDialog(String backendMessage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              TxaLanguage.t('login_verify_required_title'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          TxaLanguage.t('login_verify_required_msg'),
          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(TxaLanguage.t('close'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('${TxaApi.baseUrl}/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (ctx.mounted) {
                  TxaToast.show(ctx, TxaLanguage.t('not_open_link'), isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TxaTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(TxaLanguage.t('go_to_website'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxaTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          TxaLanguage.t('clear'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          TxaLanguage.t('history_clear_confirm'),
          style: const TextStyle(color: TxaTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              TxaLanguage.t('clear'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await TxaApi().clearWatchHistory();
      if (!mounted) return;
      if (success) {
        TxaToast.show(context, TxaLanguage.t('history_cleared'));
        setState(() {
          _history.clear();
        });
      } else {
        TxaToast.show(context, TxaLanguage.t('history_clear_failed'), isError: true);
      }
    }
  }

  void _showVIPUpgradeDialog() async {
    if (_packagesData == null) {
      TxaToast.show(context, TxaLanguage.t('loading_vip_info'), isError: false);
      return;
    }

    final packages = _packagesData!['packages'] as List<dynamic>? ?? [];
    final paymentInfo = _packagesData!['payment'] as Map<String, dynamic>? ?? {};

    if (!mounted) return;

    final auth = Provider.of<TxaAuthService>(context, listen: false);
    final user = auth.user;
    final currentPkg = (user?['package'] ?? 'free').toString().toLowerCase();
    final isFree = currentPkg == 'free' || currentPkg.isEmpty;

    final paidPackages = packages.where((p) => (p['id'] ?? '').toString().toLowerCase() != 'free').toList();
    if (paidPackages.isEmpty) {
      TxaToast.show(context, TxaLanguage.t('no_packages_available'), isError: true);
      return;
    }

    // Default to VIP package if exists
    int selectedPackageIndex = paidPackages.indexWhere((p) =>
        (p['title'] ?? '').toString().toUpperCase().contains('VIP') ||
        (p['id'] ?? '').toString().toUpperCase().contains('VIP'));
    if (selectedPackageIndex == -1) selectedPackageIndex = 0;

    String selectedCycle = 'monthly';
    String selectedPaymentMethod = 'sepay';
    String? appliedPromoCode;
    int? appliedDiscountAmount;
    final promoController = TextEditingController();
    bool isSubmitting = false;

    List<dynamic> activePromos = [];
    try {
      activePromos = await TxaApi().getActivePromos();
    } catch (e) {
      debugPrint('Error loading active promos: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final selectedPkg = paidPackages[selectedPackageIndex];
            final pkgTitle = (selectedPkg['title'] ?? 'VIP').toString();
            
            final features = selectedPkg['features'] as List<dynamic>? ?? [];
            final hasAnnual = selectedPkg['annual_price'] != null;
            final monthlyPrice = (selectedPkg['price'] as int?) ?? 0;
            final annualPrice = hasAnnual ? (selectedPkg['annual_price'] as int) : (monthlyPrice * 12);
            
            final discountPercent = monthlyPrice > 0 
                ? (((monthlyPrice * 12 - annualPrice) / (monthlyPrice * 12)) * 100).round()
                : 0;

            final basePrice = selectedCycle == 'monthly' ? monthlyPrice : annualPrice;
            int discount = 0;
            if (appliedPromoCode != null && appliedDiscountAmount != null) {
              discount = appliedDiscountAmount!;
            }
            final finalPrice = (basePrice - discount).clamp(0, basePrice);

            // Helper to verify and apply promo code
            Future<void> applyPromoCode(String code) async {
              if (code.isEmpty) {
                TxaToast.show(context, TxaLanguage.t('promo_empty_msg'), isError: true);
                return;
              }
              final priceToCheck = selectedCycle == 'monthly' ? monthlyPrice : annualPrice;
              final res = await TxaApi().verifyPromo(
                code,
                selectedPkg['title'] ?? 'VIP',
                user?['username']?.toString() ?? '',
                priceToCheck.toDouble(),
              );
              if (!context.mounted) return;
              if (res != null && res['success'] == true) {
                final promoData = res['data'] as Map<String, dynamic>?;
                if (promoData != null) {
                  setModalState(() {
                    appliedPromoCode = code;
                    final rawDiscount = promoData['discountAmount'];
                    appliedDiscountAmount = rawDiscount is int
                        ? rawDiscount
                        : rawDiscount is num
                            ? rawDiscount.round()
                            : int.tryParse(rawDiscount?.toString() ?? '0') ?? 0;
                  });
                  final discountDisplay = promoData['discountType'] == 'percent'
                      ? '${promoData['discountValue']}%'
                      : NumberFormatCurrency.format(promoData['discountAmount'] ?? 0);
                  TxaToast.show(
                    context,
                    TxaLanguage.t('promo_applied_msg', replace: {
                      'code': code,
                      'discount': discountDisplay,
                    }),
                    isError: false,
                  );
                }
              } else {
                TxaToast.show(context, res?['message']?.toString() ?? TxaLanguage.t('promo_invalid_msg'), isError: true);
              }
            }

            // Filter promos matching this package scope
            final pkgIdSelected = selectedPkg['id']?.toString().toLowerCase() ?? '';
            final pkgPromos = activePromos.where((p) {
              final scope = (p['package_scope'] ?? 'all').toString().toLowerCase();
              return scope == 'all' ||
                  pkgTitle.toLowerCase().contains(scope) ||
                  pkgIdSelected.contains(scope) ||
                  scope.contains(pkgTitle.toLowerCase()) ||
                  scope.contains(pkgIdSelected);
            }).toList();

            final isCurrentPkg = !isFree && (pkgIdSelected == currentPkg || pkgTitle.toLowerCase() == currentPkg);

            final buttonText = isCurrentPkg
                ? TxaLanguage.t('renew_action', replace: {'pkg': pkgTitle})
                : TxaLanguage.t('upgrade_action', replace: {'pkg': pkgTitle});

            return Container(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F111E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close and title bar
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          Text(
                            TxaLanguage.t('upgrade_vip_title'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Package Selector Tabs
                            if (paidPackages.length > 1) ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(paidPackages.length, (idx) {
                                    final p = paidPackages[idx];
                                    final title = p['title'] ?? 'VIP';
                                    final isSelected = selectedPackageIndex == idx;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(
                                          title,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        selected: isSelected,
                                        onSelected: (val) {
                                          if (val) {
                                            setModalState(() {
                                              selectedPackageIndex = idx;
                                              appliedPromoCode = null;
                                              appliedDiscountAmount = null;
                                              promoController.clear();
                                              if (p['annual_price'] == null) {
                                                selectedCycle = 'monthly';
                                              }
                                            });
                                          }
                                        },
                                        selectedColor: Colors.amber,
                                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Package Privileges Card
                            Text(
                              '${TxaLanguage.t('vip_privileges').toUpperCase()} $pkgTitle',
                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161A26),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: features.map((f) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            f.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Billing Cycle Selector
                            Text(
                              TxaLanguage.t('billing_cycle_title').toUpperCase(),
                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => selectedCycle = 'monthly'),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161A26),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: selectedCycle == 'monthly' ? Colors.amber : Colors.white.withValues(alpha: 0.05),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            TxaLanguage.t('billing_monthly_tab'),
                                            style: TextStyle(
                                              color: selectedCycle == 'monthly' ? Colors.amber : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            NumberFormatCurrency.format(monthlyPrice),
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasAnnual) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setModalState(() => selectedCycle = 'annual'),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF161A26),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: selectedCycle == 'annual' ? Colors.amber : Colors.white.withValues(alpha: 0.05),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${TxaLanguage.t('billing_annual_tab')} (-$discountPercent%)',
                                              style: TextStyle(
                                                color: selectedCycle == 'annual' ? Colors.amber : Colors.white70,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              NumberFormatCurrency.format(annualPrice),
                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Payment Methods Card
                            Text(
                              TxaLanguage.t('payment_method_title').toUpperCase(),
                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161A26),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final showSepay = paymentInfo['sepay_enable'] == true;
                                  final showManual = paymentInfo['manual_enable'] == true;
                                  
                                  if (selectedPaymentMethod == 'sepay' && !showSepay) {
                                    selectedPaymentMethod = 'vietqr';
                                  } else if (selectedPaymentMethod == 'vietqr' && !showManual && showSepay) {
                                    selectedPaymentMethod = 'sepay';
                                  }

                                  return Column(
                                    children: [
                                      if (showSepay) ...[
                                        GestureDetector(
                                          onTap: () => setModalState(() => selectedPaymentMethod = 'sepay'),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            color: Colors.transparent,
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  margin: const EdgeInsets.only(top: 2),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: selectedPaymentMethod == 'sepay' ? Colors.amber : Colors.white30,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: selectedPaymentMethod == 'sepay'
                                                      ? Center(
                                                          child: Container(
                                                            width: 10,
                                                            height: 10,
                                                            decoration: const BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.amber,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        TxaLanguage.t('sepay_gateway_title'),
                                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        TxaLanguage.t('sepay_gateway_desc'),
                                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (showManual)
                                          const Divider(color: Colors.white10, height: 1),
                                      ],
                                      if (showManual)
                                        GestureDetector(
                                          onTap: () => setModalState(() => selectedPaymentMethod = 'vietqr'),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            color: Colors.transparent,
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  margin: const EdgeInsets.only(top: 2),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: selectedPaymentMethod == 'vietqr' ? Colors.amber : Colors.white30,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: selectedPaymentMethod == 'vietqr'
                                                      ? Center(
                                                          child: Container(
                                                            width: 10,
                                                            height: 10,
                                                            decoration: const BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.amber,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        TxaLanguage.t('manual_vietqr_title'),
                                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        TxaLanguage.t('manual_vietqr_desc'),
                                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Promo Code Input Row
                            Text(
                              TxaLanguage.t('promo_code_title').toUpperCase(),
                              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161A26),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_offer_rounded, color: Colors.orangeAccent, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: promoController,
                                      enabled: appliedPromoCode == null,
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: TxaLanguage.t('coupon_input_hint'),
                                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  if (appliedPromoCode != null)
                                    IconButton(
                                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () {
                                        setModalState(() {
                                          appliedPromoCode = null;
                                          appliedDiscountAmount = null;
                                          promoController.clear();
                                        });
                                      },
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () async {
                                        final code = promoController.text.trim();
                                        await applyPromoCode(code);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                        TxaLanguage.t('coupon_apply_btn'),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Dynamic promo suggestions
                            if (pkgPromos.isNotEmpty && appliedPromoCode == null) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: pkgPromos.map((p) {
                                    final code = p['code']?.toString() ?? '';
                                    final val = p['discount_value'];
                                    final type = p['discount_type'] ?? 'percent';
                                    final discountStr = type == 'percent'
                                        ? '-$val%'
                                        : '-${NumberFormatCurrency.format((val as num?)?.toInt() ?? 0)}';

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: Text(
                                          '$code ($discountStr)',
                                          style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: Colors.amber.withValues(alpha: 0.1),
                                        side: BorderSide(color: Colors.amber.withValues(alpha: 0.38)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        onPressed: () {
                                          promoController.text = code;
                                          applyPromoCode(code);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            if (appliedPromoCode != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        TxaLanguage.t('promo_applied_msg', replace: {
                                          'code': appliedPromoCode ?? '',
                                          'discount': NumberFormatCurrency.format(appliedDiscountAmount ?? 0),
                                        }),
                                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Total Pricing display
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161A26),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        TxaLanguage.t('total_title').toUpperCase(),
                                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        TxaLanguage.t('price_includes_vat'),
                                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        NumberFormatCurrency.format(finalPrice),
                                        style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900),
                                      ),
                                      if (discount > 0)
                                        Text(
                                          '${TxaLanguage.t('discount_label')}: -${NumberFormatCurrency.format(discount)}',
                                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Action upgrade/renew button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final txid = 'TXA${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                    final pkgId = selectedPkg['id']?.toString() ?? '';

                                    // Call sepayInit to create the pending payment log on server
                                    await TxaApi().sepayInit(
                                      txid,
                                      finalPrice,
                                      pkgTitle,
                                      selectedCycle,
                                      pkgId,
                                    );

                                    if (!context.mounted) return;

                                    // Add transaction log to backend in pending state
                                    await TxaApi().postPaymentLog({
                                      'txid': txid,
                                      'username': user?['username'],
                                      'email': user?['email'],
                                      'packageTitle': pkgTitle,
                                      'price': finalPrice,
                                      'cycle': selectedCycle,
                                      'method': selectedPaymentMethod,
                                      'status': 'pending',
                                      'actionType': isCurrentPkg ? 'renew' : 'upgrade',
                                      'promoCode': appliedPromoCode,
                                      'note': isCurrentPkg
                                          ? TxaLanguage.t('payment_note_renew').replaceAll('%pkg%', pkgTitle)
                                          : TxaLanguage.t('payment_note_upgrade'),
                                    });

                                    if (!context.mounted) return;
                                    Navigator.pop(ctx); // Close dialog

                                    if (selectedPaymentMethod == 'sepay') {
                                      // Open SePay Payment gateway web page
                                      const siteUrl = TxaApi.baseUrl;
                                      final checkoutUri = Uri.parse(
                                        '$siteUrl/checkout/sepay?txid=$txid&price=$finalPrice&cycle=$selectedCycle&packageTitle=${Uri.encodeComponent(pkgTitle)}&packageId=${Uri.encodeComponent(pkgId)}&email=${Uri.encodeComponent(user?['email']?.toString() ?? '')}'
                                      );
                                      if (await canLaunchUrl(checkoutUri)) {
                                        await launchUrl(checkoutUri, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (context.mounted) {
                                          TxaToast.show(context, TxaLanguage.t('payment_open_failed'), isError: true);
                                        }
                                      }
                                    } else {
                                      // Open MBBank transfer VietQR bottom sheet
                                      _showPaymentQRSheet(
                                        selectedPkg,
                                        paymentInfo,
                                        actionType: isCurrentPkg ? 'renew' : 'upgrade',
                                        cycle: selectedCycle,
                                        finalPrice: finalPrice,
                                        promoCode: appliedPromoCode,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      TxaToast.show(context, '${TxaLanguage.t('payment_init_error')}: $e', isError: true);
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setModalState(() => isSubmitting = false);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: isSubmitting
                                    ? const CircularProgressIndicator(color: Colors.black)
                                    : Text(
                                        buttonText,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
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
    );
  }

  // Legacy dialog methods removed to support unified upgrade dialog options

  void _showPaymentQRSheet(dynamic package, Map<String, dynamic> paymentInfo, {String actionType = 'upgrade', String? cycle, int? finalPrice, String? promoCode}) async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final price = finalPrice ?? (package['price'] as int? ?? 0);
    final effectiveCycle = cycle ?? package['cycle'] ?? 'monthly';
    final txid = 'TXA${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final pkgTitle = package['title'] ?? 'VIP';
    final pkgId = package['id']?.toString() ?? '';

    // Call sepayInit to create the pending payment log on server
    TxaToast.show(context, TxaLanguage.t('creating_tx'));
    await TxaApi().sepayInit(
      txid,
      price,
      pkgTitle,
      effectiveCycle,
      pkgId,
    );

    if (!mounted) return;

    // QR Image url format: https://api.vietqr.io/image/<BANK_ID>-<ACCOUNT_NO>-compact2.jpg?amount=<AMOUNT>&addInfo=<DESCRIPTION>&accountName=<ACCOUNT_NAME>
    final bankName = paymentInfo['bank_name'] ?? 'MBBank';
    final accountNo = paymentInfo['account_no'] ?? '0000000000';
    final accountName = paymentInfo['account_name'] ?? 'SYSTEM';
    final encodedAccountName = Uri.encodeComponent(accountName);
    
    // Add transaction log to backend in pending state
    await TxaApi().postPaymentLog({
      'txid': txid,
      'username': user['username'],
      'email': user['email'],
      'packageTitle': pkgTitle,
      'price': price,
      'cycle': effectiveCycle,
      'method': 'sepay',
      'status': 'pending',
      'actionType': actionType,
      'promoCode': promoCode,
      'note': actionType == 'renew'
          ? TxaLanguage.t('payment_note_renew').replaceAll('%pkg%', pkgTitle)
          : TxaLanguage.t('payment_note_upgrade'),
    });

    if (!mounted) return;

    final qrUrl = 'https://api.vietqr.io/image/$bankName-$accountNo-compact2.jpg?amount=$price&addInfo=$txid&accountName=$encodedAccountName';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: TxaTheme.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                TxaLanguage.t('vietqr_scan_title'),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                TxaLanguage.t('vietqr_scan_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              const SizedBox(height: 24),
              
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CachedNetworkImage(
                  imageUrl: qrUrl,
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const SizedBox(
                    width: 250,
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (c, u, e) => Container(
                    width: 250,
                    height: 250,
                    color: Colors.white10,
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bank details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _buildPaymentDetailRow(TxaLanguage.t('bank_label'), bankName),
                    _buildPaymentDetailRow(TxaLanguage.t('account_no_label'), accountNo, isSelectable: true),
                    _buildPaymentDetailRow(TxaLanguage.t('account_name_label'), accountName),
                    _buildPaymentDetailRow(TxaLanguage.t('amount_label'), NumberFormatCurrency.format(price), isHighlight: true),
                    _buildPaymentDetailRow(TxaLanguage.t('transfer_note_label'), txid, isHighlight: true, isSelectable: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadCabinetData();
                  TxaToast.show(context, TxaLanguage.t('payment_pending_msg'));
                },
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(TxaLanguage.t('confirm_transferred'), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TxaTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  // Open web checkout page
                  const siteUrl = TxaApi.baseUrl;
                  final checkoutUri = Uri.parse(
                    '$siteUrl/checkout/sepay?txid=$txid&price=$price&cycle=$effectiveCycle&packageTitle=${Uri.encodeComponent(pkgTitle)}&packageId=${Uri.encodeComponent(pkgId)}&email=${Uri.encodeComponent(user['email']?.toString() ?? '')}'
                  );
                  if (await canLaunchUrl(checkoutUri)) {
                    if (!mounted) return;
                    await launchUrl(checkoutUri, mode: LaunchMode.externalApplication);
                  } else {
                    if (!mounted) return;
                    TxaToast.show(context, TxaLanguage.t('payment_open_failed'));
                  }
                },
                child: Text(TxaLanguage.t('open_checkout_web'), style: const TextStyle(color: TxaTheme.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, {bool isHighlight = false, bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13)),
          Flexible(
            child: isSelectable 
              ? SelectableText(
                  value,
                  style: TextStyle(
                    color: isHighlight ? Colors.amber : Colors.white,
                    fontSize: 14,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: isHighlight ? Colors.amber : Colors.white,
                    fontSize: 14,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('data:image/')) {
      try {
        final base64String = avatarUrl.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Error decoding base64 avatar: $e');
        return null;
      }
    }
    return CachedNetworkImageProvider(avatarUrl);
  }

  Future<void> _pickAndCropAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('loading_image'), isError: false);
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final decodedImage = frameInfo.image;
      _showCropDialog(bytes, decodedImage);
    } catch (e) {
      debugPrint('Error picking avatar: $e');
      if (mounted) TxaToast.show(context, TxaLanguage.t('error_pick_image').replaceAll('%error%', '$e'), isError: true);
    }
  }

  void _showCropDialog(Uint8List imageBytes, ui.Image decodedImage) {
    const double viewSize = 300.0;
    const double circleRadius = 112.0;

    // The scale where the image fits the crop view
    final double baseScale = math.max(
      viewSize / decodedImage.width.toDouble(),
      viewSize / decodedImage.height.toDouble(),
    );

    double imgScale = baseScale;
    double imgOffsetX = 0.0;
    double imgOffsetY = 0.0;
    double startScale = baseScale;
    Offset startOffset = Offset.zero;
    Offset? startFocalPoint;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateCrop) {
            final int zoomPercent = ((imgScale / baseScale) * 100).round();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TxaLanguage.t('crop_avatar_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TxaLanguage.t('crop_avatar_hint'),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Crop viewport area
                    Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          setStateCrop(() {
                            final zoomFactor = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
                            imgScale = (imgScale + baseScale * zoomFactor)
                                .clamp(baseScale * 0.1, baseScale * 4.0);
                          });
                        }
                      },
                      child: GestureDetector(
                        onScaleStart: (details) {
                          startScale = imgScale;
                          startOffset = Offset(imgOffsetX, imgOffsetY);
                          startFocalPoint = details.localFocalPoint;
                        },
                        onScaleUpdate: (details) {
                          setStateCrop(() {
                            imgScale = (startScale * details.scale)
                                .clamp(baseScale * 0.1, baseScale * 4.0);
                            if (startFocalPoint != null) {
                              final Offset delta = details.localFocalPoint - startFocalPoint!;
                              imgOffsetX = startOffset.dx + delta.dx;
                              imgOffsetY = startOffset.dy + delta.dy;
                            }
                          });
                        },
                        child: Container(
                          width: viewSize,
                          height: viewSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CustomPaint(
                            painter: _CropOverlayPainter(
                              decodedImage: decodedImage,
                              scale: imgScale,
                              offsetX: imgOffsetX,
                              offsetY: imgOffsetY,
                              viewSize: viewSize,
                              circleRadius: circleRadius,
                              accentColor: const Color(0xFFA855F7),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Zoom slider & percentage controls
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              TxaLanguage.t('zoom_image'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '$zoomPercent%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            activeTrackColor: TxaTheme.accent,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                            thumbColor: TxaTheme.accent,
                            overlayColor: TxaTheme.accent.withValues(alpha: 0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            min: 10.0,
                            max: 400.0,
                            value: zoomPercent.toDouble().clamp(10.0, 400.0),
                            onChanged: (val) {
                              setStateCrop(() {
                                imgScale = baseScale * (val / 100.0);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(TxaLanguage.t('cancel'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              _cropAndUploadCustom(
                                imageBytes,
                                imgScale,
                                imgOffsetX,
                                imgOffsetY,
                                viewSize,
                                circleRadius,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TxaTheme.accent,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              TxaLanguage.t('crop_save'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cropAndUploadCustom(
    Uint8List imageBytes,
    double imgScale,
    double imgOffsetX,
    double imgOffsetY,
    double viewSize,
    double circleRadius,
  ) async {
    if (mounted) {
      TxaToast.show(context, TxaLanguage.t('cropping_image'), isError: false);
    }
    try {
      final codec = await instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final originalImage = frameInfo.image;

      const double outputSize = 256.0;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, outputSize, outputSize));

      // The circle center in view coordinates
      final double circleCx = viewSize / 2;
      final double circleCy = viewSize / 2;

      // Image is drawn centered at (circleCx + imgOffsetX, circleCy + imgOffsetY)
      // with its natural size scaled by imgScale
      final double imgW = originalImage.width * imgScale;
      final double imgH = originalImage.height * imgScale;
      final double imgLeft = circleCx + imgOffsetX - imgW / 2;
      final double imgTop = circleCy + imgOffsetY - imgH / 2;

      // Circle bounds in view coordinates
      final double circleLeft = circleCx - circleRadius;
      final double circleTop = circleCy - circleRadius;

      // Source rect in original image coordinates
      final double srcScale = 1.0 / imgScale;
      final double srcX = (circleLeft - imgLeft) * srcScale;
      final double srcY = (circleTop - imgTop) * srcScale;
      final double srcW = (circleRadius * 2) * srcScale;
      final double srcH = (circleRadius * 2) * srcScale;

      final paint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        originalImage,
        Rect.fromLTWH(srcX, srcY, srcW, srcH),
        const Rect.fromLTWH(0, 0, outputSize, outputSize),
        paint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(outputSize.toInt(), outputSize.toInt());
      final byteData = await img.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;

      final croppedBytes = byteData.buffer.asUint8List();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(croppedBytes)}';
      _uploadAvatarToServer(base64Image);
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) TxaToast.show(context, TxaLanguage.t('error_crop_image'), isError: true);
    }
  }

  Future<void> _uploadAvatarToServer(String base64Image) async {
    if (mounted) {
      TxaToast.show(context, TxaLanguage.t('uploading_avatar'), isError: false);
    }
    try {
      final res = await TxaApi().updateAvatar(base64Image);
      if (!mounted) return;
      if (res != null && res['status'] == 'success') {
        TxaToast.show(context, TxaLanguage.t('avatar_updated_success'), isError: false);
        // Sync avatar_url toàn app (Home Drawer, TV Confirm, v.v.)
        final auth = Provider.of<TxaAuthService>(context, listen: false);
        auth.updateUserField('avatar_url', base64Image);
        _loadCabinetData();
      } else {
        final data = res?['data'] as Map<String, dynamic>?;
        final errorCode = data?['error_code'] ?? '';
        String msg = res?['message'] ?? TxaLanguage.t('avatar_update_failed');
        
        if (errorCode == 'LIMIT_REACHED') {
          final trans = TxaLanguage.t('avatar_limit_reached');
          msg = trans.isNotEmpty ? trans : 'Bạn đã đạt giới hạn đổi ảnh đại diện trong tháng này!';
        } else if (errorCode == 'UNAUTHORIZED') {
          final trans = TxaLanguage.t('session_expired_please_login');
          msg = trans.isNotEmpty ? trans : 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại!';
        } else if (errorCode == 'INVALID_FORMAT') {
          final trans = TxaLanguage.t('invalid_image_format');
          msg = trans.isNotEmpty ? trans : 'Định dạng ảnh không hợp lệ!';
        }
        
        TxaToast.show(context, msg, isError: true);
      }
    } catch (e) {
      if (mounted) TxaToast.show(context, TxaLanguage.t('server_conn_error_simple'), isError: true);
    }
  }

  // --- Builders ---

  @override
  Widget build(BuildContext context) {
    Provider.of<TxaLanguage>(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<TxaAuthService>(
        builder: (context, auth, child) {
          if (!auth.isLoggedIn) {
            return _buildLoginForm();
          }

          if (_cabinetLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: TxaTheme.accent),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('loading_data'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadCabinetData,
            color: TxaTheme.accent,
            backgroundColor: TxaTheme.cardBg,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // Top header safe area offset
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).padding.top + 16),
                ),

                // Profile Header Card
                SliverToBoxAdapter(
                  child: _buildProfileHeader(auth.user!),
                ),

                // VIP Subscription Details Card
                SliverToBoxAdapter(
                  child: _buildVIPCard(auth.user!),
                ),

                // Watch History Shelf
                SliverToBoxAdapter(
                  child: _buildWatchHistoryShelf(),
                ),

                // Favorites Shelf
                SliverToBoxAdapter(
                  child: _buildFavoritesShelf(),
                ),

                // Payments History Section
                SliverToBoxAdapter(
                  child: _buildPaymentsSection(),
                ),

                // TV Connection Section
                SliverToBoxAdapter(
                  child: _buildTVConnectionSection(),
                ),


                // Logout CTA
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      label: Text(
                        TxaLanguage.t('logout'),
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),

                // Spacing bottom for float nav bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/dongphim_logo.png', height: 72),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('app_name'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Text(
              TxaLanguage.t('app_slogan'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 36),

            // Form Content inside Liquid Glass Container
            TxaTheme.liquidGlassPill(
              radius: 24,
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      TxaLanguage.t('login'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Username/Email Field
                    TextFormField(
                      controller: _identityController,
                      focusNode: _identityFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: TxaLanguage.t('login_id'),
                        hintText: TxaLanguage.t('login_id_hint'),
                        errorText: _identityError,
                        labelStyle: const TextStyle(color: TxaTheme.textSecondary),
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: TxaTheme.accent),
                        filled: true,
                        fillColor: Colors.black26,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
                        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Colors.white10, width: 1)),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: TxaTheme.accent, width: 1.5)),
                        errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xD8FF5252), width: 1.5)),
                        focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Colors.redAccent, width: 2.0)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: TxaLanguage.t('password'),
                        hintText: TxaLanguage.t('password_hint'),
                        errorText: _passwordError,
                        labelStyle: const TextStyle(color: TxaTheme.textSecondary),
                        hintStyle: const TextStyle(color: Colors.white24),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: TxaTheme.accent),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: TxaTheme.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.black26,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
                        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Colors.white10, width: 1)),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: TxaTheme.accent, width: 1.5)),
                        errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xD8FF5252), width: 1.5)),
                        focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Colors.redAccent, width: 2.0)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _loginLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TxaTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loginLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(TxaLanguage.t('login'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),

                    // Switch to Register Info Dialog
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          TxaLanguage.t('no_account_yet'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: _showRegisterDialog,
                          child: Text(
                            TxaLanguage.t('register_now'),
                            style: const TextStyle(color: TxaTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    final name = user['name'] ?? user['username'] ?? 'User';
    final email = user['email'] ?? '';
    final role = (user['role'] ?? 'user').toString().toUpperCase();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TxaTheme.liquidGlassPill(
        radius: 24,
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Circular Avatar Glow
            GestureDetector(
              onTap: _pickAndCropAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TxaTheme.accent, width: 2),
                      boxShadow: [
                        BoxShadow(color: TxaTheme.accent.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: TxaTheme.secondaryBg,
                      backgroundImage: _getAvatarProvider(user['avatar_url']?.toString()),
                      child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                          ? Text(
                              initials,
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: TxaTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.black,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Profile info metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TxaTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TxaTheme.accent.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(color: TxaTheme.accent, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'UID: #${user['id'] ?? 'N/A'}',
                    style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVIPCard(Map<String, dynamic> user) {
    final isVIP = (user['package'] ?? 'free').toString().toLowerCase() != 'free';
    final packageName = isVIP ? 'MEMBER VIP' : 'FREE ACCOUNT';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TxaTheme.liquidGlassPill(
        radius: 20,
        borderGlowColor: isVIP ? Colors.amber.withValues(alpha: 0.4) : null,
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isVIP ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                      color: isVIP ? Colors.amber : TxaTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      packageName,
                      style: TextStyle(
                        color: isVIP ? Colors.amber : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isVIP ? TxaLanguage.t('vip_card_desc_active') : TxaLanguage.t('vip_card_desc_inactive'),
                  style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _showVIPUpgradeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: isVIP ? TxaTheme.secondaryBg : Colors.amber,
                foregroundColor: isVIP ? Colors.amber : Colors.black,
                elevation: 0,
                side: isVIP ? const BorderSide(color: Colors.amber, width: 1) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                isVIP ? TxaLanguage.t('renew_btn') : TxaLanguage.t('upgrade_btn'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchHistoryShelf() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    TxaLanguage.t('watch_history'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const TxaWatchHistoryScreen()),
                      ).then((_) => _loadCabinetData());
                    },
                    child: Text(
                      TxaLanguage.t('see_all_movies'),
                      style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _handleClearHistory,
                child: Text(
                  TxaLanguage.t('clear'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final name = item['movie_name'] ?? '';
              final epName = item['episode_name'] ?? '';
              final thumbUrl = item['movie_thumb'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MovieDetailScreen(slug: item['movie_slug'] ?? ''),
                    ),
                  ).then((_) => _loadCabinetData());
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TxaTheme.liquidGlassPill(
                    radius: 12,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: thumbUrl,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                            errorWidget: (c, u, e) => Container(color: TxaTheme.cardBg),
                          ),
                        ),
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
                        Positioned(
                          bottom: 8,
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
                                style: const TextStyle(color: TxaTheme.accent, fontSize: 8, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    if (_favorites.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 20.0, right: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TxaLanguage.t('favorites_list'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const TxaFavoritesListScreen()),
                    ).then((_) => _loadCabinetData());
                  },
                  child: Text(
                    TxaLanguage.t('see_all_movies'),
                    style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(TxaLanguage.t('no_favorites_yet'), style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 20.0, right: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('favorites_list'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const TxaFavoritesListScreen()),
                  ).then((_) => _loadCabinetData());
                },
                child: Text(
                  TxaLanguage.t('see_all_movies'),
                  style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final movie = _favorites[index];
              final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
              final name = movie['name'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MovieDetailScreen(slug: movie['slug'] ?? ''),
                    ),
                  ).then((_) => _loadCabinetData());
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TxaTheme.liquidGlassPill(
                        radius: 12,
                        child: SizedBox(
                          height: 140,
                          width: 100,
                          child: CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                            errorWidget: (c, u, e) => Container(color: TxaTheme.cardBg),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildPaymentsSection() {
    if (_payments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 20.0, right: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TxaLanguage.t('billing_history'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const TxaPaymentHistoryScreen()),
                  ).then((_) => _loadCabinetData());
                },
                child: Text(
                  TxaLanguage.t('see_all_movies'),
                  style: const TextStyle(color: TxaTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _payments.length,
              separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final log = _payments[index];
                final title = log['packageTitle'] ?? TxaLanguage.t('vip_package_default');
                final price = NumberFormatCurrency.format(log['price']);
                final status = log['status']?.toString().toLowerCase() ?? 'pending';
                final date = log['date'] != null ? log['date'].toString().split('T')[0] : '';
                
                Color statusColor = Colors.orangeAccent;
                String statusLabel = TxaLanguage.t('status_pending');
                if (status == 'approved') {
                  statusColor = Colors.greenAccent;
                  statusLabel = TxaLanguage.t('status_approved');
                } else if (status == 'rejected') {
                  statusColor = Colors.redAccent;
                  statusLabel = TxaLanguage.t('status_rejected');
                }
  
                return ListTile(
                  title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    TxaLanguage.t('transaction_id_label')
                        .replaceAll('%txid%', log['txid']?.toString() ?? '')
                        .replaceAll('%date%', date),
                    style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTVConnectionSection() {
    if (TxaPlatform.isTV) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 20.0, bottom: 8.0),
          child: Text(
            TxaLanguage.t('tv_link_title'),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tv_rounded, color: TxaTheme.accent),
                  title: Text(TxaLanguage.t('tv_login_by_code'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(TxaLanguage.t('tv_login_enter_code'), style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                  onTap: () {
                    TxaTvPairModal.show(context);
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                if (TxaPlatform.isMobile || TxaPlatform.isTV)
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner_rounded, color: TxaTheme.accent),
                    title: Text(TxaLanguage.t('tv_scan_qr_title_btn'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text(TxaLanguage.t('tv_scan_qr_desc_btn'), style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TxaQrScanScreen()),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Simple Currency Helper to prevent importing huge libraries
class NumberFormatCurrency {
  static String format(dynamic value) {
    if (value == null) return '0đ';
    final int number = int.tryParse(value.toString()) ?? 0;
    
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    buffer.write('đ');
    return buffer.toString();
  }
}

class _CropOverlayPainter extends CustomPainter {
  final ui.Image decodedImage;
  final double scale;
  final double offsetX;
  final double offsetY;
  final double viewSize;
  final double circleRadius;
  final Color accentColor;

  _CropOverlayPainter({
    required this.decodedImage,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.viewSize,
    required this.circleRadius,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final img = decodedImage;
    
    // Draw image centered with scale and offset
    final double cx = viewSize / 2;
    final double cy = viewSize / 2;
    
    final double imgW = img.width * scale;
    final double imgH = img.height * scale;
    
    final double left = cx + offsetX - imgW / 2;
    final double top = cy + offsetY - imgH / 2;

    final paintImg = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(left, top, imgW, imgH),
      paintImg,
    );

    // Draw Dark Overlay with Circular Cutout (rgba(9, 9, 11, 0.7))
    final overlayPaint = Paint()
      ..color = const Color(0xB309090B)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, viewSize, viewSize))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: circleRadius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // Draw Dashed Circular Border Guide (#A855F7)
    final borderPaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double circumference = 2 * math.pi * circleRadius;
    final int dashCount = (circumference / 10).floor();
    final double anglePerDash = (2 * math.pi) / dashCount;
    final double dashAngle = anglePerDash * 0.5;

    for (int i = 0; i < dashCount; i++) {
      final double startAngle = i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: circleRadius),
        startAngle,
        dashAngle,
        false,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offsetX != offsetX ||
        oldDelegate.offsetY != offsetY ||
        oldDelegate.decodedImage != decodedImage;
  }
}
