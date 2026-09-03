import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../constants/default_avatars.dart';

/// Renders a user's chosen default avatar (by key) as a colored circle.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.avatarKey,
    this.size = 40,
    this.photoBase64,
    this.photoUrl,
  });

  final String avatarKey;
  final double size;
  final String? photoBase64;
  final String? photoUrl;

  static final Map<String, Uint8List> _base64Cache = {};

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final key = photoBase64!;
        final bytes = _base64Cache.putIfAbsent(key, () => base64Decode(key));
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallbackAvatar(),
          ),
        );
      } catch (_) {
        return _fallbackAvatar();
      }
    }

    if (photoUrl != null && photoUrl!.isNotEmpty && photoUrl!.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallbackAvatar(),
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    if (avatarKey == 'leaf' || avatarKey.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF0C101A),
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(size * 0.12),
        child: ClipOval(
          child: Image.asset(
            'assets/icon/flowa_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.bolt_rounded, size: size * 0.5, color: const Color(0xFF38BDF8)),
          ),
        ),
      );
    }
    final avatar = avatarForKey(avatarKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatar.background,
        shape: BoxShape.circle,
      ),
      child: Icon(avatar.icon, size: size * 0.5, color: avatar.foreground),
    );
  }
}
