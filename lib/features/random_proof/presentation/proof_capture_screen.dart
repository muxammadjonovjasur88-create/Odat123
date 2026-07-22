import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class ProofCaptureScreen extends StatefulWidget {
  const ProofCaptureScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<ProofCaptureScreen> createState() => _ProofCaptureScreenState();
}

class _ProofCaptureScreenState extends State<ProofCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _secondsLeft = 15;
  Timer? _timer;
  bool _isCapturing = false;
  bool _isUploading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _errorMessage = "Kameralar topilmadi");
        return;
      }
      
      final rear = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      
      _controller = CameraController(rear, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _startTimer();
    } catch (e) {
      setState(() => _errorMessage = "Kameraga ruxsat berilmagan yoki xatolik: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _captureSequence();
      }
    });
  }

  Future<void> _captureSequence() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _isCapturing = true;
    });

    try {
      // 1. Take rear photo
      final rearXFile = await _controller!.takePicture();
      final rearFile = File(rearXFile.path);

      // 2. Switch to front camera
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first, // fallback if no front camera
      );
      
      if (front.lensDirection == CameraLensDirection.front) {
        await _controller!.setDescription(front);
        // Wait a tiny bit for auto-focus/exposure
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 3. Take front photo
        final frontXFile = await _controller!.takePicture();
        final frontFile = File(frontXFile.path);

        // 4. Upload both
        await _uploadPhotos(rearFile, frontFile);
      } else {
        // Only one camera available
        await _uploadPhotos(rearFile, null);
      }

    } catch (e) {
      setState(() {
        _errorMessage = "Suratga olishda xatolik: $e";
        _isCapturing = false;
      });
    }
  }

  Future<void> _uploadPhotos(File rearFile, File? frontFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final storage = FirebaseStorage.instance;
      final rearRef = storage.ref().child('proofs/${widget.sessionId}/rear.jpg');
      await rearRef.putFile(rearFile);
      final rearUrl = await rearRef.getDownloadURL();

      String? frontUrl;
      if (frontFile != null) {
        final frontRef = storage.ref().child('proofs/${widget.sessionId}/front.jpg');
        await frontRef.putFile(frontFile);
        frontUrl = await frontRef.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('proofSessions')
          .doc(widget.sessionId)
          .update({
        'status': 'completed',
        'rearPhotoUrl': rearUrl,
        if (frontUrl != null) 'frontPhotoUrl': frontUrl,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Call Vercel endpoint to notify telegram
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          // TODO: O'zingizning Vercel URL manzilingizni kiriting
          final url = Uri.parse('https://YOUR_VERCEL_PROJECT.vercel.app/api/notify-proof-complete');
          await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': widget.sessionId,
              'userId': uid,
            }),
          );
        }
      } catch (e) {
        debugPrint('Vercel API xatosi: $e');
      }

      if (mounted) {
        // Done
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isbot muvaffaqiyatli yuborildi!')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Yuklashda xatolik: $e";
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_isUploading || _isCapturing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Yuklanmoqda...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: false, // disable back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),
            
            // Timer overlay
            Positioned(
              top: 64,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: Center(
                    child: Text(
                      '$_secondsLeft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
