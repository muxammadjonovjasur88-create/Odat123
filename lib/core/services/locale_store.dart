import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The three languages Flowa ships with, in display order.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('uz'),
];

/// Falls back to English for any unsupported device language.
const Locale kFallbackLocale = Locale('en');

/// Native (untranslated) name for each language — always shown in its own
/// script so a user can recognise it regardless of the current app language.
String localeNativeName(String code) => switch (code) {
  'ru' => 'Русский',
  'uz' => "O'zbek",
  _ => 'English',
};

/// Hive-backed persistence for the chosen app language, so the choice survives
/// a restart. easy_localization's own `saveLocale` is disabled; this is the
/// single source of truth (read once in `main` to seed `startLocale`).
class LocaleStore {
  LocaleStore._();

  static const _boxName = 'flowa_locale';
  static const _key = 'code';

  static Box? _box;

  /// Opens the box once, before `runApp`.
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// The saved language code ('en' | 'ru' | 'uz'), or null if never set.
  static String? savedCode() => _box?.get(_key) as String?;

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
        : 'en';
  }

  /// The saved locale, or null to let easy_localization fall back to the
  /// device language (and then to [kFallbackLocale]).
  static Locale? savedLocale() {
    final code = savedCode();
    return code == null ? null : Locale(code);
  }

  static Future<void> save(String code) async => _box?.put(_key, code);
}
