import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/services/user_repository.dart';

class VoiceClubParticipant {
  final String uid;
  final String name;
  final String avatar;
  final String? photoUrl;
  final String? photoBase64;
  final bool isSpeaking;
  final bool isMuted;

  VoiceClubParticipant({
    required this.uid,
    required this.name,
    required this.avatar,
    this.photoUrl,
    this.photoBase64,
    required this.isSpeaking,
    required this.isMuted,
  });
}

class VoiceClubState {
  final bool isJoined;
  final bool isMicMuted;
  final bool isSpeakerMuted;
  final List<VoiceClubParticipant> participants;
  final String? error;

  VoiceClubState({
    this.isJoined = false,
    this.isMicMuted = true,
    this.isSpeakerMuted = false,
    this.participants = const [],
    this.error,
  });

  VoiceClubState copyWith({
    bool? isJoined,
    bool? isMicMuted,
    bool? isSpeakerMuted,
    List<VoiceClubParticipant>? participants,
    String? error,
  }) {
    return VoiceClubState(
      isJoined: isJoined ?? this.isJoined,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isSpeakerMuted: isSpeakerMuted ?? this.isSpeakerMuted,
      participants: participants ?? this.participants,
      error: error,
    );
  }
}

class VoiceClubNotifier extends Notifier<VoiceClubState> {
  MediaStream? _localStream;
  StreamSubscription? _roomSub;
  Timer? _audioLevelTimer;

  // WebRTC Mesh maps: key is opponentUid
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<StreamSubscription>> _peerSubscriptions = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  static const Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  @override
  VoiceClubState build() {
    ref.onDispose(() {
      leaveRoom();
    });
    return VoiceClubState();
  }

  Future<void> joinRoom() async {
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    try {
      // 1. Initialize local microphone
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Mute initially if state says so
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = !state.isMicMuted;
      });

      // 2. Join Firestore Room (Presence)
      final docRef = FirebaseFirestore.instance.collection('voice_club').doc('main_room');
      await docRef.collection('participants').doc(user.uid).set({
        'uid': user.uid,
        'name': user.name,
        'avatar': user.avatar,
        'photoUrl': user.photoUrl,
        'photoBase64': user.photoBase64,
        'isSpeaking': false,
        'isMuted': state.isMicMuted,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 3. Listen to Room Participants & establish connections dynamically
      _roomSub = docRef.collection('participants').snapshots().listen((snap) {
        final now = DateTime.now();
        final participants = <VoiceClubParticipant>[];

        for (final d in snap.docs) {
          final data = d.data();
          final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();
          final isStale = joinedAt != null && now.difference(joinedAt).inHours >= 1;
          final isEnter = (data['name'] as String?)?.toLowerCase().trim() == 'enter';

          if (isStale || isEnter) {
            d.reference.delete();
            continue;
          }

          participants.add(VoiceClubParticipant(
            uid: data['uid'] ?? '',
            name: data['name'] ?? 'Kitobxon',
            avatar: data['avatar'] ?? 'shield',
            photoUrl: data['photoUrl'] as String?,
            photoBase64: data['photoBase64'] as String?,
            isSpeaking: data['isSpeaking'] ?? false,
            isMuted: data['isMuted'] ?? true,
          ));
        }

        // Check for any removed participants
        final activeUids = participants.map((p) => p.uid).toSet();
        final existingConnections = List<String>.from(_peerConnections.keys);
        for (final connectedUid in existingConnections) {
          if (!activeUids.contains(connectedUid)) {
            _closeConnection(connectedUid);
          }
        }

        // Check for any new participants to connect with
        for (final p in participants) {
          if (p.uid != user.uid && !_peerConnections.containsKey(p.uid)) {
            // Sort UIDs to determine Caller vs Callee role
            final isCaller = user.uid.compareTo(p.uid) < 0;
            final docId = isCaller ? '${user.uid}_${p.uid}' : '${p.uid}_${user.uid}';
            final callDocRef = docRef.collection('calls').doc(docId);

            if (isCaller) {
              _initiateCallAsCaller(p.uid, callDocRef);
            } else {
              _receiveCallAsCallee(p.uid, callDocRef);
            }
          }
        }

        state = state.copyWith(participants: participants, isJoined: true);
      });

      // 4. Start local audio level detection to animate UI
      _startAudioLevelDetection(user.uid, docRef);

    } catch (e) {
      state = state.copyWith(error: "Mikrofonga ruxsat yo'q yoki tarmoq xatosi: $e");
    }
  }

  Future<RTCPeerConnection> _setupPeerConnection(String opponentUid, bool isCaller, DocumentReference callDocRef) async {
    final pc = await createPeerConnection(_iceServers, _config);
    _peerConnections[opponentUid] = pc;
    _peerSubscriptions[opponentUid] = [];

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      final collectionName = isCaller ? 'callerCandidates' : 'calleeCandidates';
      callDocRef.collection(collectionName).add(candidate.toMap());
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[VoiceClubWebRTC] Connection state with $opponentUid: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _closeConnection(opponentUid);
      }
    };

    pc.onTrack = (RTCTrackEvent event) async {
      debugPrint('[VoiceClubWebRTC] 🎙️ Remote audio track received from $opponentUid!');
      if (state.isSpeakerMuted) {
        event.track.enabled = false;
      }

      if (event.streams.isNotEmpty) {
        try {
          final renderer = RTCVideoRenderer();
          await renderer.initialize();
          renderer.srcObject = event.streams[0];
          
          if (_remoteRenderers.containsKey(opponentUid)) {
            await _remoteRenderers[opponentUid]?.dispose();
          }
          _remoteRenderers[opponentUid] = renderer;
          debugPrint('[VoiceClubWebRTC] Attached track to RTCVideoRenderer for $opponentUid');
        } catch (e) {
          debugPrint('[VoiceClubWebRTC] Error setting up RTCVideoRenderer: $e');
        }
      }
    };

    // Add local tracks to this connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
      debugPrint('[VoiceClubWebRTC] Added ${_localStream!.getTracks().length} tracks for $opponentUid');
    }

    return pc;
  }

  Future<void> _initiateCallAsCaller(String opponentUid, DocumentReference callDocRef) async {
    try {
      debugPrint('[VoiceClubWebRTC] 📞 Initiating call to $opponentUid...');
      final pc = await _setupPeerConnection(opponentUid, true, callDocRef);

      final offer = await pc.createOffer({
        'offerToReceiveVideo': 0,
        'offerToReceiveAudio': 1,
      });
      await pc.setLocalDescription(offer);

      await callDocRef.set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      }, SetOptions(merge: true));

      final List<RTCIceCandidate> queuedCandidates = [];

      // Listen for answer
      final ansSub = callDocRef.snapshots().listen((snapshot) async {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data['answer'] != null) {
          final remoteDesc = await pc.getRemoteDescription();
          if (remoteDesc == null) {
            final answer = data['answer'] as Map<String, dynamic>;
            await pc.setRemoteDescription(
              RTCSessionDescription(answer['sdp'], answer['type']),
            );
            debugPrint('[VoiceClubWebRTC] ✅ Answer set for $opponentUid');
            for (final cand in queuedCandidates) {
              await pc.addCandidate(cand);
            }
            queuedCandidates.clear();
          }
        }
      });
      _peerSubscriptions[opponentUid]?.add(ansSub);

      // Listen for callee ICE candidates
      final candSub = callDocRef.collection('calleeCandidates').snapshots().listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final cand = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
              final remoteDesc = await pc.getRemoteDescription();
              if (remoteDesc != null) {
                await pc.addCandidate(cand);
              } else {
                queuedCandidates.add(cand);
              }
            }
          }
        }
      });
      _peerSubscriptions[opponentUid]?.add(candSub);

    } catch (e) {
      debugPrint('[VoiceClubWebRTC] Caller error with $opponentUid: $e');
    }
  }

  Future<void> _receiveCallAsCallee(String opponentUid, DocumentReference callDocRef) async {
    try {
      debugPrint('[VoiceClubWebRTC] 📥 Receiving call from $opponentUid...');
      final pc = await _setupPeerConnection(opponentUid, false, callDocRef);
      final List<RTCIceCandidate> queuedCandidates = [];

      // Listen for offer
      final offerSub = callDocRef.snapshots().listen((snapshot) async {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null || data['offer'] == null) return;

        final remoteDesc = await pc.getRemoteDescription();
        if (remoteDesc != null) return; // already set

        final offer = data['offer'] as Map<String, dynamic>;
        await pc.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );

        final answer = await pc.createAnswer({
          'offerToReceiveVideo': 0,
          'offerToReceiveAudio': 1,
        });
        await pc.setLocalDescription(answer);

        await callDocRef.set({
          'answer': {
            'type': answer.type,
            'sdp': answer.sdp,
          },
        }, SetOptions(merge: true));
        debugPrint('[VoiceClubWebRTC] ✅ Answer sent to $opponentUid');

        for (final cand in queuedCandidates) {
          await pc.addCandidate(cand);
        }
        queuedCandidates.clear();
      });
      _peerSubscriptions[opponentUid]?.add(offerSub);

      // Listen for caller ICE candidates
      final candSub = callDocRef.collection('callerCandidates').snapshots().listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final cand = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
              final remoteDesc = await pc.getRemoteDescription();
              if (remoteDesc != null) {
                await pc.addCandidate(cand);
              } else {
                queuedCandidates.add(cand);
              }
            }
          }
        }
      });
      _peerSubscriptions[opponentUid]?.add(candSub);

    } catch (e) {
      debugPrint('[VoiceClubWebRTC] Callee error with $opponentUid: $e');
    }
  }

  void _closeConnection(String opponentUid) {
    if (_remoteRenderers.containsKey(opponentUid)) {
      _remoteRenderers[opponentUid]?.dispose();
      _remoteRenderers.remove(opponentUid);
    }
    if (_peerConnections.containsKey(opponentUid)) {
      _peerConnections[opponentUid]?.close();
      _peerConnections.remove(opponentUid);
      debugPrint('[VoiceClubWebRTC] Closed PeerConnection with $opponentUid');
    }
    if (_peerSubscriptions.containsKey(opponentUid)) {
      for (final sub in _peerSubscriptions[opponentUid]!) {
        sub.cancel();
      }
      _peerSubscriptions.remove(opponentUid);
    }
  }

  void _startAudioLevelDetection(String myUid, DocumentReference roomRef) {
    _audioLevelTimer?.cancel();
    bool wasSpeaking = false;

    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (state.isMicMuted || _localStream == null) return;

      final isSpeakingNow = !state.isMicMuted;

      if (isSpeakingNow != wasSpeaking) {
        wasSpeaking = isSpeakingNow;
        await roomRef.collection('participants').doc(myUid).update({
          'isSpeaking': isSpeakingNow,
        });
      }
    });
  }

  Future<void> toggleMic() async {
    final newMuted = !state.isMicMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !newMuted;
    });

    state = state.copyWith(isMicMuted: newMuted);

    final user = ref.read(userProfileProvider).value;
    if (user != null && state.isJoined) {
      await FirebaseFirestore.instance
          .collection('voice_club')
          .doc('main_room')
          .collection('participants')
          .doc(user.uid)
          .update({
        'isMuted': newMuted,
        'isSpeaking': !newMuted,
      });
    }
  }

  void toggleSpeaker() {
    final newSpeakerMuted = !state.isSpeakerMuted;
    state = state.copyWith(isSpeakerMuted: newSpeakerMuted);

    // Mute/unmute all remote audio tracks
    for (final pc in _peerConnections.values) {
      pc.getReceivers().then((receivers) {
        for (final receiver in receivers) {
          if (receiver.track?.kind == 'audio') {
            receiver.track?.enabled = !newSpeakerMuted;
          }
        }
      });
    }
  }

  Future<void> leaveRoom() async {
    _audioLevelTimer?.cancel();
    _roomSub?.cancel();

    // Close all peer connections
    final opponentUids = List<String>.from(_peerConnections.keys);
    for (final opponentUid in opponentUids) {
      _closeConnection(opponentUid);
    }
    _peerConnections.clear();
    _peerSubscriptions.clear();

    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    _remoteRenderers.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      try {
        final docRef = FirebaseFirestore.instance.collection('voice_club').doc('main_room');
        await docRef.collection('participants').doc(user.uid).delete();

        // Also clean up any calls we were a part of
        final callsSnap = await docRef.collection('calls').get();
        for (final doc in callsSnap.docs) {
          if (doc.id.contains(user.uid)) {
            await doc.reference.delete();
          }
        }
      } catch (_) {}
    }

    state = state.copyWith(isJoined: false, participants: []);
  }
}

final voiceClubProvider = NotifierProvider<VoiceClubNotifier, VoiceClubState>(
  VoiceClubNotifier.new,
);
