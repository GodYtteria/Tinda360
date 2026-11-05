import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class TindaFeedback {
  static void tap() {
    unawaited(_triggerFeedback(HapticFeedback.lightImpact));
  }

  static void celebrateSale() {
    unawaited(_triggerFeedback(HapticFeedback.mediumImpact));
  }

  static void milestoneUnlocked() {
    unawaited(_triggerFeedback(HapticFeedback.heavyImpact));
  }

  static Future<void> _triggerFeedback(
    Future<void> Function() hapticAction,
  ) async {
    try {
      await hapticAction();
      await SystemSound.play(SystemSoundType.click);
    } on Object catch (error) {
      debugPrint('haptic feedback failed: $error');
    }
  }
}
