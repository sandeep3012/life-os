import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/application/sync_providers.dart';
import 'revenuecat_config.dart';
import 'revenuecat_purchases.dart';

/// One way to pay for PersonalOS Plus, as the store describes it.
class PlusOffer {
  const PlusOffer({
    required this.id,
    required this.title,
    required this.price,
    this.note,
  });

  final String id;

  /// "Yearly", "Monthly".
  final String title;

  /// The store's own price string, in the buyer's currency.
  final String price;

  /// "7-day free trial", "Save 40%".
  final String? note;
}

/// Buying and restoring PersonalOS Plus through the phone's app store.
///
/// The store is the only place a subscription can be bought (its rules, not
/// ours), and the server — not this class — decides what an account may
/// use: a purchase reaches it as a notification from the store, and the app
/// then re-reads its plan.
abstract class PurchaseService {
  /// False until store billing is connected in this build.
  bool get available;

  Future<List<PlusOffer>> offers();

  /// Starts the store's purchase sheet. True once the store confirms it;
  /// throws [PurchaseCancelled] when the person backs out.
  Future<bool> buy(PlusOffer offer);

  /// Re-attaches a subscription bought earlier with this store account.
  Future<bool> restore();

  /// Opens the store's own page for changing or cancelling.
  Future<void> manage();
}

/// The person closed the store's sheet without buying. Not a failure:
/// nothing needs saying.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

/// Billing isn't connected in this build: nothing can be bought, and nothing
/// pretends otherwise.
class UnavailablePurchases implements PurchaseService {
  const UnavailablePurchases();

  @override
  bool get available => false;

  @override
  Future<List<PlusOffer>> offers() async => const [];

  @override
  Future<bool> buy(PlusOffer offer) async => false;

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> manage() async {}
}

/// RevenueCat when this build has a key for the phone's store (see
/// [RevenueCatConfig]); otherwise nothing is for sale.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final key = RevenueCatConfig.apiKey;
  if (key == null) return const UnavailablePurchases();
  return RevenueCatPurchases(
    apiKey: key,
    // A subscription belongs to the account, so it's bought under the
    // account's id: that's how the server knows whose it is.
    userId: () => ref.read(syncSessionProvider)?.userId,
  );
});
