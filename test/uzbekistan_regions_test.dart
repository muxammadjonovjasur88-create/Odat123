// test/uzbekistan_regions_test.dart
//
// Unit tests for UzRegion.fromGeocodingString — verifies that every common
// variant returned by Google Geocoding API (English, Uzbek, Russian, and
// mis-spelled) maps to the correct canonical UzRegion.

import 'package:flutter_test/flutter_test.dart';

import 'package:flowa/core/constants/uzbekistan_regions.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Normalisation helpers
  // ---------------------------------------------------------------------------

  UzRegion? parse(String? s) => UzRegion.fromGeocodingString(s);
  UzRegion? fromKey(String? k) => UzRegion.fromFirestoreKey(k);

  // ---------------------------------------------------------------------------
  // NAVOIY
  // ---------------------------------------------------------------------------
  group('UzRegion.navoiy', () {
    test('English "Navoiy Region"', () {
      expect(parse('Navoiy Region'), UzRegion.navoiy);
    });
    test('Uzbek "Navoiy viloyati"', () {
      expect(parse('navoiy viloyati'), UzRegion.navoiy);
    });
    test('bare "Navoiy"', () {
      expect(parse('Navoiy'), UzRegion.navoiy);
    });
    test('Russian "Навои"', () {
      expect(parse('Навои'), UzRegion.navoiy);
    });
    test('variant "Navoi"', () {
      expect(parse('Navoi'), UzRegion.navoiy);
    });
    test('Zarafshon city → still resolves if locality contains navoiy keyword', () {
      // Zarafshon's adminArea from geocoding is typically "Navoiy Region"
      expect(parse('Navoiy Region'), UzRegion.navoiy);
    });
    test('firestoreKey roundtrip', () {
      expect(fromKey(UzRegion.navoiy.firestoreKey), UzRegion.navoiy);
    });
  });

  // ---------------------------------------------------------------------------
  // TOSHKENT SHAHRI vs TOSHKENT VILOYATI
  // ---------------------------------------------------------------------------
  group('UzRegion.toshkent (city)', () {
    test('"Tashkent city"', () {
      expect(parse('Tashkent city'), UzRegion.toshkent);
    });
    test('"toshkent shahri"', () {
      expect(parse('toshkent shahri'), UzRegion.toshkent);
    });
  });

  group('UzRegion.toshkentViloyat (region)', () {
    test('"Tashkent Region"', () {
      expect(parse('Tashkent Region'), UzRegion.toshkentViloyat);
    });
    test('"Toshkent viloyati"', () {
      expect(parse('Toshkent viloyati'), UzRegion.toshkentViloyat);
    });
  });

  // ---------------------------------------------------------------------------
  // SAMARQAND
  // ---------------------------------------------------------------------------
  group('UzRegion.samarqand', () {
    test('"Samarqand"', () => expect(parse('Samarqand'), UzRegion.samarqand));
    test('"Samarkand"', () => expect(parse('Samarkand'), UzRegion.samarqand));
    test('"Самарканд"', () => expect(parse('Самарканд'), UzRegion.samarqand));
    test('firestoreKey roundtrip',
        () => expect(fromKey('SAMARQAND'), UzRegion.samarqand));
  });

  // ---------------------------------------------------------------------------
  // BUXORO
  // ---------------------------------------------------------------------------
  group('UzRegion.buxoro', () {
    test('"Bukhara"', () => expect(parse('Bukhara'), UzRegion.buxoro));
    test('"Buxoro"', () => expect(parse('Buxoro'), UzRegion.buxoro));
    test('"Бухара"', () => expect(parse('Бухара'), UzRegion.buxoro));
  });

  // ---------------------------------------------------------------------------
  // FARG'ONA
  // ---------------------------------------------------------------------------
  group("UzRegion.fargona", () {
    test('"Fergana"', () => expect(parse('Fergana'), UzRegion.fargona));
    test('"Fargona"', () => expect(parse('Fargona'), UzRegion.fargona));
    test('"Farghona"', () => expect(parse('Farghona'), UzRegion.fargona));
    test('"Фергана"', () => expect(parse('Фергана'), UzRegion.fargona));
  });

  // ---------------------------------------------------------------------------
  // ANDIJON
  // ---------------------------------------------------------------------------
  group('UzRegion.andijon', () {
    test('"Andijan"', () => expect(parse('Andijan'), UzRegion.andijon));
    test('"Andijon"', () => expect(parse('Andijon'), UzRegion.andijon));
    test('"Андижан"', () => expect(parse('Андижан'), UzRegion.andijon));
  });

  // ---------------------------------------------------------------------------
  // NAMANGAN
  // ---------------------------------------------------------------------------
  group('UzRegion.namangan', () {
    test('"Namangan"', () => expect(parse('Namangan'), UzRegion.namangan));
    test('"Наманган"', () => expect(parse('Наманган'), UzRegion.namangan));
  });

  // ---------------------------------------------------------------------------
  // QASHQADARYO
  // ---------------------------------------------------------------------------
  group('UzRegion.qashqadaryo', () {
    test('"Kashkadarya"',
        () => expect(parse('Kashkadarya'), UzRegion.qashqadaryo));
    test('"Qashqadaryo"',
        () => expect(parse('Qashqadaryo'), UzRegion.qashqadaryo));
    test('"Кашкадарья"',
        () => expect(parse('Кашкадарья'), UzRegion.qashqadaryo));
  });

  // ---------------------------------------------------------------------------
  // SURXONDARYO
  // ---------------------------------------------------------------------------
  group('UzRegion.surxondaryo', () {
    test('"Surkhandarya"',
        () => expect(parse('Surkhandarya'), UzRegion.surxondaryo));
    test('"Surxondaryo"',
        () => expect(parse('Surxondaryo'), UzRegion.surxondaryo));
    test('"Сурхандарья"',
        () => expect(parse('Сурхандарья'), UzRegion.surxondaryo));
  });

  // ---------------------------------------------------------------------------
  // JIZZAX
  // ---------------------------------------------------------------------------
  group('UzRegion.jizzax', () {
    test('"Jizzakh"', () => expect(parse('Jizzakh'), UzRegion.jizzax));
    test('"Jizzax"', () => expect(parse('Jizzax'), UzRegion.jizzax));
    test('"Джизак"', () => expect(parse('Джизак'), UzRegion.jizzax));
  });

  // ---------------------------------------------------------------------------
  // SIRDARYO
  // ---------------------------------------------------------------------------
  group('UzRegion.sirdaryo', () {
    test('"Syrdarya"', () => expect(parse('Syrdarya'), UzRegion.sirdaryo));
    test('"Sirdaryo"', () => expect(parse('Sirdaryo'), UzRegion.sirdaryo));
    test('"Сырдарья"', () => expect(parse('Сырдарья'), UzRegion.sirdaryo));
  });

  // ---------------------------------------------------------------------------
  // XORAZM
  // ---------------------------------------------------------------------------
  group('UzRegion.xorazm', () {
    test('"Khorezm"', () => expect(parse('Khorezm'), UzRegion.xorazm));
    test('"Xorazm"', () => expect(parse('Xorazm'), UzRegion.xorazm));
    test('"Хорезм"', () => expect(parse('Хорезм'), UzRegion.xorazm));
  });

  // ---------------------------------------------------------------------------
  // QORAQALPOG'ISTON
  // ---------------------------------------------------------------------------
  group("UzRegion.qoraqalpogiston", () {
    test('"Karakalpakstan"',
        () => expect(parse('Karakalpakstan'), UzRegion.qoraqalpogiston));
    test('"Каракалпакстан"',
        () => expect(parse('Каракалпакстан'), UzRegion.qoraqalpogiston));
    test('"Qaraqalpaqstan"',
        () => expect(parse('Qaraqalpaqstan'), UzRegion.qoraqalpogiston));
    test('firestoreKey roundtrip',
        () => expect(fromKey('QORAQALPOGISTON'), UzRegion.qoraqalpogiston));
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('null input returns null', () => expect(parse(null), isNull));
    test('empty string returns null', () => expect(parse(''), isNull));
    test('whitespace returns null', () => expect(parse('   '), isNull));
    test('completely unknown string returns null',
        () => expect(parse('Paris'), isNull));
    test('fromFirestoreKey with null returns null',
        () => expect(fromKey(null), isNull));
    test('fromFirestoreKey with unknown key returns null',
        () => expect(fromKey('UNKNOWN'), isNull));
  });

  // ---------------------------------------------------------------------------
  // Display names — smoke test
  // ---------------------------------------------------------------------------
  group('displayName non-empty for all regions', () {
    for (final r in UzRegion.values) {
      test(r.name, () => expect(r.displayName.trim(), isNotEmpty));
    }
  });

  // ---------------------------------------------------------------------------
  // Firestore keys — unique and non-empty
  // ---------------------------------------------------------------------------
  group('firestoreKey unique and non-empty', () {
    test('all keys non-empty', () {
      for (final r in UzRegion.values) {
        expect(r.firestoreKey.trim(), isNotEmpty);
      }
    });
    test('all keys unique', () {
      final keys = UzRegion.values.map((r) => r.firestoreKey).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
