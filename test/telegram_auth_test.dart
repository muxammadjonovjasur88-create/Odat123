import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowa/core/services/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class MockFirebaseAuth extends Fake implements FirebaseAuth {}

void main() {
  group('Telegram Automatic Login Flow Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthRepository repo;
    late ProviderContainer container;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      container = ProviderContainer();
      repo = AuthRepository(
        MockFirebaseAuth(),
        container.read(dummyRefProvider),
        fakeFirestore,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('createTelegramLoginRequest creates a pending document in loginRequests', () async {
      final token = await repo.createTelegramLoginRequest();
      expect(token, isNotEmpty);

      final docSnap = await fakeFirestore.collection('loginRequests').doc(token).get();
      expect(docSnap.exists, isTrue);
      expect(docSnap.data()?['status'], equals('pending'));
      expect(docSnap.data()?['token'], equals(token));
    });

    test('listenToLoginRequest streams updates for the specific token', () async {
      final token = await repo.createTelegramLoginRequest();

      final initialSnap = await repo.listenToLoginRequest(token).first;
      expect(initialSnap.data()?['status'], equals('pending'));

      await fakeFirestore.collection('loginRequests').doc(token).update({
        'status': 'approved',
        'customToken': 'mock_custom_token_123',
      });

      final updatedSnap = await fakeFirestore.collection('loginRequests').doc(token).get();
      expect(updatedSnap.data()?['status'], equals('approved'));
      expect(updatedSnap.data()?['customToken'], equals('mock_custom_token_123'));
    });
  });
}

final dummyRefProvider = Provider<Ref>((ref) => ref);
