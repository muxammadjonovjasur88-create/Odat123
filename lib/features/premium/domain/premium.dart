import 'package:flutter/material.dart';

/// Master switch for the entire Premium system.
const bool kPremiumEnabled = true;

/// Google Play In-App Subscription Product IDs
const String kPremiumMonthlySku = 'odat_premium_monthly';
const String kPremiumYearlySku = 'odat_premium_yearly';

/// Free users may generate this many AI plans per calendar day before the
/// paywall appears.
const int kFreeAiPlansPerDay = 3;

/// Muted gold accent for premium touches — calm enough to sit with the Zen
/// cream/sage palette without shouting.
const Color kPremiumGold = Color(0xFFC9A24B);
const Color kPremiumGoldSoft = Color(0xFFEFE3C4);

/// Pricing in UZS (O'zbek so'mi)
const int kMonthlyPriceUzs = 40000;
const int kYearlyPriceUzs = 390000;

// Display-only pricing keys resolved with `.tr()`
const String kMonthlyPriceLabel = 'premium.price_monthly';
const String kMonthlyPeriodLabel = 'premium.per_month';
const String kYearlyPriceLabel = 'premium.price_yearly';
const String kYearlyPeriodLabel = 'premium.per_year';
const String kYearlySaveLabel = 'premium.save_pct';

/// Translation key for the message shown when a free user hits the daily AI
/// limit (resolved with `.tr()` at the call site).
const String kAiLimitMessage = 'premium.ai_limit_msg';

/// One premium benefit, shown with an icon on the paywall. [title]/[subtitle]
/// are translation keys resolved with `.tr()` when rendered.
class PremiumBenefit {
  const PremiumBenefit(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

const List<PremiumBenefit> kPremiumBenefits = [
  PremiumBenefit(
    Icons.auto_awesome_rounded,
    'premium.benefit_ai_title',
    'premium.benefit_ai_sub',
  ),
  PremiumBenefit(
    Icons.insights_rounded,
    'premium.benefit_stats_title',
    'premium.benefit_stats_sub',
  ),
  PremiumBenefit(
    Icons.self_improvement_rounded,
    'premium.benefit_coach_title',
    'premium.benefit_coach_sub',
  ),
  PremiumBenefit(
    Icons.palette_outlined,
    'premium.benefit_cosmetics_title',
    'premium.benefit_cosmetics_sub',
  ),
];

/// The two subscription options offered on the paywall.
enum PremiumPlan {
  monthly,
  yearly;

  int get priceUzs => this == PremiumPlan.monthly ? kMonthlyPriceUzs : kYearlyPriceUzs;

  String get formattedPriceUzs => this == PremiumPlan.monthly ? '40 000 so\'m' : '390 000 so\'m';

  Duration get duration => this == PremiumPlan.monthly ? const Duration(days: 30) : const Duration(days: 365);
}

/// Supported payment gateways for Odat Premium
enum PremiumPaymentMethod {
  payme(
    title: 'Payme',
    subtitle: 'Karta orqali tezkor to\'lov (UzCard / Humo)',
    brandColor: Color(0x7B2FFFCC),
    icon: Icons.account_balance_wallet_rounded,
  ),
  click(
    title: 'Click',
    subtitle: 'Click Up / Click Evolution orqali',
    brandColor: Color(0xFF007AFF),
    icon: Icons.touch_app_rounded,
  ),
  uzumCard(
    title: 'Uzum Bank / Karta',
    subtitle: 'Humo, UzCard, Visa & MasterCard',
    brandColor: Color(0xFF7000FF),
    icon: Icons.credit_card_rounded,
  ),
  googlePlay(
    title: 'Google Play',
    subtitle: 'Google Play hisobingiz orqali obuna',
    brandColor: Color(0xFF00875A),
    icon: Icons.play_arrow_rounded,
  );

  const PremiumPaymentMethod({
    required this.title,
    required this.subtitle,
    required this.brandColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color brandColor;
  final IconData icon;
}
