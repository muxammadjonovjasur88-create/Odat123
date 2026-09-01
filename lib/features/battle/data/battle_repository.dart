import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/models/battle_match.dart';

final battleRepositoryProvider = Provider<BattleRepository>((ref) {
  return BattleRepository(ref.watch(firestoreProvider));
});

final waitingBattlesStreamProvider = StreamProvider<List<BattleMatch>>((ref) {
  return ref.watch(battleRepositoryProvider).watchWaitingBattles();
});

final myBattlesStreamProvider = StreamProvider.family<List<BattleMatch>, String>((ref, uid) {
  return ref.watch(battleRepositoryProvider).watchMyActiveAndWaitingBattles(uid);
});

final singleBattleStreamProvider = StreamProvider.family<BattleMatch?, String>((ref, battleId) {
  return ref.watch(battleRepositoryProvider).watchBattle(battleId);
});

class BattleException implements Exception {
  const BattleException(this.message);
  final String message;
  @override
  String toString() => message;
}

class QuizBattleQuestion {
  const QuizBattleQuestion({
    required this.questionText,
    required this.options,
    required this.correctIndex,
  });
  final String questionText;
  final List<String> options;
  final int correctIndex;

  Map<String, dynamic> toMap() => {
    'questionText': questionText,
    'options': options,
    'correctIndex': correctIndex,
  };
}

// Age-appropriate question banks
const List<QuizBattleQuestion> _kidsQuestions = [
  QuizBattleQuestion(questionText: '7 × 8 = ?', options: ['48', '56', '54', '62'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'O\'zbekiston poytaxti qaysi shahar?', options: ['Samarqand', 'Buxoro', 'Toshkent', 'Andijon'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'Qaysi sayyora Quyoshga eng yaqin?', options: ['Venera', 'Mars', 'Merkuriy', 'Yer'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'Suvning kimyoviy formulasi?', options: ['CO2', 'O2', 'H2O', 'NaCl'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'Yer sharida nechta qit\'a bor?', options: ['5', '6', '7', '4'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'Quyosh tizimidagi eng katta sayyora?', options: ['Saturn', 'Yer', 'Uran', 'Yupiter'], correctIndex: 3),
  QuizBattleQuestion(questionText: '100 sonining kvadrat ildizi?', options: ['50', '10', '20', '5'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Qanday ranglar birlashib yashil hosil qiladi?', options: ['Qizil+Ko\'k', 'Sariq+Ko\'k', 'Qizil+Sariq', 'Ko\'k+Oq'], correctIndex: 1),
];

const List<QuizBattleQuestion> _teensQuestions = [
  QuizBattleQuestion(questionText: 'Al-Xorazmiy qaysi fanning asoschisi?', options: ['Astronomiya', 'Fizika', 'Algebra', 'Kimyo'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'O\'zbekiston mustaqilligi qaysi yili e\'lon qilingan?', options: ['1990', '1991', '1992', '1989'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Yorug\'lik tezligi taxminan qancha?', options: ['300 000 km/s', '150 000 km/s', '1 000 000 km/s', '30 000 km/s'], correctIndex: 0),
  QuizBattleQuestion(questionText: 'Inson tanasida qancha suyak bor?', options: ['150 ta', '206 ta', '300 ta', '250 ta'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Qaysi metall oddiy sharoitda suyuq?', options: ['Simob', 'Mis', 'Rux', 'Qo\'rg\'oshin'], correctIndex: 0),
  QuizBattleQuestion(questionText: 'Eng katta qit\'a qaysi?', options: ['Afrika', 'Osiyo', 'Shimoliy Amerika', 'Antarktida'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Atom yadrosi nimalardan iborat?', options: ['Elektron va proton', 'Proton va neytron', 'Neytron va elektron', 'Faqat proton'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Fotosintez qayerda sodir bo\'ladi?', options: ['Ildizda', 'Guldor\'da', 'Xlorofillda', 'Po\'stlog\'da'], correctIndex: 2),
];

const List<QuizBattleQuestion> _adultsQuestions = [
  QuizBattleQuestion(questionText: '"Men fikrlayapman, demak, mavjudman" – kim aytgan?', options: ['Sokrat', 'Rene Dekart', 'I. Kant', 'Aristotel'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Yer sharidagi eng chuqur ko\'l?', options: ['Kaspiy', 'Baykal', 'Viktoriya', 'Tanganika'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Inson DNKsida nechta juft xromosoma?', options: ['23 juft', '46 juft', '21 juft', '24 juft'], correctIndex: 0),
  QuizBattleQuestion(questionText: 'Eng uzun daryo?', options: ['Amazonka', 'Nil', 'Yanszi', 'Missisipi'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Relativity nazariyasini kim yaratgan?', options: ['Nyuton', 'Plank', 'Eynshteyn', 'Bohr'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'Qaysi element davriy sistemada birinchi o\'rinda?', options: ['Geliy', 'Litiy', 'Vodorod', 'Uglerod'], correctIndex: 2),
  QuizBattleQuestion(questionText: 'GDP nima?', options: ['Davlat qarz portfeli', 'Yalpi ichki mahsulot', 'Global ta\'lim dasturi', 'Davlat boshqaruv platforma'], correctIndex: 1),
  QuizBattleQuestion(questionText: 'Optik tolaning asosiy prinsipi?', options: ['Yorug\'likni sindirish', 'To\'liq ichki aks ettirish', 'Difraktsiya', 'Interferensiya'], correctIndex: 1),
];

List<Map<String, dynamic>> getQuestionsForAge(int age) {
  List<QuizBattleQuestion> pool;
  if (age < 12) {
    pool = _kidsQuestions;
  } else if (age < 18) {
    pool = _teensQuestions;
  } else {
    pool = _adultsQuestions;
  }
  final shuffled = List<QuizBattleQuestion>.from(pool)..shuffle();
  return shuffled.take(5).map((q) => q.toMap()).toList();
}

class BattleRepository {
  BattleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _battlesCol =>
      _db.collection('battles');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  /// Streams list of open waiting battles (where no opponent has joined yet or waiting for opponent)
  /// Updates instantly in real-time across all devices with zero polling delay.
  Stream<List<BattleMatch>> watchWaitingBattles() {
    return _battlesCol
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final list = snap.docs
              .map(BattleMatch.fromDoc)
              .where((b) =>
                  b.status == BattleStatus.waiting &&
                  (b.opponentUid == null || b.opponentUid!.isEmpty))
              .toList();
          list.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('⚠️ watchWaitingBattles error: $e');
          return <BattleMatch>[];
        });
  }

  /// Streams user's own active or waiting battles
  Stream<List<BattleMatch>> watchMyActiveAndWaitingBattles(String uid) {
    if (uid.isEmpty) return Stream.value(<BattleMatch>[]);
    return _battlesCol
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
          final list = snap.docs
              .map(BattleMatch.fromDoc)
              .where((b) =>
                  (b.status == BattleStatus.waiting || b.status == BattleStatus.active) &&
                  (b.hostUid == uid || b.opponentUid == uid))
              .toList();
          list.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return list;
        })
        .handleError((e) {
          debugPrint('⚠️ watchMyActiveAndWaitingBattles error: $e');
          return <BattleMatch>[];
        });
  }

  /// Streams a single live battle
  Stream<BattleMatch?> watchBattle(String battleId) {
    if (battleId.isEmpty) return Stream.value(null);
    return _battlesCol.doc(battleId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BattleMatch.fromDoc(doc);
    }).handleError((e) {
      debugPrint('⚠️ watchBattle error: $e');
      return null;
    });
  }

  /// Broadcasts live camera preview snapshot frame & current score
  Future<void> updatePlayerLiveFrame({
    required String battleId,
    required String uid,
    required String frameBase64,
    required int reps,
  }) async {
    try {
      await _battlesCol
          .doc(battleId)
          .collection('live_frames')
          .doc(uid)
          .set({
        'frame': frameBase64,
        'reps': reps,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Streams the opponent's live camera preview frame
  Stream<Map<String, dynamic>?> watchPlayerLiveFrame({
    required String battleId,
    required String opponentUid,
  }) {
    if (opponentUid.isEmpty) return Stream.value(null);
    return _battlesCol
        .doc(battleId)
        .collection('live_frames')
        .doc(opponentUid)
        .snapshots()
        .map((doc) => doc.data())
        .handleError((_) => null);
  }

  /// Broadcasts player's live camera / pose preview frame
  Future<void> broadcastPlayerLiveFrame({
    required String battleId,
    required String uid,
    required String frameBase64,
  }) => updatePlayerLiveFrame(battleId: battleId, uid: uid, frameBase64: frameBase64, reps: 0);

  /// Creates a new 1v1 battle by staking custom PTS
  Future<String> createBattle({
    required UserProfile host,
    required String exerciseType,
    int durationSeconds = 60,
    int wagerPoints = 100,
    int playerAge = 16,
  }) async {
    final cleanWager = wagerPoints.clamp(50, 50000);
    if (host.totalPoints < cleanWager) {
      throw BattleException('Ballaringiz yetarli emas! Ishtirok uchun kamida $cleanWager PTS kerak.');
    }

    final batch = _db.batch();
    final battleRef = _battlesCol.doc();
    final userRef = _usersCol.doc(host.uid);

    final totalPot = cleanWager * 2;
    final winnerPrize = (totalPot * 0.9).toInt();
    final commission = totalPot - winnerPrize;

    // Deduct wager PTS from host
    batch.update(userRef, {
      'totalPoints': FieldValue.increment(-cleanWager),
      'weeklyPoints': FieldValue.increment(-cleanWager),
    });

    // Generate quiz questions for knowledge battles
    final quizQuestions = exerciseType == 'quiz' ? getQuestionsForAge(playerAge) : <Map<String, dynamic>>[];

    // Create battle document
    batch.set(battleRef, {
      'hostUid': host.uid,
      'hostName': host.name.isEmpty ? 'Jangchi' : host.name,
      'hostAvatar': host.avatar,
      'hostScore': 0,
      'hostReady': false,
      'exerciseType': exerciseType,
      'durationSeconds': durationSeconds,
      'wagerPoints': cleanWager,
      'winnerPrize': winnerPrize,
      'commission': commission,
      'status': BattleStatus.waiting.name,
      'createdAt': FieldValue.serverTimestamp(),
      if (exerciseType == 'quiz') 'hostAge': playerAge,
      if (quizQuestions.isNotEmpty) 'questions': quizQuestions,
    });

    await batch.commit();
    return battleRef.id;
  }

  /// Joins an existing waiting battle by staking the battle's wagerPoints
  Future<void> joinBattle({
    required String battleId,
    required UserProfile opponent,
  }) async {
    await _db.runTransaction((transaction) async {
      final battleDoc = await transaction.get(_battlesCol.doc(battleId));
      if (!battleDoc.exists) throw const BattleException('Battle topilmadi.');

      final data = battleDoc.data() ?? {};
      if (data['status'] != BattleStatus.waiting.name || (data['opponentUid'] != null && data['opponentUid'] != opponent.uid)) {
        throw const BattleException('Ushbu battle allaqachon boshlangan yoki to‘lgan.');
      }

      final wager = (data['wagerPoints'] as num?)?.toInt() ?? 100;
      if (opponent.totalPoints < wager) {
        throw BattleException('Ballaringiz yetarli emas! Ishtirok uchun kamida $wager PTS kerak.');
      }

      if (data['hostUid'] == opponent.uid) {
        throw const BattleException('O‘zingiz yaratgan jangga raqib bo‘lib qo‘shila olmaysiz.');
      }

      // Deduct wager PTS from opponent
      transaction.set(_usersCol.doc(opponent.uid), {
        'totalPoints': FieldValue.increment(-wager),
        'weeklyPoints': FieldValue.increment(-wager),
      }, SetOptions(merge: true));

      // Update battle with opponent info (both must press ready/start)
      transaction.update(_battlesCol.doc(battleId), {
        'opponentUid': opponent.uid,
        'opponentName': opponent.name.isEmpty ? 'Raqib' : opponent.name,
        'opponentAvatar': opponent.avatar,
        'opponentPhotoUrl': opponent.photoUrl,
        'opponentPhotoBase64': opponent.photoBase64,
        'opponentScore': 0,
        'opponentReady': false,
        'status': BattleStatus.waiting.name,
      });
    });
  }

  /// Quick random match finder: Joins an open room, or creates a fast match with a realistic player/bot
  Future<String> findOrCreateRandomMatch({
    required UserProfile user,
    String exerciseType = 'pushup',
    int durationSeconds = 60,
    int wagerPoints = 50,
    int playerAge = 16,
  }) async {
    final cleanWager = wagerPoints.clamp(50, 5000);
    if (user.totalPoints < cleanWager) {
      throw BattleException('Ballaringiz yetarli emas! Kamida $cleanWager PTS kerak.');
    }

    try {
      final snap = await _battlesCol
          .where('status', isEqualTo: BattleStatus.waiting.name)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 5));

      final now = DateTime.now();
      final available = snap.docs.where((d) {
        final data = d.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final ageSec = createdAt != null ? now.difference(createdAt).inSeconds : 0;
        final opponentUid = data['opponentUid'] as String?;
        return data['hostUid'] != user.uid &&
            (opponentUid == null || opponentUid.isEmpty) &&
            data['exerciseType'] == exerciseType &&
            (data['hostReady'] as bool? ?? false) == true &&
            ageSec < 60; // Only fresh active rooms within last 60 seconds
      }).toList();

      if (available.isNotEmpty) {
        final chosen = available.first;
        await joinBattle(battleId: chosen.id, opponent: user);
        return chosen.id;
      }
    } catch (_) {}

    // If no public rooms found, create an authentic instant match with realistic opponent
    final botNames = ['Temur_Workout', 'Sardor_Fit', 'Jasur_Champion', 'Bek_Pro', 'Aziz_Titan', 'Murod_Power', 'Bobur_Athlete'];
    final botAvatars = ['shield', 'fire', 'leaf', 'star', 'crown', 'gem'];
    final randomSeed = DateTime.now().millisecondsSinceEpoch;
    final botName = botNames[randomSeed % botNames.length];
    final botAvatar = botAvatars[(randomSeed ~/ 7) % botAvatars.length];
    final botUid = 'bot_$randomSeed';

    final battleRef = _battlesCol.doc();
    final userRef = _usersCol.doc(user.uid);
    final totalPot = cleanWager * 2;
    final winnerPrize = (totalPot * 0.9).toInt();
    final commission = totalPot - winnerPrize;

    final quizQuestions = exerciseType == 'quiz' ? getQuestionsForAge(playerAge) : <Map<String, dynamic>>[];

    final batch = _db.batch();
    batch.update(userRef, {
      'totalPoints': FieldValue.increment(-cleanWager),
      'weeklyPoints': FieldValue.increment(-cleanWager),
    });

    batch.set(battleRef, {
      'hostUid': user.uid,
      'hostName': user.name.isEmpty ? 'Jangchi' : user.name,
      'hostAvatar': user.avatar,
      'hostPhotoUrl': user.photoUrl,
      'hostPhotoBase64': user.photoBase64,
      'hostScore': 0,
      'hostReady': true,
      'opponentUid': botUid,
      'opponentName': botName,
      'opponentAvatar': botAvatar,
      'opponentPhotoUrl': null,
      'opponentPhotoBase64': null,
      'opponentScore': 0,
      'opponentReady': true,
      'exerciseType': exerciseType,
      'durationSeconds': durationSeconds,
      'wagerPoints': cleanWager,
      'winnerPrize': winnerPrize,
      'commission': commission,
      'status': BattleStatus.active.name,
      'startedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      if (exerciseType == 'quiz') 'hostAge': playerAge,
      if (exerciseType == 'quiz') 'opponentAge': playerAge,
      if (quizQuestions.isNotEmpty) 'questions': quizQuestions,
    });

    await batch.commit();
    return battleRef.id;
  }

  /// Updates bot opponent score live during match
  Future<void> updateBotScore(String battleId, int newScore) async {
    try {
      await _battlesCol.doc(battleId).update({
        'opponentScore': newScore,
      });
    } catch (_) {}
  }

  /// Sets player ready status. If both host and opponent are ready, activates match!
  Future<void> setPlayerReady({
    required String battleId,
    required String uid,
  }) async {
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(_battlesCol.doc(battleId));
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final isHost = data['hostUid'] == uid;
      final isOpponent = data['opponentUid'] == uid;

      if (!isHost && !isOpponent) return;

      final hostReady = isHost ? true : (data['hostReady'] as bool? ?? false);
      final opponentReady = isOpponent ? true : (data['opponentReady'] as bool? ?? false);
      final hasOpponent = data['opponentUid'] != null && (data['opponentUid'] as String).isNotEmpty;

      final updates = <String, dynamic>{
        if (isHost) 'hostReady': true,
        if (isOpponent) 'opponentReady': true,
      };

      if (hasOpponent && hostReady && opponentReady) {
        updates['status'] = BattleStatus.active.name;
        updates['startedAt'] = FieldValue.serverTimestamp();
      }

      transaction.update(_battlesCol.doc(battleId), updates);
    });
  }

  /// When opponent or host is inactive/sleeping, instantly converts match to AI Bot battle
  Future<void> startWithBotFallback({
    required String battleId,
    required String myUid,
  }) async {
    final botNames = ['Temur_Workout', 'Sardor_Fit', 'Jasur_Champion', 'Bek_Pro', 'Aziz_Titan', 'Murod_Power'];
    final botAvatars = ['shield', 'fire', 'leaf', 'star', 'crown', 'gem'];
    final randomSeed = DateTime.now().millisecondsSinceEpoch;
    final botName = botNames[randomSeed % botNames.length];
    final botAvatar = botAvatars[(randomSeed ~/ 7) % botAvatars.length];
    final botUid = 'bot_$randomSeed';

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(_battlesCol.doc(battleId));
      if (!doc.exists) return;
      final data = doc.data() ?? {};

      final isHost = data['hostUid'] == myUid;

      final updates = <String, dynamic>{
        'status': BattleStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
        if (isHost) ...{
          'opponentUid': botUid,
          'opponentName': botName,
          'opponentAvatar': botAvatar,
          'opponentReady': true,
          'hostReady': true,
        } else ...{
          'hostUid': botUid,
          'hostName': botName,
          'hostAvatar': botAvatar,
          'hostReady': true,
          'opponentReady': true,
        },
      };

      transaction.update(_battlesCol.doc(battleId), updates);
    });
  }

  /// Claims 30s timeout win when opponent or host does not ready up within 30 seconds
  Future<void> claimTimeoutWin({
    required String battleId,
    required String winnerUid,
  }) async {
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(_battlesCol.doc(battleId));
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      if (data['status'] == BattleStatus.finished.name) return;

      final hostUid = data['hostUid'] as String? ?? '';
      final opponentUid = data['opponentUid'] as String? ?? '';
      final isHostWinner = winnerUid == hostUid;
      final loserUid = isHostWinner ? opponentUid : hostUid;

      final wager = (data['wagerPoints'] as num?)?.toInt() ?? 100;
      final prize = (data['winnerPrize'] as num?)?.toInt() ?? (wager * 1.8).round();

      transaction.update(_battlesCol.doc(battleId), {
        'status': BattleStatus.finished.name,
        'winnerUid': winnerUid,
        'finishedAt': FieldValue.serverTimestamp(),
      });

      // Winner gets the prize PTS
      transaction.set(_usersCol.doc(winnerUid), {
        'totalPoints': FieldValue.increment(prize),
        'weeklyPoints': FieldValue.increment(prize),
        'battleWins': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Record in winner's PTS history
      final winHistoryRef = _usersCol.doc(winnerUid).collection('pts_history').doc();
      transaction.set(winHistoryRef, {
        'title': 'extra.battle_opponent_missed'.tr(namedArgs: {'prize': prize.toString()}),
        'amount': prize,
        'type': 'earn',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Loser gets recorded in PTS history
      if (loserUid.isNotEmpty && !loserUid.startsWith('bot_')) {
        transaction.set(_usersCol.doc(loserUid), {
          'battleLosses': FieldValue.increment(1),
        }, SetOptions(merge: true));

        final loseHistoryRef = _usersCol.doc(loserUid).collection('pts_history').doc();
        transaction.set(loseHistoryRef, {
          'title': 'extra.battle_you_missed'.tr(namedArgs: {'wager': wager.toString()}),
          'amount': -wager,
          'type': 'spend',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Live score sync during active match (does not end the match)
  Future<void> submitScore({
    required String battleId,
    required String uid,
    required int score,
    bool isFinal = false,
  }) async {
    await _db.runTransaction((transaction) async {
      final battleDoc = await transaction.get(_battlesCol.doc(battleId));
      if (!battleDoc.exists) return;

      final data = battleDoc.data() ?? {};
      if (data['status'] == BattleStatus.finished.name) return;

      final isHost = data['hostUid'] == uid;
      final hostScore = isHost ? score : ((data['hostScore'] as num?)?.toInt() ?? 0);
      final opponentScore = !isHost ? score : ((data['opponentScore'] as num?)?.toInt() ?? 0);

      final updates = <String, dynamic>{
        if (isHost) 'hostScore': score,
        if (!isHost) 'opponentScore': score,
        if (isHost && isFinal) 'hostFinished': true,
        if (!isHost && isFinal) 'opponentFinished': true,
      };

      final hostFinished = (isHost && isFinal) || (data['hostFinished'] as bool? ?? false);
      final opponentFinished = (!isHost && isFinal) || (data['opponentFinished'] as bool? ?? false);

      // Resolve the match when both finished OR any player finalizes after timer
      if (isFinal || (hostFinished && opponentFinished)) {
        final wager = (data['wagerPoints'] as num?)?.toInt() ?? 100;
        final prize = (data['winnerPrize'] as num?)?.toInt() ?? (wager * 1.8).round();

        String? winnerUid;
        if (hostScore > opponentScore) {
          winnerUid = data['hostUid'] as String;
        } else if (opponentScore > hostScore) {
          winnerUid = data['opponentUid'] as String;
        }

        updates['status'] = BattleStatus.finished.name;
        updates['winnerUid'] = winnerUid;
        updates['finishedAt'] = FieldValue.serverTimestamp();

        if (winnerUid != null) {
          final loserUid = winnerUid == data['hostUid'] ? data['opponentUid'] as String? : data['hostUid'] as String?;
          final winnerRef = _usersCol.doc(winnerUid);
          transaction.set(winnerRef, {
            'totalPoints': FieldValue.increment(prize),
            'weeklyPoints': FieldValue.increment(prize),
            'battleWins': FieldValue.increment(1),
            'pushUpCount': FieldValue.increment(data['exerciseType'] == 'pushup'
                ? (winnerUid == data['hostUid'] ? hostScore : opponentScore)
                : 0),
          }, SetOptions(merge: true));
          if (loserUid != null && !loserUid.startsWith('bot_')) {
            final loserRef = _usersCol.doc(loserUid);
            transaction.set(loserRef, {
              'battleLosses': FieldValue.increment(1),
            }, SetOptions(merge: true));
          }
          debugPrint('🏆 [Battle Arena] G‘olib: $winnerUid ga $prize PTS berildi.');
        } else {
          // Draw: refund exact staked wager PTS to both without giving extra fake points
          final hostRef = _usersCol.doc(data['hostUid'] as String);
          final opponentRef = _usersCol.doc(data['opponentUid'] as String);
          transaction.set(hostRef, {
            'totalPoints': FieldValue.increment(wager),
            'weeklyPoints': FieldValue.increment(wager),
          }, SetOptions(merge: true));
          transaction.set(opponentRef, {
            'totalPoints': FieldValue.increment(wager),
            'weeklyPoints': FieldValue.increment(wager),
          }, SetOptions(merge: true));
          debugPrint('🤝 [Battle Arena] Durang: Har ikki ishtirokchiga $wager PTS qaytarildi.');
        }
      }

      transaction.update(_battlesCol.doc(battleId), updates);
    });
  }

  /// Cancels or deletes a battle room with strict permissions
  Future<void> cancelBattle({
    required String battleId,
    required String uid,
  }) async {
    await _db.runTransaction((transaction) async {
      final battleDoc = await transaction.get(_battlesCol.doc(battleId));
      if (!battleDoc.exists) return;

      final data = battleDoc.data() ?? {};
      final hostUid = data['hostUid'] as String?;
      final opponentUid = data['opponentUid'] as String?;
      final wager = (data['wagerPoints'] as num?)?.toInt() ?? 100;
      final status = data['status'] as String?;

      // 1. Host Cancels unstarted room
      if (hostUid == uid) {
        if (status != BattleStatus.finished.name) {
          transaction.set(_usersCol.doc(hostUid), {
            'totalPoints': FieldValue.increment(wager),
            'weeklyPoints': FieldValue.increment(wager),
          }, SetOptions(merge: true));
          if (opponentUid != null && opponentUid.isNotEmpty) {
            transaction.set(_usersCol.doc(opponentUid), {
              'totalPoints': FieldValue.increment(wager),
              'weeklyPoints': FieldValue.increment(wager),
            }, SetOptions(merge: true));
          }
        }
        transaction.delete(_battlesCol.doc(battleId));
        debugPrint('🗑️ [Battle Arena] Host xonani bekor qildi: $battleId');
        return;
      }

      // 2. Opponent leaves unstarted room (Room stays open for another opponent!)
      if (opponentUid == uid && status == BattleStatus.waiting.name) {
        transaction.set(_usersCol.doc(opponentUid), {
          'totalPoints': FieldValue.increment(wager),
          'weeklyPoints': FieldValue.increment(wager),
        }, SetOptions(merge: true));
        transaction.update(_battlesCol.doc(battleId), {
          'opponentUid': FieldValue.delete(),
          'opponentName': FieldValue.delete(),
          'opponentAvatar': FieldValue.delete(),
          'opponentReady': false,
          'opponentScore': 0,
        });
        debugPrint('🚪 [Battle Arena] Raqib xonadan chiqdi, xona ochiq qoldi: $battleId');
        return;
      }

      // 3. Opponent forfeits active match (Host wins)
      if (opponentUid == uid && status == BattleStatus.active.name && hostUid != null) {
        final prize = (data['winnerPrize'] as num?)?.toInt() ?? (wager * 1.8).round();
        transaction.update(_battlesCol.doc(battleId), {
          'status': BattleStatus.finished.name,
          'winnerUid': hostUid,
          'finishedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_usersCol.doc(hostUid), {
          'totalPoints': FieldValue.increment(prize),
          'weeklyPoints': FieldValue.increment(prize),
        }, SetOptions(merge: true));
        debugPrint('🏳️ [Battle Arena] Raqib taslim bo‘ldi, Host yutdi: $hostUid');
        return;
      }
    });
  }

  /// Deletes a finished or stale battle from Firestore
  Future<void> cleanupFinishedBattle(String battleId) async {
    try {
      await _battlesCol.doc(battleId).delete();
      debugPrint('🧹 [Battle Arena] Finished battle $battleId deleted from database.');
    } catch (_) {}
  }
}
