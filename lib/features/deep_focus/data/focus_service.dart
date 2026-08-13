import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../honest_focus/domain/honest_focus.dart';

/// A live tick pushed from the native focus service, carrying the live
/// "honest focus" integrity signals.
class FocusTick {
  const FocusTick({
    required this.taskId,
    required this.remainingSeconds,
    required this.status,
    this.totalSeconds = 0,
    this.distractingOpens = 0,
    this.awayCount = 0,
    this.awaySeconds = 0,
  });

  final String? taskId;
  final int remainingSeconds;

  /// 'waiting' | 'running' | 'finished' | 'idle'.
  final String status;

  final int totalSeconds;
  final int distractingOpens;
  final int awayCount;
  final int awaySeconds;

  bool get isFinished => status == 'finished';

  /// Builds integrity signals from this tick (used for finished ticks).
  FocusSignals toSignals() => FocusSignals(
    timerCompleted: isFinished,
    distractingOpens: distractingOpens,
    awayCount: awayCount,
    awaySeconds: awaySeconds,
    totalSeconds: totalSeconds,
  );

  factory FocusTick.fromMap(Map<dynamic, dynamic> m) => FocusTick(
    taskId: m['taskId'] as String?,
    remainingSeconds: (m['remainingSeconds'] as num?)?.toInt() ?? 0,
    status: (m['status'] as String?) ?? 'idle',
    totalSeconds: (m['totalSeconds'] as num?)?.toInt() ?? 0,
    distractingOpens: (m['distractingOpens'] as num?)?.toInt() ?? 0,
    awayCount: (m['awayCount'] as num?)?.toInt() ?? 0,
    awaySeconds: (m['awaySeconds'] as num?)?.toInt() ?? 0,
  );
}

/// A finished session awaiting point-scoring (e.g. completed while the app was
/// closed), with its captured integrity signals.
typedef PendingCompletion = ({String taskId, FocusSignals signals});

/// Dart bridge to the native background focus session (Android only).
///
/// The native [Foreground Service] owns the countdown, the ongoing
/// notification, and app blocking; this just schedules/stops sessions and reads
/// the live state. On non-Android platforms every call is a safe no-op.
class FocusService {
  static const _channel = MethodChannel('flowa/focus');
  static const _events = EventChannel('flowa/focus/events');

  bool get _supported => Platform.isAndroid;

  Future<T?> _invokeSafe<T>(String method, [dynamic arguments]) async {
    try {
      debugPrint('[FocusService] → invokeMethod($method, $arguments)');
      final result = await _channel.invokeMethod<T>(method, arguments);
      debugPrint('[FocusService] ← $method result: $result');
      return result;
    } on MissingPluginException catch (e) {
      debugPrint('[FocusService] ✗ $method: MethodChannel not registered — $e');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[FocusService] ✗ $method: PlatformException ${e.code}: ${e.message}\ndetails: ${e.details}');
      return null;
    } catch (e, st) {
      debugPrint('[FocusService] ✗ $method: unexpected error — $e\n$st');
      return null;
    }
  }

  /// Schedules (or immediately starts, if [startAt] is in the past) a background
  /// session for [taskId] running until [endAt]. An exact alarm starts the
  /// foreground service at [startAt] even if the app is closed.
  Future<void> scheduleSession({
    required String taskId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required List<String> packages,
    bool strict = false,
    String lang = 'en',
  }) async {
    if (!_supported) return;
    await _invokeSafe<void>('scheduleSession', {
      'taskId': taskId,
      'title': title,
      'startAt': startAt.millisecondsSinceEpoch,
      'endAt': endAt.millisecondsSinceEpoch,
      'packages': packages,
      'strict': strict,
      'lang': lang,
    });
  }

  Future<void> stopSession() async {
    if (!_supported) return;
    await _invokeSafe<void>('stopSession');
  }

  /// Shifts the native session end time by [deltaSeconds] seconds.
  /// Positive = add time, negative = subtract time. The native service
  /// updates its countdown on the very next 1-second tick (no restart needed).
  Future<void> adjustTime(int deltaSeconds) async {
    if (!_supported) return;
    await _invokeSafe<void>('adjustTime', {'deltaSeconds': deltaSeconds});
  }

  /// The current background session, or null if none.
  Future<FocusTick?> getActiveSession() async {
    if (!_supported) return null;
    final map = await _invokeSafe<Map<dynamic, dynamic>>(
      'getActiveSession',
    );
    return map == null ? null : FocusTick.fromMap(map);
  }

  /// Returns (and clears) a session that finished in the background — with its
  /// integrity signals — so the app can score its points on next open.
  Future<PendingCompletion?> takePendingCompletion() async {
    if (!_supported) return null;
    final m = await _invokeSafe<Map<dynamic, dynamic>>(
      'takePendingCompletion',
    );
    final taskId = m?['taskId'] as String?;
    if (m == null || taskId == null) return null;
    return (taskId: taskId, signals: FocusSignals.fromMap(m));
  }

  /// Debug/test hook: simulate the user leaving to a distracting app.
  Future<void> debugSimulateDistraction() async {
    if (!_supported) return;
    await _invokeSafe<void>('debugDistraction');
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!_supported) return false;
    return await _invokeSafe<bool>('canScheduleExactAlarms') ?? false;
  }

  Future<void> openExactAlarmSettings() async {
    if (!_supported) return;
    await _invokeSafe<void>('openExactAlarmSettings');
  }

  Stream<FocusTick>? _stream;

  /// Live ticks (≈1/sec) from the native service while a session is active.
  /// Cached so multiple listeners share a single native subscription.
  Stream<FocusTick> events() {
    if (!_supported) return const Stream.empty();
    return _stream ??= _events
        .receiveBroadcastStream()
        .map((e) => FocusTick.fromMap(e as Map<dynamic, dynamic>))
        .asBroadcastStream();
  }
}

final focusServiceProvider = Provider<FocusService>((ref) => FocusService());
