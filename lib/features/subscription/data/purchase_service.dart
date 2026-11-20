import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Starts the store's purchase sheet. True once the store confirms it.
  Future<bool> buy(PlusOffer offer);

  /// Re-attaches a subscription bought earlier with this store account.
  Future<bool> restore();

  /// Opens the store's own page for changing or cancelling.
  Future<void> manage();
}

/// Billing isn't connected yet: nothing can be bought, and nothing pretends
/// otherwise.
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

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => const UnavailablePurchases(),
);
