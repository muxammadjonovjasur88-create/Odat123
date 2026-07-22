import 'package:flutter/material.dart';

/// A known distracting app the user can choose to block, with its Android
/// application id (package name) used by the native blocker.
class BlockableApp {
  const BlockableApp({
    required this.packageName,
    required this.name,
    required this.category,
    required this.icon,
  });

  final String packageName;
  final String name;
  final String category;
  final IconData icon;
}

/// The curated catalog shown on the blocking settings screen (15).
const List<BlockableApp> kBlockableApps = [
  BlockableApp(
    packageName: 'com.instagram.android',
    name: 'Instagram',
    category: 'Social',
    icon: Icons.photo_camera_rounded,
  ),
  BlockableApp(
    packageName: 'org.telegram.messenger',
    name: 'Telegram',
    category: 'Messaging',
    icon: Icons.send_rounded,
  ),
  BlockableApp(
    packageName: 'com.google.android.youtube',
    name: 'YouTube',
    category: 'Entertainment',
    icon: Icons.play_arrow_rounded,
  ),
  BlockableApp(
    packageName: 'com.whatsapp',
    name: 'WhatsApp',
    category: 'Messaging',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  BlockableApp(
    packageName: 'com.zhiliaoapp.musically',
    name: 'TikTok',
    category: 'Entertainment',
    icon: Icons.music_note_rounded,
  ),
  BlockableApp(
    packageName: 'com.facebook.katana',
    name: 'Facebook',
    category: 'Social',
    icon: Icons.thumb_up_off_alt_rounded,
  ),
  BlockableApp(
    packageName: 'com.twitter.android',
    name: 'X',
    category: 'Social',
    icon: Icons.tag_rounded,
  ),
  BlockableApp(
    packageName: 'com.snapchat.android',
    name: 'Snapchat',
    category: 'Social',
    icon: Icons.camera_alt_rounded,
  ),
  BlockableApp(
    packageName: 'com.reddit.frontpage',
    name: 'Reddit',
    category: 'Social',
    icon: Icons.forum_rounded,
  ),
  BlockableApp(
    packageName: 'com.netflix.mediaclient',
    name: 'Netflix',
    category: 'Entertainment',
    icon: Icons.movie_outlined,
  ),
];
