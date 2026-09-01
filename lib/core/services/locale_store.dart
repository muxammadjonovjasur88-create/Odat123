import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The languages Odat ships with, in display order.
const List<Locale> kSupportedLocales = [
  Locale('uz'),
  Locale('ru'),
  Locale('en'),
];

/// Falls back to Uzbek for any unsupported device language.
const Locale kFallbackLocale = Locale('uz');

/// Native (untranslated) name for each language — always shown in its own
/// script so a user can recognise it regardless of the current app language.
String localeNativeName(String code) => switch (code) {
  'ru' => 'Русский',
  'en' => 'English',
  _ => "O'zbek",
};

/// Hive-backed persistence for the chosen app language, so the choice survives
/// a restart. easy_localization's own `saveLocale` is disabled; this is the
/// single source of truth (read once in `main` to seed `startLocale`).
class LocaleStore {
  LocaleStore._();

  static const _boxName = 'odat_locale';
  static const _key = 'code';

  static Box? _box;

  /// Opens the box once, before `runApp`.
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// The saved language code ('en' | 'ru' | 'uz'), defaulting to 'uz'.
  static String savedCode() => _box?.get(_key) as String? ?? 'uz';

  /// The language actually in effect — the saved choice, else the device
  /// language when it's one of the three, else English. Used to tell the native
  /// blocking overlay which language to render, so it never falls back to
  /// English when the user is really seeing Russian or Uzbek.
  static String effectiveCode() {
    final saved = savedCode();
    if (saved != null) return saved;
    final device =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return kSupportedLocales.any((l) => l.languageCode == device)
        ? device
        : 'uz';
  }

  /// The saved locale, defaulting to Uzbek if never set.
  static Locale savedLocale() {
    return Locale(savedCode());
  }

  static Future<void> save(String code) async => _box?.put(_key, code);

  // Har safar ochilganda intro ko'rsatmaslik uchun Hive saqlash
  static bool hasSeenIntro() => _box?.get('has_seen_intro_v2') as bool? ?? false;
  static Future<void> setHasSeenIntro() async => _box?.put('has_seen_intro_v2', true);

  // Telegram Obuna kvesti holati
  static bool hasClaimedTelegramQuest() => _box?.get('claimed_tg_quest') as bool? ?? false;
  static Future<void> setClaimedTelegramQuest() async => _box?.put('claimed_tg_quest', true);

  // Ruxsatnomalar holati
  static bool hasGrantedStartupPermissions() => _box?.get('granted_startup_permissions') as bool? ?? false;
  static Future<void> setGrantedStartupPermissions() async => _box?.put('granted_startup_permissions', true);
}
