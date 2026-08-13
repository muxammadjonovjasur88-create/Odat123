import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_assistant_response.dart';

/// Calls the `askAiAssistant` Firebase Cloud Function with user query & real stats.
class AiAssistantService {
  AiAssistantService(this._functions);

  final FirebaseFunctions _functions;

  Future<AiAssistantResponse> ask(String message) async {
    try {
      debugPrint('🤖 [AiAssistantService] Calling askAiAssistant Cloud Function with message: "$message"');
      final callable = _functions.httpsCallable('askAiAssistant');
      final result = await callable.call<Map<String, dynamic>>({'message': message});

      debugPrint('🤖 [AiAssistantService] Function returned data: ${result.data}');
      return AiAssistantResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [AiAssistantService] FirebaseFunctionsException: ${e.code} — ${e.message}');
      throw Exception(
        e.message ?? 'Hozir javob bera olmayapman, birozdan keyin qayta urinib ko\'ring.',
      );
    } catch (e) {
      debugPrint('❌ [AiAssistantService] Error: $e');
      throw Exception(
        'Hozir javob bera olmayapman, birozdan keyin qayta urinib ko\'ring.',
      );
    }
  }
}

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return AiAssistantService(FirebaseFunctions.instance);
});
