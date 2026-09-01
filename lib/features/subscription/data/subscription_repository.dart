import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/subscription_models.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

class SubscriptionRepository {
  UserSubscription _current = UserSubscription.trialPro(days: 6);

  UserSubscription getSubscription() => _current;

  Future<void> start7DayTrial(SubscriptionPlanTier tier) async {
    if (tier == SubscriptionPlanTier.family) {
      _current = UserSubscription.trialFamily(days: 7);
    } else {
      _current = UserSubscription.trialPro(days: 7);
    }
  }

  Future<void> activateSubscription(SubscriptionPlanTier tier, BillingCycle cycle) async {
    _current = UserSubscription(
      tier: tier,
      state: tier == SubscriptionPlanTier.family ? SubscriptionState.familyActive : SubscriptionState.proActive,
      billingCycle: cycle,
      expiresAt: DateTime.now().add(cycle == BillingCycle.yearly ? const Duration(days: 365) : const Duration(days: 30)),
    );
  }

  Future<void> restorePurchases() async {
    // In production, queries Google Play / StoreKit billing receipts.
  }
}
