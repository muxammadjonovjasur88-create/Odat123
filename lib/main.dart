import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/auth_repository.dart';
import 'core/services/locale_store.dart';
import 'core/services/theme_mode_controller.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_theme.dart';
import 'features/deep_focus/data/focus_providers.dart';
import 'features/deep_focus/data/focus_service.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/streak/data/streak_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug-only: show the exception + stack ON SCREEN (scrollable) instead of the
  // default red screen, so an unexpected crash is diagnosable from a screenshot.
  if (kDebugMode) {
    ErrorWidget.builder = (details) => _CrashReport(details: details);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Local storage for cached/offline state.
  await Hive.initFlutter();
  // Remembered app language (seeds the start locale below).
  await LocaleStore.init();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: kFallbackLocale,
      // Saved choice wins; when null, easy_localization uses the device
      // language if it's one of the three, otherwise English.
      startLocale: LocaleStore.savedLocale(),
      // We persist the choice ourselves (Hive), not via SharedPreferences.
      saveLocale: false,
      child: const ProviderScope(child: FlowaApp()),
    ),
  );
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
      if (next.asData?.value != null) _onAuthReady();
    });
    _focusSub = ref.read(focusServiceProvider).events().listen((tick) {
      if (tick.isFinished && tick.taskId != null) {
        processBackgroundCompletion(ref, tick.taskId!, tick.toSignals());
      }
    });

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

  @override
  void dispose() {
    _focusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onAuthReady();
  }

  /// Runs the once-per-open housekeeping that needs a signed-in user.
  void _onAuthReady() {
    _processPendingCompletion();
    _refreshStreak();
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
      title: 'Flowa',
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
