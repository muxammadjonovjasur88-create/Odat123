import '../../../core/utils/formatting.dart';

/// 1 USD ≈ 12 800 UZS (market rate — update as needed)
const double kUsdToUzs = 12800.0;
class FenixCoinPackage {
  const FenixCoinPackage({
    required this.id,
    required this.coins,
    required this.priceUzs,
    this.badgeText,
    this.bonusPct = 0,
    this.isPopular = false,
    this.isBestValue = false,
    this.emoji = '🪙',
  });

  final String id;
  final int coins;

  /// Price in UZS (O'zbek so'mi)
  final int priceUzs;

  final String? badgeText;
  final int bonusPct;
  final bool isPopular;
  final bool isBestValue;
  final String emoji;

  /// Total coins including bonus
  int get totalCoins => bonusPct > 0 ? (coins * (1 + bonusPct / 100)).round() : coins;

  String get formattedCoins {
    return formatCompactNumber(totalCoins);
  }

  String get formattedPrice {
    if (priceUzs >= 1000000) {
      return '${(priceUzs / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}m so\'m';
    } else if (priceUzs >= 1000) {
      return '${(priceUzs / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k so\'m';
    }
    return '$priceUzs so\'m';
  }

  /// Value per 1000 coins in UZS (lower = better deal)
  double get valueScore => priceUzs / (totalCoins / 1000.0);
}

/// Official Fenix Coin Store Packages — priced in UZS
const List<FenixCoinPackage> kFenixCoinPackages = [
  FenixCoinPackage(
    id: 'fenix_100',
    coins: 100,
    priceUzs: 12000,
    emoji: '🪙',
  ),
  FenixCoinPackage(
    id: 'fenix_300',
    coins: 300,
    priceUzs: 29000,
    badgeText: '+5% BONUS',
    bonusPct: 5,
    emoji: '💰',
  ),
  FenixCoinPackage(
    id: 'fenix_700',
    coins: 700,
    priceUzs: 59000,
    badgeText: '+10% BONUS',
    bonusPct: 10,
    emoji: '💎',
  ),
  FenixCoinPackage(
    id: 'fenix_1500',
    coins: 1500,
    priceUzs: 99000,
    badgeText: '+15% BONUS',
    bonusPct: 15,
    emoji: '✨',
  ),
  FenixCoinPackage(
    id: 'fenix_3000',
    coins: 3000,
    priceUzs: 179000,
    badgeText: '🔥 ENG OMMABOP',
    bonusPct: 25,
    isPopular: true,
    emoji: '🔥',
  ),
  FenixCoinPackage(
    id: 'fenix_6000',
    coins: 6000,
    priceUzs: 299000,
    badgeText: '+50% BONUS',
    bonusPct: 50,
    emoji: '⚡',
  ),
  FenixCoinPackage(
    id: 'fenix_12000',
    coins: 12000,
    priceUzs: 499000,
    badgeText: '+80% BONUS',
    bonusPct: 80,
    isBestValue: true,
    emoji: '👑',
  ),
  FenixCoinPackage(
    id: 'fenix_25000',
    coins: 25000,
    priceUzs: 899000,
    badgeText: '💎 MEGA FOYDALI',
    bonusPct: 100,
    isBestValue: true,
    emoji: '💎',
  ),
];
