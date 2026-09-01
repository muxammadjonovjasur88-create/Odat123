import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/formatting.dart';

/// Represents a Clan / Guild in the ODAT ecosystem.
class Clan {
  const Clan({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.emblem,
    required this.leaderId,
    required this.leaderName,
    this.region = 'Navoiy',
    this.maxMembers = 25,
    this.membersCount = 1,
    this.totalPoints = 0,
    this.weeklyPoints = 0,
    this.memberUids = const [],
    this.isPublic = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String tag;
  final String description;
  final String emblem; // Emoji or crest icon
  final String leaderId;
  final String leaderName;
  final String region;
  final int maxMembers; // 25 members limit per clan
  final int membersCount;
  final int totalPoints;
  final int weeklyPoints;
  final List<String> memberUids;
  final bool isPublic;
  final DateTime? createdAt;

  String get formattedTag => '[$tag]';
  bool get isFull => membersCount >= maxMembers;

  String get formattedPoints {
    return formatCompactNumber(totalPoints);
  }

  factory Clan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Clan.fromMap(data, id: doc.id);
  }

  factory Clan.fromMap(Map<String, dynamic> data, {String? id}) {
    final rawMembers = data['memberUids'] as List<dynamic>? ?? [];
    final memberList = rawMembers
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String);
    } else if (data['createdAt'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    }

    final leaderId = data['leaderId'] as String? ?? '';
    final combinedMembers = <String>{
      if (leaderId.isNotEmpty) leaderId,
      ...memberList,
    }.toList();

    int parsedCount = 1;
    if (data['membersCount'] is int) {
      parsedCount = data['membersCount'] as int;
    } else if (data['membersCount'] != null) {
      parsedCount = int.tryParse(data['membersCount'].toString()) ?? 1;
    }

    final computedCount = combinedMembers.length >= parsedCount
        ? combinedMembers.length.clamp(1, 25)
        : parsedCount.clamp(1, 25);

    int parsedTotalPoints = 0;
    if (data['totalPoints'] is int) {
      parsedTotalPoints = data['totalPoints'] as int;
    } else if (data['totalPoints'] != null) {
      parsedTotalPoints = int.tryParse(data['totalPoints'].toString()) ?? 0;
    }

    int parsedWeeklyPoints = 0;
    if (data['weeklyPoints'] is int) {
      parsedWeeklyPoints = data['weeklyPoints'] as int;
    } else if (data['weeklyPoints'] != null) {
      parsedWeeklyPoints = int.tryParse(data['weeklyPoints'].toString()) ?? 0;
    }

    return Clan(
      id: id ?? (data['id'] as String? ?? 'clan_${DateTime.now().millisecondsSinceEpoch}'),
      name: data['name'] as String? ?? 'Nomsiz Klan',
      tag: data['tag'] as String? ?? 'KLAN',
      description: data['description'] as String? ?? 'ODAT jangchilari klani',
      emblem: data['emblem'] as String? ?? '🦅',
      leaderId: data['leaderId'] as String? ?? '',
      leaderName: data['leaderName'] as String? ?? 'Sardor',
      region: data['region'] as String? ?? 'Navoiy',
      maxMembers: data['maxMembers'] as int? ?? 25,
      membersCount: computedCount,
      totalPoints: parsedTotalPoints.clamp(0, 999999999),
      weeklyPoints: parsedWeeklyPoints.clamp(0, 999999999),
      memberUids: memberList,
      isPublic: (data['isPublic'] as bool?) ?? true,
      createdAt: created ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'tag': tag,
        'description': description,
        'emblem': emblem,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'region': region,
        'maxMembers': maxMembers,
        'membersCount': membersCount,
        'totalPoints': totalPoints,
        'weeklyPoints': weeklyPoints,
        'memberUids': memberUids,
        'isPublic': isPublic,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  String toJson() => jsonEncode({
        'id': id,
        'name': name,
        'tag': tag,
        'description': description,
        'emblem': emblem,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'region': region,
        'maxMembers': maxMembers,
        'membersCount': membersCount,
        'totalPoints': totalPoints,
        'weeklyPoints': weeklyPoints,
        'memberUids': memberUids,
        'isPublic': isPublic,
        'createdAt': createdAt?.toIso8601String(),
      });

  factory Clan.fromJson(String source) =>
      Clan.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
