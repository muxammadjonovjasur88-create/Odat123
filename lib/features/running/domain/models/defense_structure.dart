import 'package:flutter/foundation.dart';

/// Defense Tower Tier definition for shop and progression
class DefenseTowerTier {
  const DefenseTowerTier({
    required this.level,
    required this.name,
    required this.costPoints,
    required this.hp,
    required this.maxHp,
    required this.attackPower,
    required this.defensePower,
    required this.icon,
    required this.description,
  });

  final int level;
  final String name;
  final int costPoints;
  final int hp;
  final int maxHp;
  final int attackPower;
  final int defensePower;
  final String icon;
  final String description;
}

/// Global Defense Shop Configurations (Configurable economy & stats)
abstract final class DefenseShopConfig {
  static const List<DefenseTowerTier> tiers = [
    DefenseTowerTier(
      level: 1,
      name: 'Cyber Post Lv.1',
      costPoints: 300,
      hp: 120,
      maxHp: 120,
      attackPower: 25,
      defensePower: 20,
      icon: '🛡️',
      description: 'Boshlang‘ich himoya minorasi. Hudud chegarasini qo‘riqlaydi.',
    ),
    DefenseTowerTier(
      level: 2,
      name: 'Neon Fortress Lv.2',
      costPoints: 750,
      hp: 250,
      maxHp: 250,
      attackPower: 55,
      defensePower: 45,
      icon: '⚡',
      description: 'Kuchsiz hujumlarni osonlikcha qaytaruvchi lazer minorasi.',
    ),
    DefenseTowerTier(
      level: 3,
      name: 'Titan Citadel Lv.3',
      costPoints: 1500,
      hp: 450,
      maxHp: 450,
      attackPower: 110,
      defensePower: 90,
      icon: '🏰',
      description: 'Yuqori quvvatli mudofaa istehkomi. Katta radiusni himoyalaydi.',
    ),
    DefenseTowerTier(
      level: 4,
      name: 'Quantum Bastion Lv.4',
      costPoints: 3000,
      hp: 750,
      maxHp: 750,
      attackPower: 200,
      defensePower: 160,
      icon: '🔮',
      description: 'Dushman hujumini zaiflashtiruvchi kvant to‘siq tizimi.',
    ),
    DefenseTowerTier(
      level: 5,
      name: 'Fenix Nexus Lv.5',
      costPoints: 6000,
      hp: 1200,
      maxHp: 1200,
      attackPower: 350,
      defensePower: 280,
      icon: '👑',
      description: 'Afsonaviy ODAT himoya minorasi. Hududni to‘liq yengilmas qiladi.',
    ),
  ];

  static DefenseTowerTier getTier(int level) {
    if (level < 1) return tiers.first;
    if (level > tiers.length) return tiers.last;
    return tiers[level - 1];
  }

  static int getUpgradeCost(int currentLevel) {
    if (currentLevel >= tiers.length) return 0;
    return tiers[currentLevel].costPoints;
  }
}

/// Represents an active defensive structure placed inside an owned territory.
@immutable
class DefenseStructure {
  const DefenseStructure({
    required this.id,
    required this.territoryId,
    required this.ownerId,
    required this.level,
    required this.latitude,
    required this.longitude,
    required this.hp,
    required this.maxHp,
    required this.attackPower,
    required this.defensePower,
    required this.placedAt,
    this.name = 'Cyber Tower',
    this.icon = '🛡️',
  });

  final String id;
  final String territoryId;
  final String ownerId;
  final int level;
  final double latitude;
  final double longitude;
  final int hp;
  final int maxHp;
  final int attackPower;
  final int defensePower;
  final DateTime placedAt;
  final String name;
  final String icon;

  double get hpPercent => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'territoryId': territoryId,
        'ownerId': ownerId,
        'level': level,
        'latitude': latitude,
        'longitude': longitude,
        'hp': hp,
        'maxHp': maxHp,
        'attackPower': attackPower,
        'defensePower': defensePower,
        'placedAt': placedAt.toIso8601String(),
        'name': name,
        'icon': icon,
      };

  factory DefenseStructure.fromMap(Map<String, dynamic> map, {String? id}) {
    final lvl = (map['level'] as num?)?.toInt() ?? 1;
    final tier = DefenseShopConfig.getTier(lvl);

    return DefenseStructure(
      id: id ?? (map['id'] as String? ?? ''),
      territoryId: map['territoryId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      level: lvl,
      latitude: ((map['latitude'] ?? map['lat'] ?? 0.0) as num).toDouble(),
      longitude: ((map['longitude'] ?? map['lng'] ?? 0.0) as num).toDouble(),
      hp: (map['hp'] as num?)?.toInt() ?? tier.hp,
      maxHp: (map['maxHp'] as num?)?.toInt() ?? tier.maxHp,
      attackPower: (map['attackPower'] as num?)?.toInt() ?? tier.attackPower,
      defensePower: (map['defensePower'] as num?)?.toInt() ?? tier.defensePower,
      placedAt: map['placedAt'] != null
          ? (map['placedAt'] is String
              ? DateTime.tryParse(map['placedAt'] as String) ?? DateTime.now()
              : DateTime.now())
          : DateTime.now(),
      name: map['name'] as String? ?? tier.name,
      icon: map['icon'] as String? ?? tier.icon,
    );
  }

  DefenseStructure copyWith({
    int? level,
    int? hp,
    int? maxHp,
    int? attackPower,
    int? defensePower,
    String? name,
    String? icon,
  }) {
    return DefenseStructure(
      id: id,
      territoryId: territoryId,
      ownerId: ownerId,
      level: level ?? this.level,
      latitude: latitude,
      longitude: longitude,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      attackPower: attackPower ?? this.attackPower,
      defensePower: defensePower ?? this.defensePower,
      placedAt: placedAt,
      name: name ?? this.name,
      icon: icon ?? this.icon,
    );
  }
}
