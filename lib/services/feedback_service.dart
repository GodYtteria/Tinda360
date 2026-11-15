import 'dart:async';

import 'package:flutter/services.dart';

/// Safe haptic and system-sound feedback helpers for Tinda360.
abstract final class TindaFeedback {
  /// Subtle feedback for standard UI taps.
  static void tap() {
    unawaited(_triggerFeedback(HapticFeedback.lightImpact));
  }

  /// Medium feedback when a sale is completed.
  static void celebrateSale() {
    unawaited(_triggerFeedback(HapticFeedback.mediumImpact));
  }

  /// Strong feedback when a store milestone is unlocked.
  static void milestoneUnlocked() {
    unawaited(_triggerFeedback(HapticFeedback.heavyImpact));
  }

  static Future<void> _triggerFeedback(
    Future<void> Function() hapticAction,
  ) async {
    try {
      await hapticAction();
      await SystemSound.play(SystemSoundType.click);
    } on Object {
      // Ignore platform channel errors in headless or VM test environments.
    }
  }
}
