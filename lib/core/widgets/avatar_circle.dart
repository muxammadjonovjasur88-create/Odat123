import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64!);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackAvatar(),
          ),
        );
      } catch (_) {
        return _fallbackAvatar();
      }
    }

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackAvatar(),
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
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
