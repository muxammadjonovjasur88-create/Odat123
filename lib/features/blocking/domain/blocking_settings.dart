import 'package:cloud_firestore/cloud_firestore.dart';

/// The user's app-blocking preferences, stored at
/// `users/{uid}/settings/blocking`.
class BlockingSettings {
  const BlockingSettings({
    this.alwaysBlock = true,
    this.blockedPackages = const {},
    this.strictMode = false,
  });

  /// Block the selected apps automatically whenever a focus session is active.
  final bool alwaysBlock;

  /// Package names of the apps the user chose to block.
  final Set<String> blockedPackages;

  /// When true, blocked apps are a HARD wall (the old behavior). When false
  /// (the default), they show a gentle "soft friction" reminder the user can
  /// choose to bypass — so no one feels imprisoned.
  final bool strictMode;

  bool isBlocked(String packageName) => blockedPackages.contains(packageName);

  BlockingSettings copyWith({
    bool? alwaysBlock,
    Set<String>? blockedPackages,
    bool? strictMode,
  }) => BlockingSettings(
    alwaysBlock: alwaysBlock ?? this.alwaysBlock,
    blockedPackages: blockedPackages ?? this.blockedPackages,
    strictMode: strictMode ?? this.strictMode,
  );

  Map<String, dynamic> toMap() => {
    'alwaysBlock': alwaysBlock,
    'blockedPackages': blockedPackages.toList(),
    'strictMode': strictMode,
  };

  factory BlockingSettings.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return BlockingSettings(
      alwaysBlock: (data['alwaysBlock'] as bool?) ?? true,
      blockedPackages:
          ((data['blockedPackages'] as List?)?.cast<String>() ?? const [])
              .toSet(),
      strictMode: (data['strictMode'] as bool?) ?? false,
    );
  }
}
