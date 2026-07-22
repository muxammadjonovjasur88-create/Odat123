import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../workout/domain/workout.dart';
import '../domain/honest_focus.dart';

/// Persists the result + integrity signals of each focus session under
/// `users/{uid}/focus_sessions`, and mirrors a summary onto the task document
/// so the record lives "with the task".
class FocusSessionRepository {
  FocusSessionRepository(this._db);

  final FirebaseFirestore _db;

  Future<void> record({
    required String uid,
    required String taskId,
    required String taskTitle,
    required FocusVerdict verdict,
    required FocusSignals signals,
    required int points,
    WorkoutResult? workout,
  }) async {
    final counted = HonestFocus.counts(verdict);
    final summary = {
      'taskId': taskId,
      'taskTitle': taskTitle,
      'verdict': verdict.name,
      'counted': counted,
      'points': points,
      'focusedSeconds': signals.focusedSeconds,
      'totalSeconds': signals.totalSeconds,
      'distractingOpens': signals.distractingOpens,
      'awayCount': signals.awayCount,
      'timerCompleted': signals.timerCompleted,
      if (workout != null) 'workout': workout.toMap(),
      'completedAt': FieldValue.serverTimestamp(),
    };

    final userRef = _db.collection('users').doc(uid);
    // 1. Append an immutable session record.
    await userRef.collection('focus_sessions').add(summary);

    // 2. Mirror the latest result onto the task itself (best-effort).
    try {
      await userRef.collection('tasks').doc(taskId).set({
        'lastSession': summary,
      }, SetOptions(merge: true));
    } catch (_) {
      // Task may have been deleted; the session record above is the source.
    }
  }
}

final focusSessionRepositoryProvider = Provider<FocusSessionRepository>(
  (ref) => FocusSessionRepository(ref.watch(firestoreProvider)),
);
