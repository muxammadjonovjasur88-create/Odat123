import 'package:flutter/foundation.dart';

/// Available subscription plan tiers.
enum SubscriptionPlanTier {
  free,
  pro,
  family,
}

/// Billing cycle for paid subscriptions.
enum BillingCycle {
  monthly,
  yearly,
}

/// Detailed subscription lifecycle state.
enum SubscriptionState {
  free,
  trialPro,
  trialFamily,
  proActive,
  familyActive,
  canceledButActive,
  expired,
}

/// Centralized entitlement model determining feature access.
@immutable
class UserSubscription {
  const UserSubscription({
    required this.tier,
    required this.state,
    required this.billingCycle,
    this.trialDaysRemaining = 0,
    this.expiresAt,
  });

  final SubscriptionPlanTier tier;
  final SubscriptionState state;
  final BillingCycle billingCycle;
  final int trialDaysRemaining;
  final DateTime? expiresAt;

  bool get isPremium => tier == SubscriptionPlanTier.pro || tier == SubscriptionPlanTier.family;
  bool get isFamily => tier == SubscriptionPlanTier.family;
  bool get isTrial => state == SubscriptionState.trialPro || state == SubscriptionState.trialFamily;

  // Feature Entitlement Checks
  bool get canUseAdvancedAI => isPremium;
  bool get canUseFullPlay2 => isPremium;
  bool get canUseAdvancedDiscipline => isPremium;
  bool get canUseFamilyMode => isFamily;
  bool get canUseParentReports => isFamily;
  bool get canCreateFamilyMissions => isFamily;

  factory UserSubscription.free() => const UserSubscription(
        tier: SubscriptionPlanTier.free,
        state: SubscriptionState.free,
        billingCycle: BillingCycle.monthly,
      );

  factory UserSubscription.trialPro({int days = 7}) => UserSubscription(
        tier: SubscriptionPlanTier.pro,
        state: SubscriptionState.trialPro,
        billingCycle: BillingCycle.monthly,
        trialDaysRemaining: days,
        expiresAt: DateTime.now().add(Duration(days: days)),
      );

  factory UserSubscription.trialFamily({int days = 7}) => UserSubscription(
        tier: SubscriptionPlanTier.family,
        state: SubscriptionState.trialFamily,
        billingCycle: BillingCycle.monthly,
        trialDaysRemaining: days,
        expiresAt: DateTime.now().add(Duration(days: days)),
      );
}

/// Plan pricing and description metadata.
@immutable
class PlanPricing {
  const PlanPricing({
    required this.tier,
    required this.monthlyPriceUzs,
    required this.yearlyPriceUzs,
    required this.yearlyEquivalentMonthlyUzs,
    required this.has7DayTrial,
  });

  final SubscriptionPlanTier tier;
  final int monthlyPriceUzs;
  final int yearlyPriceUzs;
  final int yearlyEquivalentMonthlyUzs;
  final bool has7DayTrial;

  static const pro = PlanPricing(
    tier: SubscriptionPlanTier.pro,
    monthlyPriceUzs: 40000,
    yearlyPriceUzs: 390000,
    yearlyEquivalentMonthlyUzs: 32500,
    has7DayTrial: true,
  );

  static const family = PlanPricing(
    tier: SubscriptionPlanTier.family,
    monthlyPriceUzs: 79000,
    yearlyPriceUzs: 690000,
    yearlyEquivalentMonthlyUzs: 57500,
    has7DayTrial: true,
  );
}
