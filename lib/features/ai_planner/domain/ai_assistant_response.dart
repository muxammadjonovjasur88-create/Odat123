import 'planned_task.dart';

enum AiResponseType { analysis, taskSuggestion }

/// Response returned by the `askAiAssistant` Cloud Function.
class AiAssistantResponse {
  const AiAssistantResponse({
    required this.type,
    required this.reply,
    this.suggestedTask,
  });

  final AiResponseType type;
  final String reply;
  final PlannedTask? suggestedTask;

  factory AiAssistantResponse.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'analysis';
    final type = typeStr == 'task_suggestion'
        ? AiResponseType.taskSuggestion
        : AiResponseType.analysis;

    PlannedTask? task;
    final rawTask = json['task'];
    if (rawTask is Map) {
      try {
        task = PlannedTask.fromMap(Map<String, dynamic>.from(rawTask));
      } catch (_) {}
    }

    return AiAssistantResponse(
      type: type,
      reply: json['reply'] as String? ?? '',
      suggestedTask: task,
    );
  }
}
