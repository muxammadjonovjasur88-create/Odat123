import 'dart:typed_data';

/// A real app installed on the device, returned by the native side for the
/// blocking settings list.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.name,
    this.icon,
  });

  final String packageName;
  final String name;

  /// PNG bytes of the app's launcher icon, or null if unavailable.
  final Uint8List? icon;

  factory InstalledApp.fromMap(Map<dynamic, dynamic> m) => InstalledApp(
    packageName: (m['packageName'] as String?) ?? '',
    name: (m['appName'] as String?) ?? (m['packageName'] as String? ?? ''),
    icon: m['icon'] as Uint8List?,
  );
}

/// Common distracting apps, surfaced at the top of the list when installed.
const Set<String> kCommonDistractingPackages = {
  'com.instagram.android',
  'com.zhiliaoapp.musically', // TikTok
  'com.google.android.youtube',
  'com.facebook.katana',
  'com.twitter.android',
  'com.snapchat.android',
  'com.reddit.frontpage',
  'org.telegram.messenger',
  'com.whatsapp',
  'com.netflix.mediaclient',
  'com.pinterest',
};
