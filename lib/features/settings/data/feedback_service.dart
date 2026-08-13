import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(FirebaseFunctions.instance);
});

/// Service handling feedback submission to Cloud Functions.
class FeedbackService {
  const FeedbackService(this._functions);

  final FirebaseFunctions _functions;

  /// Validates message string. Returns error message if invalid, null if valid.
  static String? validateMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return "Iltimos, xabaringizni yozing";
    }
    return null;
  }

  /// Sends feedback to admin via Cloud Functions (sendFeedbackToAdmin).
  Future<void> sendFeedback(String message) async {
    final validationError = validateMessage(message);
    if (validationError != null) {
      throw FormatException(validationError);
    }

    try {
      final callable = _functions.httpsCallable('sendFeedbackToAdmin');
      await callable.call<dynamic>({
        'message': message.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Serverda xatolik yuz berdi.');
    } catch (e) {
      throw Exception('Xabar yuborishda xatolik yuz berdi.');
    }
  }
}
