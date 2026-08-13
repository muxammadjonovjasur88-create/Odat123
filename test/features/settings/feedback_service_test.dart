import 'package:flowa/features/settings/data/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackService — validation unit tests', () {
    test('validateMessage returns error string for empty or whitespace messages', () {
      expect(FeedbackService.validateMessage(null), 'Iltimos, xabaringizni yozing');
      expect(FeedbackService.validateMessage(''), 'Iltimos, xabaringizni yozing');
      expect(FeedbackService.validateMessage('   '), 'Iltimos, xabaringizni yozing');
      expect(FeedbackService.validateMessage('\n\t '), 'Iltimos, xabaringizni yozing');
    });

    test('validateMessage returns null for valid non-empty message', () {
      expect(FeedbackService.validateMessage('Salom, bu test xabari'), isNull);
      expect(FeedbackService.validateMessage('  Ilovada xatolik bor  '), isNull);
    });
  });
}
