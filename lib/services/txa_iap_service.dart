import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/txa_logger.dart';
import 'txa_api.dart';
import '../services/txa_language.dart';
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

  static const Set<String> _kProductIds = {
    productIdNormal,
    productIdAdmin,
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
        onPurchaseError?.call(error.toString());
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
      TxaLogger.log('Lỗi queryProductDetails: ${response.error!.message}', type: 'iap');
    }

    if (response.notFoundIDs.isNotEmpty) {
      TxaLogger.log('Không tìm thấy Product IDs trên Store Console: ${response.notFoundIDs}', type: 'iap');
    }

    _products = response.productDetails;
    return _products;
  }

  /// 3. Thực hiện kích hoạt luồng Mua sản phẩm
  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      onPurchaseError?.call('Cửa hàng thanh toán Google Play không sẵn sàng.');
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
      onPurchaseError?.call('Sản phẩm ($productId) chưa được kích hoạt trên Google Play Console.');
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Mua sản phẩm dạng Consumable (dùng 1 lần / Air Drop item)
    return await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 4. Khôi phục giao dịch cũ (Restore Purchases)
  Future<bool> restorePurchases() async {
    if (!_isAvailable) {
      onPurchaseError?.call('Cửa hàng thanh toán Google Play không sẵn sàng.');
      return false;
    }
    _hasRestoredAny = false;
    onPurchasePending?.call('Đang quét lịch sử đơn hàng từ Google Play...');
    await _iap.restorePurchases();

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!_hasRestoredAny) {
      onPurchaseError?.call('Không tìm thấy đơn hàng nào đã mua trên Google Play để khôi phục.');
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
          onPurchasePending?.call('Đang quét và xử lý giao dịch trên Google Play...');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _hasRestoredAny = true;
          onPurchasePending?.call('Phát hiện đơn hàng! Đang xác thực với máy chủ...');
          await verifyPurchase(purchaseDetails);
          break;

        case PurchaseStatus.error:
          final errCode = purchaseDetails.error?.code ?? '';
          final errMessage = purchaseDetails.error?.message ?? '';
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
            onPurchaseError?.call(errMessage.isNotEmpty ? errMessage : 'Giao dịch thất bại.');
          }
          break;

        case PurchaseStatus.canceled:
          TxaLogger.log('Người dùng đã hủy giao dịch IAP.', type: 'iap');
          onPurchaseError?.call('Giao dịch đã bị hủy.');
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
      
      final bool isAdmin = productId == productIdAdmin;
      const String packageTitle = 'Gói Key Bypass Zalo (15 Thiết bị)';
      double price = isAdmin ? 7000.0 : 40000.0;
      try {
        final prod = _products.firstWhere((p) => p.id == productId);
        if (prod.rawPrice > 0) {
          price = prod.rawPrice;
        }
        // Extract numeric digits from localized price string (e.g., "1.000 ₫" -> 1000.0)
        final cleanDigits = prod.price.replaceAll(RegExp(r'[^\d]'), '');
        final parsedVal = double.tryParse(cleanDigits);
        if (parsedVal != null && parsedVal >= 0) {
          price = parsedVal;
        }
      } catch (_) {}

      // Gọi API POST lên backend /api/user/payments
      final result = await TxaApi.submitIapPayment(
        txid: orderId,
        packageTitle: packageTitle,
        price: price,
        method: 'google_play',
        status: 'approved',
        clientInfo: 'Google Play Billing - Product: $productId',
      );

      if (result['success'] == true) {
        final String? keyCode = result['keyCode'];
        onPurchaseSuccess?.call(
          keyCode, 
          result['message'] ?? 'Thanh toán thành công! Mã Key của bạn đã được khởi tạo.',
        );
      } else {
        onPurchaseError?.call(result['message'] ?? 'Không thể xác thực hóa đơn trên hệ thống.');
      }
    } catch (e) {
      TxaLogger.log('Lỗi khi verifyPurchase: $e', type: 'iap');
      onPurchaseError?.call('Lỗi xác thực đơn hàng: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
