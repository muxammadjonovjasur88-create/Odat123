import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../features/gamification/domain/weekly_reset.dart';
import '../../features/notifications/data/notification_service.dart';
import 'firebase_providers.dart';

/// Custom exception for authentication errors to pass safe messages to UI.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wrapper around [FirebaseAuth] for Flowa's sign-in methods.
class AuthRepository {
  AuthRepository(this._auth, [this._ref, FirebaseFirestore? firestore, FirebaseFunctions? functions])
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseAuth _auth;
  final Ref? _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  FirebaseFunctions get _functionsInstance => _functions ?? FirebaseFunctions.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Signs in with Google, creates a lightweight profile document if needed,
  /// and returns the Firebase auth result.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();

      final googleUser = await _googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      await _ensureProfile(result.user);
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Autentifikatsiya xatosi yuz berdi.');
    } on PlatformException catch (e) {
      if (e.code == 'network_error') {
        throw const AuthException(
          'Tarmoq xatosi. Internetga ulanishni tekshiring.',
        );
      }
      throw AuthException('Tizimga kirishda xato: ${e.message ?? e.code}');
    } catch (e) {
      throw const AuthException(
        'Kutilmagan xatolik yuz berdi. Qayta urinib ko\'ring.',
      );
    }
  }

  Future<void> _ensureProfile(User? user) async {
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists) {
      final existingData = existing.data();
      await docRef.set({
        'email': user.email,
        'photoUrl': user.photoURL ?? existingData?['photoUrl'] as String?,
        'photoBase64': existingData?['photoBase64'] as String?,
        'name': user.displayName ?? existingData?['name'] ?? 'Friend',
        'totalPoints': (existingData?['totalPoints'] as num?)?.toInt() ?? 0,
        'weeklyPoints': (existingData?['weeklyPoints'] as num?)?.toInt() ?? 0,
        'streak': (existingData?['streak'] as num?)?.toInt() ?? 0,
        'longestStreak': (existingData?['longestStreak'] as num?)?.toInt() ?? 0,
      }, SetOptions(merge: true));
      return;
    }

    await docRef.set({
      'name': user.displayName ?? user.email?.split('@').first ?? 'Friend',
      'email': user.email,
      'photoUrl': user.photoURL,
      'avatar': 'leaf',
      'focusType': 'Study',
      'streak': 0,
      'longestStreak': 0,
      'totalPoints': 0,
      'weeklyPoints': 0,
      'weeklyFocusMinutes': 0,
      'totalFocusMinutes': 0,
      'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
      'totalDeepSessions': 0,
      'freezes': 1,
      'earnedBadges': <int>[],
      'isPremium': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Verifies a 6-digit Telegram OTP code, logs in or creates the account,
  /// and returns the user credential.
  Future<UserCredential> signInWithTelegramOtp(String otpCode) async {
    final cleanCode = otpCode.trim();
    if (cleanCode.length != 6 || int.tryParse(cleanCode) == null) {
      throw const AuthException('6 xonali raqamli tasdiqlash kodini kiriting.');
    }

    try {
      final docRef = _firestore.collection('telegramAuthCodes').doc(cleanCode);
      final snap = await docRef.get();

      if (!snap.exists) {
        throw const AuthException('Tasdiqlash kodi topilmadi yoki noto\'g\'ri.');
      }

      final data = snap.data()!;
      final used = data['used'] as bool? ?? false;
      final expiresAt = (data['expiresAt'] as num?)?.toInt() ?? 0;
      final attempts = (data['attempts'] as num?)?.toInt() ?? 0;
      final telegramId = data['telegramId']?.toString() ?? '';
      final chatId = data['chatId']?.toString() ?? telegramId;

      if (used) {
        throw const AuthException('Ushbu kod allaqachon ishlatilgan. Botdan yangi kod oling.');
      }

      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        throw const AuthException('Kodni amal qilish muddati o\'tgan (5 daqiqa). Botdan yangi kod oling.');
      }

      if (attempts >= 5) {
        throw const AuthException('Urinishlar soni oshib ketdi (maks 5). Botdan yangi kod oling.');
      }

      // Increment attempts
      await docRef.update({'attempts': FieldValue.increment(1)});

      // Mark code as used immediately to prevent reuse
      await docRef.update({'used': true});

      // Find or determine user UID
      String targetUid = 'telegram_$telegramId';
      bool isExisting = false;

      final userByChatSnap = await _firestore
          .collection('users')
          .where('telegramChatId', isEqualTo: chatId)
          .limit(1)
          .get();

      if (userByChatSnap.docs.isNotEmpty) {
        targetUid = userByChatSnap.docs.first.id;
        isExisting = true;
      } else {
        final userByIdSnap = await _firestore
            .collection('users')
            .where('telegramId', isEqualTo: telegramId)
            .limit(1)
            .get();

        if (userByIdSnap.docs.isNotEmpty) {
          targetUid = userByIdSnap.docs.first.id;
          isExisting = true;
        }
      }

      UserCredential userCredential;
      try {
        userCredential = await _auth.signInAnonymously();
      } catch (e) {
        throw AuthException('Autentifikatsiya amalga oshmadi: $e');
      }

      final user = userCredential.user;
      if (user != null) {
        await _ensureTelegramProfile(
          user,
          targetUid: targetUid,
          telegramId: telegramId,
          chatId: chatId,
          isExisting: isExisting,
        );
      }

      return userCredential;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Autentifikatsiya xatosi yuz berdi.');
    } catch (e) {
      throw AuthException('Kodni tekshirishda xatolik yuz berdi: $e');
    }
  }

  /// Creates a single-use token for Telegram login flow.
  /// Calls Cloud Function `createLoginRequest` or generates UUID fallback.
  Future<String> createTelegramLoginRequest() async {
    try {
      final callable = _functionsInstance.httpsCallable('createLoginRequest');
      final res = await callable.call();
      final data = res.data as Map<Object?, Object?>?;
      final token = data?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {
      // Fallback in test/mock environment
    }

    // Client-side fallback token if Cloud Function is unavailable
    final fallbackToken = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('loginRequests').doc(fallbackToken).set({
      'token': fallbackToken,
      'status': 'pending',
      'createdAtMs': now,
      'expiresAt': now + 5 * 60 * 1000,
    });
    return fallbackToken;
  }

  /// Listens to real-time status updates of a Telegram login request.
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToLoginRequest(
      String token) {
    return _firestore.collection('loginRequests').doc(token).snapshots();
  }

  /// Signs in using a custom Firebase Auth token returned after Telegram approval.
  Future<UserCredential> signInWithCustomToken(
    String customToken, {
    String? loginToken,
  }) async {
    try {
      final cred = await _auth.signInWithCustomToken(customToken);
      await _ensureProfile(cred.user);

      if (loginToken != null && loginToken.isNotEmpty) {
        try {
          await _firestore.collection('loginRequests').doc(loginToken).delete();
        } catch (_) {
          // Silent cleanup failure ignore
        }
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Telegram bilan kirishda xatolik yuz berdi.');
    } catch (e) {
      throw AuthException('Kirishda kutilmagan xatolik: $e');
    }
  }

  Future<void> _ensureTelegramProfile(
    User user, {
    required String targetUid,
    required String telegramId,
    required String chatId,
    required bool isExisting,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();

    if (existing.exists || isExisting) {
      await docRef.set({
        'telegramId': telegramId,
        'telegramChatId': chatId,
      }, SetOptions(merge: true));
    } else {
      await docRef.set({
        'name': 'Foydalanuvchi_$telegramId',
        'telegramId': telegramId,
        'telegramChatId': chatId,
        'avatar': 'leaf',
        'focusType': 'Study',
        'streak': 0,
        'longestStreak': 0,
        'totalPoints': 0,
        'weeklyPoints': 0,
        'weeklyFocusMinutes': 0,
        'totalFocusMinutes': 0,
        'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
        'totalDeepSessions': 0,
        'freezes': 1,
        'earnedBadges': <int>[],
        'isPremium': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Signs out of both Google and Firebase so the next sign-in re-shows the
  /// account picker instead of silently reusing the last account.
  Future<void> signOut() async {
    final user = _auth.currentUser;
    final ref = _ref;

    if (ref != null) {
      if (user != null) {
        await ref
            .read(notificationServiceProvider)
            .clearAllUserData(uid: user.uid);
      } else {
        await ref.read(notificationServiceProvider).clearAllUserData();
      }
    }

    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref),
);

/// Emits the current [User] (or null) and drives the auth gate.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
