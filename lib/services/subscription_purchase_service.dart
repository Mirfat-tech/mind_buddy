import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionOffer {
  const SubscriptionOffer({
    required this.productId,
    required this.tier,
    required this.period,
  });

  final String productId;
  final String tier;
  final String period;
}

class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.tier,
    required this.status,
    this.renewsAt,
    this.expiresAt,
  });

  final String tier;
  final String status;
  final DateTime? renewsAt;
  final DateTime? expiresAt;

  bool get isActive => status == 'active' || status == 'trialing';
}

class SubscriptionPurchaseController extends ChangeNotifier {
  SubscriptionPurchaseController();

  static const String verifyFunctionName = 'verify-store-purchase';
  static const List<SubscriptionOffer> catalog = [
    SubscriptionOffer(
      productId: 'mindbuddy.light.monthly',
      tier: 'light',
      period: 'monthly',
    ),
    SubscriptionOffer(
      productId: 'mindbuddy.light.yearly',
      tier: 'light',
      period: 'yearly',
    ),
    SubscriptionOffer(
      productId: 'mindbuddy.plus.monthly',
      tier: 'plus',
      period: 'monthly',
    ),
    SubscriptionOffer(
      productId: 'mindbuddy.plus.yearly',
      tier: 'plus',
      period: 'yearly',
    ),
    SubscriptionOffer(
      productId: 'mindbuddy.full.monthly',
      tier: 'full',
      period: 'monthly',
    ),
    SubscriptionOffer(
      productId: 'mindbuddy.full.yearly',
      tier: 'full',
      period: 'yearly',
    ),
  ];

  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _productsById = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  PurchaseDetails? _androidOldPurchase;

  bool _ready = false;
  bool _busy = false;
  String? _error;
  SubscriptionEntitlement? _entitlement;

  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;
  SubscriptionEntitlement? get entitlement => _entitlement;
  List<ProductDetails> get products =>
      _productsById.values.toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

  ProductDetails? productForId(String productId) => _productsById[productId];

  Future<void> init() async {
    if (_purchaseSub != null) return;
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e, StackTrace st) {
        _error = e.toString();
        notifyListeners();
      },
    );
    await Future.wait(<Future<void>>[
      loadProducts(),
      refreshEntitlement(),
      _loadAndroidOldPurchase(),
    ]);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> loadProducts() async {
    _error = null;
    final available = await _iap.isAvailable();
    if (!available) {
      _ready = false;
      _productsById.clear();
      notifyListeners();
      return;
    }

    final ids = catalog.map((e) => e.productId).toSet();
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      _ready = false;
      _error = response.error!.message;
      notifyListeners();
      return;
    }

    _productsById
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
    _ready = true;
    notifyListeners();
  }

  Future<void> refreshEntitlement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _entitlement = const SubscriptionEntitlement(
        tier: 'pending',
        status: 'inactive',
      );
      notifyListeners();
      return;
    }

    Map<String, dynamic> data = const <String, dynamic>{};
    try {
      final res = await Supabase.instance.client.rpc('get_my_entitlement');
      if (res is Map) {
        data = Map<String, dynamic>.from(res);
      }
    } catch (e, st) {
      debugPrint('refreshEntitlement RPC failed: $e');
      debugPrint('$st');
      final row = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      data = row == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(row as Map);
    }

    final tier = (data['subscription_tier'] ?? 'pending')
        .toString()
        .toLowerCase();
    final status =
        (data['subscription_status'] ??
                (tier == 'pending' ? 'inactive' : 'active'))
            .toString()
            .toLowerCase();
    final renewsAt = DateTime.tryParse(
      (data['subscription_renews_at'] ?? '').toString(),
    );
    final expiresAt = DateTime.tryParse(
      (data['subscription_expires_at'] ?? '').toString(),
    );

    _entitlement = SubscriptionEntitlement(
      tier: tier,
      status: status,
      renewsAt: renewsAt,
      expiresAt: expiresAt,
    );
    notifyListeners();
  }

  Future<void> restorePurchases() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      await _loadAndroidOldPurchase();
      await refreshEntitlement();
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> purchaseProduct(String productId) async {
    final product = _productsById[productId];
    if (product == null) return;

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      late final PurchaseParam param;
      if (Platform.isAndroid &&
          _androidOldPurchase is GooglePlayPurchaseDetails) {
        param = GooglePlayPurchaseParam(
          productDetails: product,
          changeSubscriptionParam: ChangeSubscriptionParam(
            oldPurchaseDetails:
                _androidOldPurchase as GooglePlayPurchaseDetails,
            replacementMode: ReplacementMode.withTimeProration,
          ),
        );
      } else {
        param = PurchaseParam(productDetails: product);
      }
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> openManageSubscriptionPage() async {
    Uri uri;
    if (Platform.isIOS) {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      final pkg = await PackageInfo.fromPlatform();
      uri = Uri.parse(
        'https://play.google.com/store/account/subscriptions?package=${pkg.packageName}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _busy = true;
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _busy = false;
        _error = purchase.error?.message ?? 'Purchase failed';
        notifyListeners();
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final verified = await _verifyAndSync(purchase);
        if (!verified) {
          _error =
              'Purchase received but could not be verified. Please try Restore Purchases.';
        }
        _busy = false;
        notifyListeners();
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verifyAndSync(PurchaseDetails purchase) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        verifyFunctionName,
        body: <String, dynamic>{
          'user_id': user.id,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'product_id': purchase.productID,
          'purchase_id': purchase.purchaseID,
          'transaction_date': purchase.transactionDate,
          'verification_data': purchase.verificationData.serverVerificationData,
          'local_verification_data':
              purchase.verificationData.localVerificationData,
          'source': purchase.verificationData.source,
        },
      );
      final payload = res.data;
      final ok = payload is Map && payload['verified'] == true;
      if (ok) {
        await refreshEntitlement();
        await _loadAndroidOldPurchase();
      }
      return ok;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<void> _loadAndroidOldPurchase() async {
    if (!Platform.isAndroid) return;
    try {
      final addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) return;
      final ids = catalog.map((e) => e.productId).toSet();
      for (final p in response.pastPurchases.reversed) {
        if (!ids.contains(p.productID)) continue;
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          _androidOldPurchase = p;
          break;
        }
      }
    } catch (_) {
      // no-op: replacement is optional and fallback is normal purchase
    }
  }
}
