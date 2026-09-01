import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/utils/ai_date_parser.dart';

void main() {
  group('AiDateParser Tests', () {
    test('Salom or greetings do not trigger explicit date or time', () {
      final parsed = AiDateParser.parse('Salom');
      expect(parsed.hasExplicitDate, isFalse);
      expect(parsed.hasExplicitTime, isFalse);
      expect(parsed.hasIntent, isFalse);
      expect(parsed.hasDateOrTime, isFalse);
    });

    test('Assalomu alaykum qalaysiz do not trigger explicit date or time', () {
      final parsed = AiDateParser.parse('Assalomu alaykum qalaysiz');
      expect(parsed.hasExplicitDate, isFalse);
      expect(parsed.hasExplicitTime, isFalse);
      expect(parsed.hasIntent, isFalse);
      expect(parsed.hasDateOrTime, isFalse);
    });

    test('Ertaga soat 15:00 da investor bilan uchrashuv', () {
      final parsed = AiDateParser.parse('Ertaga soat 15:00 da investor bilan uchrashuv');
      expect(parsed.hasExplicitDate, isTrue);
      expect(parsed.hasExplicitTime, isTrue);
      expect(parsed.hasIntent, isTrue);
      expect(parsed.scheduledDateTime.hour, equals(15));
      expect(parsed.scheduledDateTime.minute, equals(0));
    });

    test('27-avgust soat 2da futbol', () {
      final parsed = AiDateParser.parse('27-avgust soat 2da futbol');
      expect(parsed.hasExplicitDate, isTrue);
      expect(parsed.hasExplicitTime, isTrue);
      expect(parsed.scheduledDateTime.month, equals(8));
      expect(parsed.scheduledDateTime.day, equals(27));
      expect(parsed.scheduledDateTime.hour, equals(14));
    });

    test('Har kuni 22:00 da kitob o‘qishni eslat', () {
      final parsed = AiDateParser.parse('Har kuni 22:00 da kitob o‘qishni eslat');
      expect(parsed.isDaily, isTrue);
      expect(parsed.repeatType, equals('daily'));
      expect(parsed.hasExplicitTime, isTrue);
      expect(parsed.scheduledDateTime.hour, equals(22));
      expect(parsed.scheduledDateTime.minute, equals(0));
    });

    test('Har dushanba soat 9:00 da haftalik reja', () {
      final parsed = AiDateParser.parse('Har dushanba soat 9:00 da haftalik reja');
      expect(parsed.isWeekly, isTrue);
      expect(parsed.repeatType, equals('weekly'));
      expect(parsed.hasExplicitTime, isTrue);
      expect(parsed.scheduledDateTime.hour, equals(9));
    });
  });
}
