import 'package:flutter/material.dart';

/// Click Guard utility to prevent rapid multi-tapping / double click bugs.
class ClickGuard {
  static int _lastClickTime = 0;

  /// Returns true if the click is allowed (i.e. not debounced).
  static bool canClick({int thresholdMs = 600}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastClickTime < thresholdMs) {
      return false;
    }
    _lastClickTime = now;
    return true;
  }

  /// Runs callback only if not debounced.
  static void run(VoidCallback action, {int thresholdMs = 600}) {
    if (canClick(thresholdMs: thresholdMs)) {
      action();
    }
  }
}

/// Global Toast / SnackBar helper that hides previous messages before showing a new one.
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = const Color(0xFF131929),
    Color textColor = Colors.white,
    Duration duration = const Duration(seconds: 2),
    Widget? icon,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            if (icon != null) ...[
              icon,
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
