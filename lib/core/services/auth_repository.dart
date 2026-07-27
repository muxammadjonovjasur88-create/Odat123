import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  AuthRepository(this._auth, this._ref);

  final FirebaseAuth _auth;
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        throw const AuthException('Tarmoq xatosi. Internetga ulanishni tekshiring.');
      }
      throw AuthException('Tizimga kirishda xato: ${e.message ?? e.code}');
    } catch (e) {
      throw const AuthException('Kutilmagan xatolik yuz berdi. Qayta urinib ko\'ring.');
    }
  }

  Future<void> _ensureProfile(User? user) async {
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists) {
      final existingData = existing.data();
      await docRef.set(
        {
          'email': user.email,
          'photoUrl': user.photoURL ?? existingData?['photoUrl'] as String?,
          'photoBase64': existingData?['photoBase64'] as String?,
          'name': user.displayName ?? existingData?['name'] ?? 'Friend',
        },
        SetOptions(merge: true),
      );
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

  /// Signs out of both Google and Firebase so the next sign-in re-shows the
  /// account picker instead of silently reusing the last account.
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {}
      await _ref.read(notificationServiceProvider).clearAllUserData();
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
