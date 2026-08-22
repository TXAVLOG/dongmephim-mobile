import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/txa_logger.dart';
import 'txa_api.dart';
import '../services/txa_language.dart';
import '../services/txa_dynamic_icon_service.dart';
typedef OnPurchaseSuccessCallback = void Function(String? keyCode, String message);
typedef OnPurchaseErrorCallback = void Function(String error);
typedef OnPurchasePendingCallback = void Function(String statusMessage);

class TxaIapService {
  static final TxaIapService _instance = TxaIapService._internal();
  factory TxaIapService() => _instance;
  TxaIapService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  OnPurchaseSuccessCallback? onPurchaseSuccess;
  OnPurchaseErrorCallback? onPurchaseError;
  OnPurchasePendingCallback? onPurchasePending;
  bool _hasRestoredAny = false;

  static const String productIdNormal = 'zalo_key_normal';
  static const String productIdAdmin = 'zalo_key_admin';
  static const String productIdCustomIcon = 'custom_icon_monthly';

  static const Set<String> _kProductIds = {
    productIdNormal,
    productIdAdmin,
    productIdCustomIcon,
  };

  /// 1. Khởi tạo Google Play Billing Service
  Future<void> initialize({
    OnPurchaseSuccessCallback? onSuccess,
    OnPurchaseErrorCallback? onError,
    OnPurchasePendingCallback? onPending,
  }) async {
    onPurchaseSuccess = onSuccess;
    onPurchaseError = onError;
    onPurchasePending = onPending;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      TxaLogger.log('Google Play Billing không khả dụng trên thiết bị này.', type: 'iap');
      return;
    }

    // Đăng ký nhận luồng cập nhật mua hàng từ Store
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        TxaLogger.log('Lỗi purchaseStream: $error', type: 'iap');
        onPurchaseError?.call(TxaLanguage.t('iap_payment_failed'));
      },
    );

    // Tải danh sách sản phẩm từ Store
    await loadProducts();
  }

  /// 2. Tải danh sách sản phẩm từ Google Play / App Store
  Future<List<ProductDetails>> loadProducts() async {
    if (!_isAvailable) {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) return [];
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(_kProductIds);
    if (response.error != null) {
      final errMsg = 'Lỗi queryProductDetails Google Play: [${response.error!.code}] ${response.error!.message}';
      TxaLogger.log(errMsg, type: 'crash');
      TxaLogger.log(errMsg, type: 'iap');
    }

    if (response.notFoundIDs.isNotEmpty) {
      final notFoundMsg = 'Google Play không tìm thấy Product IDs: ${response.notFoundIDs}. '
          'Gói thuê bao (custom_icon_monthly) cần có Base Plan đã Active trên Play Console và bản build tester đã upload.';
      TxaLogger.log(notFoundMsg, type: 'crash');
      TxaLogger.log(notFoundMsg, type: 'iap');
    }

    _products = response.productDetails;
    TxaLogger.log('Tải thành công ${_products.length} sản phẩm từ Google Play: ${_products.map((p) => '${p.id} (${p.price})').toList()}', type: 'iap');
    return _products;
  }

  /// 3. Thực hiện kích hoạt luồng Mua sản phẩm
  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      TxaLogger.log('Google Play Billing không sẵn sàng trên thiết bị khi mua $productId', type: 'crash');
      onPurchaseError?.call(TxaLanguage.t('iap_store_unavailable'));
      return false;
    }

    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      // Nếu chưa có trong danh sách nạp trước, thử tải lại
      await loadProducts();
      try {
        product = _products.firstWhere((p) => p.id == productId);
      } catch (_) {}
    }

    if (product == null) {
      TxaLogger.log('Không tìm thấy product details cho $productId trên Store Console (Chưa active Base Plan hoặc ID chưa sẵn sàng).', type: 'crash');
      onPurchaseError?.call(TxaLanguage.t('iap_product_not_available'));
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    // Gói Thuê bao Đổi Icon / Subscriptions yêu cầu gọi buyNonConsumable để loại bỏ lỗi Developer Console
    if (productId == productIdCustomIcon || productId.contains('icon') || productId.contains('sub')) {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
    return await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 4. Khôi phục giao dịch cũ (Restore Purchases)
  Future<bool> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call(TxaLanguage.t('iap_store_unavailable'));
      return false;
    }
    _hasRestoredAny = false;
    onPurchasePending?.call(TxaLanguage.t('iap_checking_orders'));
    await _iap.restorePurchases();

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!_hasRestoredAny) {
      onPurchaseError?.call(TxaLanguage.t('iap_no_orders_to_restore'));
      return false;
    }
    return true;
  }

  /// 5. Xử lý sự kiện cập nhật trạng thái mua từ Store
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          TxaLogger.log('Giao dịch đang được xử lý (Pending)... ID: ${purchaseDetails.productID}', type: 'iap');
          onPurchasePending?.call(TxaLanguage.t('iap_processing_order'));
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _hasRestoredAny = true;
          if (purchaseDetails.productID == productIdCustomIcon || purchaseDetails.productID.contains('icon')) {
            await TxaDynamicIconService.setLocalSubscriptionActive(true);
          }
          onPurchasePending?.call(TxaLanguage.t('iap_verifying_with_server'));
          await verifyPurchase(purchaseDetails);
          break;

        case PurchaseStatus.error:
          final errCode = purchaseDetails.error?.code ?? '';
          final errMessage = purchaseDetails.error?.message ?? '';
          TxaLogger.log('Lỗi giao dịch IAP: Code=$errCode, Message=$errMessage', type: 'crash');
          TxaLogger.log('Lỗi giao dịch IAP: Code=$errCode, Message=$errMessage', type: 'iap');

          final isAlreadyOwned = errCode.contains('itemAlreadyOwned') ||
              errCode.contains('ITEM_ALREADY_OWNED') ||
              errCode == '7' ||
              errMessage.contains('itemAlreadyOwned') ||
              errMessage.contains('already owned') ||
              errMessage.contains('ITEM_ALREADY_OWNED');

          if (isAlreadyOwned) {
            onPurchaseError?.call(TxaLanguage.t('iap_item_already_owned'));
          } else {
            onPurchaseError?.call(TxaLanguage.t('iap_payment_failed'));
          }
          break;

        case PurchaseStatus.canceled:
          TxaLogger.log('Người dùng đã hủy giao dịch IAP.', type: 'iap');
          onPurchaseError?.call(TxaLanguage.t('iap_purchase_canceled_msg'));
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// 6. Xác thực Hóa đơn IAP với Backend Supabase để phát hành mã Key Zalo
  Future<void> verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final String orderId = purchaseDetails.purchaseID ?? 'IAP_${DateTime.now().millisecondsSinceEpoch}';
      final String productId = purchaseDetails.productID;
      
      final bool isCustomIcon = productId == productIdCustomIcon || productId.contains('icon');
      final bool isAdmin = productId == productIdAdmin;

      final String packageTitle = isCustomIcon
          ? 'Gói Đổi Icon App (Monthly)'
          : (isAdmin ? 'Gói Key Bypass Zalo (15 Thiết bị - Ưu đãi Admin)' : 'Gói Key Bypass Zalo (15 Thiết bị)');

      double price = isCustomIcon ? 9000.0 : (isAdmin ? 7000.0 : 40000.0);
      try {
        final prod = _products.firstWhere((p) => p.id == productId);
        if (prod.rawPrice > 0) {
          price = prod.rawPrice;
        }
        // Extract numeric digits from localized price string (e.g., "9.000 ₫" -> 9000.0)
        final cleanDigits = prod.price.replaceAll(RegExp(r'[^\d]'), '');
        final parsedVal = double.tryParse(cleanDigits);
        if (parsedVal != null && parsedVal >= 0) {
          price = parsedVal;
        }
      } catch (_) {}

      if (isCustomIcon) {
        final bool isTrial = price == 0;
        await TxaDynamicIconService.setLocalSubscriptionActive(true, isTrial: isTrial);
      }

      final String dynamicPackageTitle = isCustomIcon
          ? (price == 0
              ? TxaLanguage.t('icon_sub_trial_package_title')
              : TxaLanguage.t('icon_sub_monthly_package_title'))
          : packageTitle;

      // Gọi API POST lên backend /api/user/payments
      final result = await TxaApi.submitIapPayment(
        txid: orderId,
        packageTitle: dynamicPackageTitle,
        price: price,
        cycle: isCustomIcon ? (price == 0 ? 'trial_7_days' : 'monthly') : 'custom_1',
        method: 'google_play',
        status: 'approved',
        clientInfo: 'Google Play Billing - Product: $productId (Price: $price)',
      );

      if (result['success'] == true) {
        final String? keyCode = result['keyCode'];
        final String defaultSuccessMsg = isCustomIcon
            ? TxaLanguage.t('iap_icon_restore_success')
            : TxaLanguage.t('iap_zalo_key_success');
        onPurchaseSuccess?.call(
          keyCode, 
          result['message'] ?? defaultSuccessMsg,
        );
      } else {
        onPurchaseError?.call(result['message'] ?? TxaLanguage.t('iap_verify_failed'));
      }
    } catch (e) {
      TxaLogger.log('Lỗi khi verifyPurchase: $e', type: 'crash');
      TxaLogger.log('Lỗi khi verifyPurchase: $e', type: 'iap');
      onPurchaseError?.call(TxaLanguage.t('iap_verify_order_error'));
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
