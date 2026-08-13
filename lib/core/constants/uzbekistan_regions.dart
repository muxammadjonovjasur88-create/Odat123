/// Canonical list of Uzbekistan's 14 administrative units.
///
/// Used to normalise any geocoding string (English, Uzbek, Russian) into a
/// single well-known value so leaderboard queries are consistent.
enum UzRegion {
  toshkent,
  toshkentViloyat,
  samarqand,
  buxoro,
  navoiy,
  fargona,
  andijon,
  namangan,
  qashqadaryo,
  surxondaryo,
  jizzax,
  sirdaryo,
  xorazm,
  qoraqalpogiston;

  // ---------------------------------------------------------------------------
  // Display name (Uzbek)
  // ---------------------------------------------------------------------------

  String get displayName => switch (this) {
        UzRegion.toshkent => 'Toshkent shahri',
        UzRegion.toshkentViloyat => 'Toshkent viloyati',
        UzRegion.samarqand => 'Samarqand',
        UzRegion.buxoro => 'Buxoro',
        UzRegion.navoiy => 'Navoiy',
        UzRegion.fargona => "Farg'ona",
        UzRegion.andijon => 'Andijon',
        UzRegion.namangan => 'Namangan',
        UzRegion.qashqadaryo => 'Qashqadaryo',
        UzRegion.surxondaryo => 'Surxondaryo',
        UzRegion.jizzax => 'Jizzax',
        UzRegion.sirdaryo => 'Sirdaryo',
        UzRegion.xorazm => "Xorazm",
        UzRegion.qoraqalpogiston => "Qoraqalpog'iston",
      };

  /// Firestore-safe key stored in `users/{uid}.region`.
  String get firestoreKey => switch (this) {
        UzRegion.toshkent => 'TOSHKENT_CITY',
        UzRegion.toshkentViloyat => 'TOSHKENT_REGION',
        UzRegion.samarqand => 'SAMARQAND',
        UzRegion.buxoro => 'BUXORO',
        UzRegion.navoiy => 'NAVOIY',
        UzRegion.fargona => 'FARGONA',
        UzRegion.andijon => 'ANDIJON',
        UzRegion.namangan => 'NAMANGAN',
        UzRegion.qashqadaryo => 'QASHQADARYO',
        UzRegion.surxondaryo => 'SURXONDARYO',
        UzRegion.jizzax => 'JIZZAX',
        UzRegion.sirdaryo => 'SIRDARYO',
        UzRegion.xorazm => 'XORAZM',
        UzRegion.qoraqalpogiston => 'QORAQALPOGISTON',
      };

  // ---------------------------------------------------------------------------
  // Normalisation — maps any geocoding string to a canonical UzRegion.
  // ---------------------------------------------------------------------------

  /// Attempts to map [raw] (English, Uzbek, or Russian geocoding response)
  /// to a [UzRegion]. Returns null if the string cannot be matched.
  ///
  /// Examples that all map to [UzRegion.navoiy]:
  ///   - "Navoiy Region"
  ///   - "navoiy viloyati"
  ///   - "Navoi"
  ///   - "Nawoiy"
  static UzRegion? fromGeocodingString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.toLowerCase().trim();
    return _normalize(s);
  }

  /// Restores a [UzRegion] from a Firestore key stored in `users/{uid}.region`.
  static UzRegion? fromFirestoreKey(String? key) {
    if (key == null) return null;
    for (final r in UzRegion.values) {
      if (r.firestoreKey == key) return r;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Private matching helpers
  // ---------------------------------------------------------------------------

  static UzRegion? _normalize(String s) {
    // Tashkent city — must come before Tashkent Region
    if (_matches(s, [
      'tashkent city',
      'toshkent shahri',
      'tashkent shahri',
      'город ташкент',
      'г. ташкент',
    ])) { return UzRegion.toshkent; }

    // Tashkent Region
    if (_matchesAny(s, ['toshkent', 'tashkent', 'ташкент'])) {
      return UzRegion.toshkentViloyat;
    }

    if (_matchesAny(s, ['samarqand', 'samarkand', 'самарканд'])) {
      return UzRegion.samarqand;
    }

    if (_matchesAny(s, ['buxoro', 'bukhara', 'bukhoro', 'бухара', 'бухоро'])) {
      return UzRegion.buxoro;
    }

    if (_matchesAny(s, ['navoiy', 'navoi', 'nawoi', 'навои', 'навоий'])) {
      return UzRegion.navoiy;
    }

    if (_matchesAny(s, ['farg\'ona', 'fergana', 'farghona', 'fargona', 'фергана', 'фарғона'])) {
      return UzRegion.fargona;
    }

    if (_matchesAny(s, ['andijon', 'andijan', 'андижан', 'андижон'])) {
      return UzRegion.andijon;
    }

    if (_matchesAny(s, ['namangan', 'наманган'])) {
      return UzRegion.namangan;
    }

    if (_matchesAny(s, ['qashqadaryo', 'kashkadarya', 'кашкадарья', 'qashqadarya'])) {
      return UzRegion.qashqadaryo;
    }

    if (_matchesAny(s, ['surxondaryo', 'surkhandarya', 'сурхандарья', 'surhandarya'])) {
      return UzRegion.surxondaryo;
    }

    if (_matchesAny(s, ['jizzax', 'jizzakh', 'jizakh', 'джизак', 'жиззах'])) {
      return UzRegion.jizzax;
    }

    if (_matchesAny(s, ['sirdaryo', 'syrdarya', 'сырдарья', 'sirdarya'])) {
      return UzRegion.sirdaryo;
    }

    if (_matchesAny(s, ['xorazm', 'khorezm', 'khorazm', 'хорезм', 'хоразм'])) {
      return UzRegion.xorazm;
    }

    if (_matchesAny(s, [
      'qoraqalpog\'iston',
      'qoraqalpogiston',
      'karakalpakstan',
      'karakalpakiya',
      'каракалпакстан',
      'qaraqalpaqstan',
    ])) {
      return UzRegion.qoraqalpogiston;
    }

    return null;
  }

  /// Returns true if [s] exactly matches any of [candidates].
  static bool _matches(String s, List<String> candidates) =>
      candidates.contains(s);

  /// Returns true if [s] *contains* any keyword in [keywords] (handles
  /// "Navoiy Region", "Navoiy viloyati", "navoiy" all at once).
  static bool _matchesAny(String s, List<String> keywords) =>
      keywords.any((kw) => s.contains(kw));
}
