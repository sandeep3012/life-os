import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'purchase_service.dart';
import 'revenuecat_config.dart';

/// PersonalOS Plus bought through RevenueCat, which talks to Google Play
/// (or, in debug builds, to its own Test Store).
///
/// This class only *sells*. What an account may use is still the server's
/// call: RevenueCat tells our `revenuecat-webhook` function about the
/// purchase, that writes the `entitlements` row, and the app re-reads its
/// plan from there. A "yes" from this class alone unlocks nothing.
class RevenueCatPurchases implements PurchaseService {
  RevenueCatPurchases({required this.apiKey, required this.userId});

  final String apiKey;

  /// The signed-in account's id, or null when nobody is signed in.
  final String? Function() userId;

  /// The packages last offered, by id, so [buy] purchases exactly what was
  /// shown.
  final _packages = <String, Package>{};

  @override
  bool get available => true;

  /// Makes sure RevenueCat is running as the signed-in account.
  Future<void> _ready() async {
    final id = userId();
    if (id == null) throw StateError('Sign in before buying.');
    if (!await Purchases.isConfigured) {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = id);
    } else if (await Purchases.appUserID != id) {
      await Purchases.logIn(id);
    }
  }

  bool _hasPlus(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatConfig.entitlement);

  @override
  Future<List<PlusOffer>> offers() async {
    await _ready();
    final offerings = await Purchases.getOfferings();
    final packages = [...?offerings.current?.availablePackages]
      // Yearly first: it's the one most people should take.
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    _packages
      ..clear()
      ..addEntries(packages.map((p) => MapEntry(p.identifier, p)));
    return [for (final p in packages) offerFor(p)];
  }

  static int _order(Package p) => switch (p.packageType) {
    PackageType.annual => 0,
    PackageType.sixMonth => 1,
    PackageType.threeMonth => 2,
    PackageType.twoMonth => 3,
    PackageType.monthly => 4,
    PackageType.weekly => 5,
    _ => 6,
  };

  @visibleForTesting
  static PlusOffer offerFor(Package package) {
    final product = package.storeProduct;
    final trial = product.defaultOption?.freePhase != null;
    final perMonth = product.pricePerMonthString;
    final yearly = package.packageType == PackageType.annual;
    return PlusOffer(
      id: package.identifier,
      title: switch (package.packageType) {
        PackageType.annual => 'Yearly',
        PackageType.sixMonth => '6 months',
        PackageType.threeMonth => '3 months',
        PackageType.twoMonth => '2 months',
        PackageType.monthly => 'Monthly',
        PackageType.weekly => 'Weekly',
        PackageType.lifetime => 'Lifetime',
        _ => product.title,
      },
      price: product.priceString,
      note: trial
          ? 'Free trial first'
          : yearly && perMonth != null
          ? '$perMonth a month'
          : null,
    );
  }

  @override
  Future<bool> buy(PlusOffer offer) async {
    await _ready();
    final package = _packages[offer.id];
    if (package == null) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _hasPlus(result.customerInfo);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<bool> restore() async {
    await _ready();
    return _hasPlus(await Purchases.restorePurchases());
  }

  @override
  Future<void> manage() async {
    String? url;
    try {
      await _ready();
      url = (await Purchases.getCustomerInfo()).managementURL;
    } on Object {
      // Fall through to the store's own subscriptions page.
    }
    final target = Uri.parse(
      url ??
          'https://play.google.com/store/account/subscriptions'
              '?package=com.sandit.personalos',
    );
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }
}
