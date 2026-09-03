import 'dart:convert';
import 'package:flutter/material.dart';

/// Reusable clan emblem display widget supporting both Unicode emojis
/// and custom uploaded Base64 / network images.
class ClanEmblemView extends StatelessWidget {
  const ClanEmblemView({
    super.key,
    required this.emblem,
    this.size = 32,
  });

  final String emblem;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clean = emblem.trim();
    if (clean.length > 20 || clean.startsWith('data:image') || clean.startsWith('http')) {
      if (clean.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.network(
            clean,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Text('🛡️', style: TextStyle(fontSize: size * 0.6)),
          ),
        );
      }
      try {
        final b64 = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(b64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Text('🛡️', style: TextStyle(fontSize: size * 0.6)),
          ),
        );
      } catch (_) {
        return Text('🛡️', style: TextStyle(fontSize: size * 0.6));
      }
    }
    return Text(clean.isEmpty ? '🦅' : clean, style: TextStyle(fontSize: size * 0.65));
  }
}
