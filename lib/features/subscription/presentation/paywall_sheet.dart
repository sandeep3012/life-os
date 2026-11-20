import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_fonts.dart';
import '../../sync/application/sync_providers.dart';
import '../application/plan_providers.dart';
import '../data/purchase_service.dart';
import '../domain/plan.dart';

/// Shows what PersonalOS Plus is and how to get it. [from] is the feature the
/// person was reaching for, listed first.
Future<void> showPaywall(BuildContext context, {PlusFeature? from}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => PaywallSheet(from: from),
    );

class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key, this.from});

  final PlusFeature? from;

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  List<PlusOffer> _offers = const [];
  PlusOffer? _chosen;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final purchases = ref.read(purchaseServiceProvider);
    if (purchases.available) {
      purchases.offers().then((offers) {
        if (!mounted) return;
        setState(() {
          _offers = offers;
          _chosen = offers.firstOrNull;
        });
      });
    }
  }

  Future<void> _run(Future<bool> Function() action, String failed) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    var done = false;
    try {
      done = await action();
    } on Object {
      done = false;
    }
    if (!mounted) return;
    if (done) {
      // The store has confirmed; the server hears from it too, and the
      // plan is re-read from there.
      await ref.read(planControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _message = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final plan = ref.watch(planControllerProvider);
    final purchases = ref.watch(purchaseServiceProvider);
    final signedIn = plan.status != PlanStatus.signedOut;
    final features = [
      ?widget.from,
      for (final f in PlusFeature.values)
        if (f != widget.from) f,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, color: colors.accentInk),
                const SizedBox(width: 10),
                // Shrinks to fit rather than overflow on a narrow phone or
                // with a large text size.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PersonalOS Plus',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.isPlus
                  ? "You're on PersonalOS Plus. Thank you for supporting the app."
                  : 'Everything on this phone stays free. Plus adds what '
                        'runs on our servers, and the extra looks.',
              style: TextStyle(height: 1.45, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            for (final feature in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        LucideIcons.circleCheck,
                        size: 18,
                        color: colors.accentInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            feature.detail,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            if (plan.isPlus) ...[
              if (purchases.available)
                OutlinedButton(
                  onPressed: purchases.manage,
                  child: const Text('Manage subscription'),
                ),
            ] else if (!signedIn) ...[
              // A subscription belongs to an account, so it works on every
              // phone that signs in to it.
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(RoutePaths.sync);
                },
                child: const Text('Sign in to get Plus'),
              ),
            ] else if (!purchases.available) ...[
              FilledButton(onPressed: null, child: const Text('Subscribe')),
              const SizedBox(height: 8),
              Text(
                "Subscriptions aren't open yet. They'll be available here "
                'through Google Play.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ] else ...[
              for (final offer in _offers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OfferTile(
                    offer: offer,
                    selected: offer.id == _chosen?.id,
                    onTap: _busy ? null : () => setState(() => _chosen = offer),
                  ),
                ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _busy || _chosen == null
                    ? null
                    : () => _run(
                        () => purchases.buy(_chosen!),
                        "The purchase didn't go through. You haven't been "
                        'charged.',
                      ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Subscribe'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        purchases.restore,
                        'No earlier purchase was found for this store '
                        'account.',
                      ),
                child: const Text('Restore purchases'),
              ),
              Text(
                'Renews automatically until cancelled. Cancel any time in '
                'Google Play.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.warm),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(plan.isPlus ? 'Close' : 'Not now'),
            ),
            if (signedIn)
              Text(
                ref.watch(syncControllerProvider).email ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final PlusOffer offer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (offer.note != null)
                    Text(
                      offer.note!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              offer.price,
              style: TextStyle(
                fontFamily: AppFonts.numeric,
                fontFeatures: AppFonts.tabular,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
