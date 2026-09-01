import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/subscription_repository.dart';
import '../../domain/subscription_models.dart';

final userSubscriptionProvider = NotifierProvider<SubscriptionNotifier, UserSubscription>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends Notifier<UserSubscription> {
  @override
  UserSubscription build() {
    final repo = ref.watch(subscriptionRepositoryProvider);
    return repo.getSubscription();
  }

  Future<void> start7DayTrial(SubscriptionPlanTier tier) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.start7DayTrial(tier);
    state = repo.getSubscription();
  }

  Future<void> activateSubscription(SubscriptionPlanTier tier, BillingCycle cycle) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.activateSubscription(tier, cycle);
    state = repo.getSubscription();
  }

  Future<void> restorePurchases() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await repo.restorePurchases();
    state = repo.getSubscription();
  }
}
