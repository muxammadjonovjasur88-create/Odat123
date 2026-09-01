import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC Peer-to-Peer Signaling & Screen Sharing Service for 1v1 Battle Arena.
/// Uses screen capture (MediaProjection on Android) to stream the workout view
/// including ML Kit skeleton overlay — no camera conflict!
class WebRtcSignalingService {
  WebRtcSignalingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  /// Local screen capture renderer (shows your own screen — optional, not shown to you)
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  /// Remote screen stream from the opponent
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRemoteVideoAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isVideoMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLocalCameraReady = ValueNotifier<bool>(false);

  StreamSubscription? _callSub;
  StreamSubscription? _candidatesSub;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      // TURN servers for relay when STUN fails (symmetric NAT)
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

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Starts Live WebRTC Stream for 1v1 Battle Arena (audio stream + safe fallback).
  Future<void> startLocalStream({bool audioOnly = true}) async {
    try {
      debugPrint('[WebRTC] 🎙️ Starting audio stream for battle...');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': audioOnly ? false : {
          'facingMode': 'user',
          'width': {'ideal': 360},
          'height': {'ideal': 480},
        },
      });
      localRenderer.srcObject = _localStream;
      isLocalCameraReady.value = true;
      debugPrint('[WebRTC] ✅ WebRTC stream ready!');
    } catch (e) {
      debugPrint('[WebRTC] Audio stream error fallback: $e');
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        localRenderer.srcObject = _localStream;
        isLocalCameraReady.value = true;
      } catch (e2) {
        isLocalCameraReady.value = false;
      }
    }
  }

  void _setupPeerConnectionCallbacks(RTCPeerConnection pc) {
    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        isConnected.value = true;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        isConnected.value = false;
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] 📺 Remote track received! streams=${event.streams.length}');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        isRemoteVideoAvailable.value = true;
        isConnected.value = true;
        debugPrint('[WebRTC] ✅ Remote video connected!');
      }
    };
  }

  /// Host creates WebRTC room — sends SDP offer
  Future<void> createRoom({
    required String battleId,
    required String hostUid,
  }) async {
    try {
      debugPrint('[WebRTC] 🏠 Host creating room: $battleId');
      _peerConnection = await createPeerConnection(_iceServers, _config);
      _setupPeerConnectionCallbacks(_peerConnection!);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
        _firestore
            .collection('battles')
            .doc(battleId)
            .collection('callerCandidates')
            .add(candidate.toMap());
      };

      // Add local stream tracks to peer connection
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
        debugPrint('[WebRTC] Added ${_localStream!.getTracks().length} local tracks');
      }

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });
      await _peerConnection!.setLocalDescription(offer);

      final roomRef = _firestore.collection('battles').doc(battleId);
      await roomRef.set({
        'webrtc': {
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
          'hostReady': true,
        },
      }, SetOptions(merge: true));
      debugPrint('[WebRTC] ✅ SDP Offer sent to Firestore');

      final List<RTCIceCandidate> queuedCandidates = [];

      // Listen for answer from guest
      _callSub?.cancel();
      _callSub = roomRef.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data != null && data['webrtc'] != null) {
          final webrtc = data['webrtc'] as Map<String, dynamic>;
          if (webrtc['answer'] != null) {
            final remoteDesc = await _peerConnection?.getRemoteDescription();
            if (remoteDesc == null) {
              final answer = webrtc['answer'] as Map<String, dynamic>;
              await _peerConnection?.setRemoteDescription(
                RTCSessionDescription(answer['sdp'], answer['type']),
              );
              debugPrint('[WebRTC] ✅ Remote answer set — P2P established!');
              isConnected.value = true;

              // Drain queued ICE candidates
              for (final cand in queuedCandidates) {
                await _peerConnection?.addCandidate(cand);
              }
              queuedCandidates.clear();
            }
          }
        }
      });

      // Listen for ICE candidates from guest
      _candidatesSub?.cancel();
      _candidatesSub = roomRef.collection('calleeCandidates').snapshots().listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final cand = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
              final remoteDesc = await _peerConnection?.getRemoteDescription();
              if (remoteDesc != null) {
                await _peerConnection?.addCandidate(cand);
              } else {
                queuedCandidates.add(cand);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('[WebRTC] createRoom error: $e');
    }
  }

  /// Guest joins WebRTC room — sends SDP answer
  Future<void> joinRoom({
    required String battleId,
    required String opponentUid,
  }) async {
    try {
      debugPrint('[WebRTC] 🚪 Guest joining room: $battleId');
      _peerConnection = await createPeerConnection(_iceServers, _config);
      _setupPeerConnectionCallbacks(_peerConnection!);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
        _firestore
            .collection('battles')
            .doc(battleId)
            .collection('calleeCandidates')
            .add(candidate.toMap());
      };

      // Add local stream tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
        debugPrint('[WebRTC] Added ${_localStream!.getTracks().length} local tracks');
      }

      final roomRef = _firestore.collection('battles').doc(battleId);
      final List<RTCIceCandidate> guestQueuedCandidates = [];

      // Listen for offer from host and respond with answer
      _callSub?.cancel();
      _callSub = roomRef.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data == null || data['webrtc'] == null) return;

        final webrtc = data['webrtc'] as Map<String, dynamic>;
        if (webrtc['offer'] == null) return;

        final remoteDesc = await _peerConnection?.getRemoteDescription();
        if (remoteDesc != null) return; // Already processed

        debugPrint('[WebRTC] 📩 Received SDP offer from host, creating answer...');
        final offer = webrtc['offer'] as Map<String, dynamic>;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offer['sdp'], offer['type']),
        );

        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveVideo': 1,
          'offerToReceiveAudio': 1,
        });
        await _peerConnection!.setLocalDescription(answer);

        await roomRef.set({
          'webrtc': {
            'answer': {
              'type': answer.type,
              'sdp': answer.sdp,
            },
            'guestReady': true,
          },
        }, SetOptions(merge: true));
        debugPrint('[WebRTC] ✅ SDP Answer sent — waiting for video...');
        isConnected.value = true;

        // Drain queued ICE candidates
        for (final cand in guestQueuedCandidates) {
          await _peerConnection?.addCandidate(cand);
        }
        guestQueuedCandidates.clear();
      });

      // Listen for ICE candidates from host
      _candidatesSub?.cancel();
      _candidatesSub = roomRef.collection('callerCandidates').snapshots().listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final cand = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
              final remoteDesc = await _peerConnection?.getRemoteDescription();
              if (remoteDesc != null) {
                await _peerConnection?.addCandidate(cand);
              } else {
                guestQueuedCandidates.add(cand);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('[WebRTC] joinRoom error: $e');
    }
  }

  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final newState = !audioTracks.first.enabled;
        audioTracks.first.enabled = newState;
        isMuted.value = !newState;
      }
    }
  }

  void toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final newState = !videoTracks.first.enabled;
        videoTracks.first.enabled = newState;
        isVideoMuted.value = !newState;
      } else {
        isVideoMuted.value = !isVideoMuted.value;
      }
    } else {
      isVideoMuted.value = !isVideoMuted.value;
    }
  }

  Future<void> dispose() async {
    await _callSub?.cancel();
    await _candidatesSub?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    _peerConnection = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    isConnected.value = false;
    isRemoteVideoAvailable.value = false;
    isLocalCameraReady.value = false;
  }
}
