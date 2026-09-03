import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/auth_repository.dart';
import 'core/services/locale_store.dart';
import 'core/services/theme_mode_controller.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'features/deep_focus/data/focus_providers.dart';
import 'features/deep_focus/data/focus_service.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/reminders/domain/models/reminder.dart';
import 'features/running/domain/services/running_background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'features/streak/data/streak_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  final stopwatch = Stopwatch()..start();
  
  void logTime(String step) {
    debugPrint('🕒 [APP STARTUP] $step took: ${stopwatch.elapsedMilliseconds} ms');
    stopwatch.reset();
  }

  WidgetsFlutterBinding.ensureInitialized();
  logTime('WidgetsFlutterBinding.ensureInitialized');

  // Lock orientation to portrait only (mobile only)
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}
  }

  // Debug-only: show the exception + stack ON SCREEN (scrollable) instead of the
  // default red screen, so an unexpected crash is diagnosable from a screenshot.
  if (kDebugMode) {
    ErrorWidget.builder = (details) => _CrashReport(details: details);
  }

  // To optimize cold start, we run independent initializations in parallel.
  // Firebase, Supabase, Hive, and EasyLocalization do not depend on each other.
  final firebaseFuture = () async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logTime('Firebase.initializeApp (parallel)');
    } catch (e) {
      debugPrint('Firebase.initializeApp warning: $e');
    }
  }();

  final supabaseFuture = () async {
    try {
      await Supabase.initialize(
        url: 'https://xeymuoezdxhjivilqgtu.supabase.co',
        publishableKey: 'sb_publishable_-arZuPuO6K3oxXHt0mNZnQ_1wHRCiso',
      );
      logTime('Supabase.initialize (parallel)');
    } catch (e) {
      debugPrint('Supabase.initialize warning: $e');
    }
  }();

  final hiveAndLocaleFuture = () async {
    try {
      await Hive.initFlutter();
      logTime('Hive.initFlutter (parallel)');
      
      if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(RepeatTypeAdapter());
      if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(ReminderAdapter());
      
      await LocaleStore.init();
      logTime('LocaleStore.init (parallel)');
    } catch (e) {
      debugPrint('Hive.init warning: $e');
    }
  }();

  final easyLocalizationFuture = () async {
    try {
      await EasyLocalization.ensureInitialized();
      logTime('EasyLocalization.ensureInitialized (parallel)');
    } catch (e) {
      debugPrint('EasyLocalization.ensureInitialized warning: $e');
    }
  }();

  await Future.wait([
    firebaseFuture,
    supabaseFuture,
    hiveAndLocaleFuture,
    easyLocalizationFuture,
  ]);
  logTime('Parallel init complete');

  if (!kIsWeb) {
    try {
      await RunningBackgroundService.initialize();
      final bgService = FlutterBackgroundService();
      if (await bgService.isRunning()) {
        bgService.invoke('stop_service');
      }
    } catch (e) {
      debugPrint('RunningBackgroundService init error: $e');
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: kFallbackLocale,
      // Saved choice wins; when null, default to Uzbek.
      startLocale: LocaleStore.savedLocale(),
      // We persist the choice ourselves (Hive), not via SharedPreferences.
      saveLocale: false,
      child: const ProviderScope(child: FlowaApp()),
    ),
  );
  logTime('runApp (end of main)');
}

/// A scrollable on-screen crash report (debug only). Deliberately built from
/// low-level widgets so it renders even when the failing subtree is above
/// `MaterialApp` (no MediaQuery / Directionality / Material available).
class _CrashReport extends StatelessWidget {
  const _CrashReport({required this.details});

  final FlutterErrorDetails details;
  @override
  Widget build(BuildContext context) {
    final stack = details.stack?.toString() ?? 'no stack';
    // Keep it screenshot-friendly: the first frames point at the real cause.
    final trimmed = stack.split('\n').take(24).join('\n');
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF7A0B0B),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 64, 14, 24),
          child: SingleChildScrollView(
            child: Text(
              '${details.exceptionAsString()}\n\n$trimmed',
              style: const TextStyle(
                color: Color(0xFFFFE082),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FlowaApp extends ConsumerStatefulWidget {
  const FlowaApp({super.key});

  @override
  ConsumerState<FlowaApp> createState() => _FlowaAppState();
}

class _FlowaAppState extends ConsumerState<FlowaApp>
    with WidgetsBindingObserver {
  StreamSubscription? _focusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up notifications. The evening streak reminder is scheduled
    // conditionally by StreakReminderScheduler (only when a streak is at risk).
    ref.read(notificationServiceProvider).init();

    // Award points for any focus session that finished while the app was
    // closed (once auth resolves), and listen for sessions that finish while
    // the app is open. Also resolve missed days + grant the weekly freeze.
    _onAuthReady();
    ref.listenManual(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user != null) {
        _onAuthReady();
      } else {
        ref.read(notificationServiceProvider).cancelFcmSubscription();
      }
    });
    _focusSub = ref.read(focusServiceProvider).events().listen((tick) {
      if (tick.isFinished && tick.taskId != null) {
        processBackgroundCompletion(ref, tick.taskId!, tick.toSignals());
      }
    });

    if (!kIsWeb) {
      // Random Proof listeners
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.data['type'] == 'proof_request') {
          final sessionId = message.data['sessionId'];
          if (sessionId != null) {
            ref.read(routerProvider).push('/proof-capture/$sessionId');
          }
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['type'] == 'proof_request') {
          final sessionId = message.data['sessionId'];
          if (sessionId != null) {
            ref.read(routerProvider).push('/proof-capture/$sessionId');
          }
        }
      });
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null && message.data['type'] == 'proof_request') {
          final sessionId = message.data['sessionId'];
          if (sessionId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(routerProvider).push('/proof-capture/$sessionId');
            });
          }
        }
      });
    }
  }

  Timer? _heartbeatTimer;
  Timer? _offlineDebounceTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _updateOnlineStatus(true);
    });
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    try {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'isOnline': isOnline,
          'lastActiveDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _offlineDebounceTimer?.cancel();
    _updateOnlineStatus(false);
    _focusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _offlineDebounceTimer?.cancel();
      _updateOnlineStatus(true);
      _startHeartbeat();
      _onAuthReady();
    } else if (state == AppLifecycleState.paused) {
      _heartbeatTimer?.cancel();
      _offlineDebounceTimer?.cancel();
      // Debounce offline for 30s to prevent rapid flickering on quick background/lock
      _offlineDebounceTimer = Timer(const Duration(seconds: 30), () {
        _updateOnlineStatus(false);
      });
    } else if (state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _offlineDebounceTimer?.cancel();
      _updateOnlineStatus(false);
    }
  }

  /// Runs the once-per-open housekeeping that needs a signed-in user.
  Future<void> _onAuthReady() async {
    try {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid != null) {
        _updateOnlineStatus(true);
        _startHeartbeat();
        if (!kIsWeb) {
          await ref.read(notificationServiceProvider).setupFcm(uid);
        }
      }
      await _processPendingCompletion();
      await _refreshStreak();
    } catch (e) {
      debugPrint('_onAuthReady error: $e');
    }
  }

  Future<void> _processPendingCompletion() async {
    // Wait until auth is ready so the task lookup has a uid.
    if (ref.read(authStateProvider).asData?.value == null) return;
    final pending = await ref
        .read(focusServiceProvider)
        .takePendingCompletion();
    if (pending != null) {
      await processBackgroundCompletion(ref, pending.taskId, pending.signals);
    }
  }

  /// Grants the weekly freeze and resolves any missed days (consuming a freeze
  /// to bridge a gap, or breaking the streak).
  Future<void> _refreshStreak() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref.read(streakRepositoryProvider).refresh(uid);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ODAT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Soft, consistent overscroll across every scrollable in the app.
      scrollBehavior: const CalmScrollBehavior(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }
}
