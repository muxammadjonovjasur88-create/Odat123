import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/blocking_settings.dart';

/// Reads/writes the user's blocking preferences at
/// `users/{uid}/settings/blocking`.
class BlockingRepository {
  BlockingRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('settings').doc('blocking');

  Stream<BlockingSettings> watch(String uid) => _doc(uid).snapshots().map(
    (s) => s.exists ? BlockingSettings.fromDoc(s) : const BlockingSettings(),
  );

  Future<void> save(String uid, BlockingSettings settings) =>
      _doc(uid).set(settings.toMap(), SetOptions(merge: true));
}

final blockingRepositoryProvider = Provider<BlockingRepository>(
  (ref) => BlockingRepository(ref.watch(firestoreProvider)),
);

/// Live blocking settings for the signed-in user (defaults when none saved).
final blockingSettingsProvider = StreamProvider<BlockingSettings>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const BlockingSettings());
  return ref.watch(blockingRepositoryProvider).watch(uid);
});
