import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/shop/presentation/screens/shipping_form_screen.dart';

void main() {
  group('ShippingFormScreen Phone Validation', () {
    test('validates standard Uzbekistan phone numbers correctly', () {
      expect(ShippingFormScreen.validateUzPhone('+998901234567'), isTrue);
      expect(ShippingFormScreen.validateUzPhone('998901234567'), isTrue);
      expect(ShippingFormScreen.validateUzPhone('+998 90 123 45 67'), isTrue);
      expect(ShippingFormScreen.validateUzPhone('+998 (90) 123-45-67'), isTrue);
      expect(ShippingFormScreen.validateUzPhone('901234567'), isTrue); // 9 digits
    });

    test('rejects invalid or too short/long phone numbers', () {
      expect(ShippingFormScreen.validateUzPhone(''), isFalse);
      expect(ShippingFormScreen.validateUzPhone('12345'), isFalse);
      expect(ShippingFormScreen.validateUzPhone('+99890123456'), isFalse); // 8 digits
      expect(ShippingFormScreen.validateUzPhone('+9989012345678'), isFalse); // 10 digits
      expect(ShippingFormScreen.validateUzPhone('abcdefghijk'), isFalse);
    });
  });
}
