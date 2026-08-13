import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flowa/core/services/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  test('AuthRepository createTelegramLoginRequest creates a pending token document', () async {
    final authRepo = AuthRepository(
      MockFirebaseAuth(),
      null,
      fakeFirestore,
    );

    final token = await authRepo.createTelegramLoginRequest();
    expect(token, isNotEmpty);

    final docSnap = await fakeFirestore.collection('loginRequests').doc(token).get();
    expect(docSnap.exists, isTrue);
    expect(docSnap.data()?['status'], equals('pending'));
  });

  test('AuthRepository listenToLoginRequest emits approved status with customToken', () async {
    final authRepo = AuthRepository(
      MockFirebaseAuth(),
      null,
      fakeFirestore,
    );

    const token = 'test-token-123';
    await fakeFirestore.collection('loginRequests').doc(token).set({
      'token': token,
      'status': 'pending',
    });

    final stream = authRepo.listenToLoginRequest(token);

    expect(
      stream.map((snap) => snap.data()?['status']),
      emitsInOrder(['pending', 'approved']),
    );

    // Simulate backend approval
    await fakeFirestore.collection('loginRequests').doc(token).update({
      'status': 'approved',
      'customToken': 'mock-custom-token',
      'uid': 'user-tg-456',
    });
  });
}

class MockFirebaseAuth implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
