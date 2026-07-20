import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Emotional states for the Tinda AI character.
enum TindaAvatarMood {
  /// Waiting on FAB or chat header.
  idle,

  /// Reading store data.
  thinking,

  /// Streaming/showing answer.
  talking,

  /// Sale done, good news, or tapped.
  happy,
}

/// SVG-backed Tinda AI avatar (`assets/avatar/*.svg`) supporting 4 moods,
/// blink/talk timers, and system reduce-motion compliance.
class TindaAiAvatar extends StatefulWidget {
  /// Creates the avatar.
  const TindaAiAvatar({
    super.key,
    this.mood = TindaAvatarMood.idle,
    this.size = 44,
  });

  /// Active expression.
  final TindaAvatarMood mood;

  /// Diameter in logical pixels.
  final double size;

  @override
  State<TindaAiAvatar> createState() => _TindaAiAvatarState();
}

class _TindaAiAvatarState extends State<TindaAiAvatar> {
  Timer? _blinkTimer;
  Timer? _blinkResetTimer;
  Timer? _talkTimer;
  bool _isBlinking = false;
  bool _isMouthOpen = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TindaAiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _syncTimers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimers();
  }

  void _syncTimers() {
    _cancelTimers();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _isBlinking = false;
      _isMouthOpen = false;
      return;
    }
    if (widget.mood != TindaAvatarMood.happy) {
      _blinkTimer = Timer.periodic(
        const Duration(milliseconds: 3400),
        (_) => _triggerBlink(),
      );
    }
    if (widget.mood == TindaAvatarMood.talking) {
      _talkTimer = Timer.periodic(const Duration(milliseconds: 170), (_) {
        if (!mounted) return;
        setState(() => _isMouthOpen = !_isMouthOpen);
      });
    } else {
      _isMouthOpen = false;
    }
  }

  void _triggerBlink() {
    if (!mounted) return;
    setState(() => _isBlinking = true);
    _blinkResetTimer?.cancel();
    _blinkResetTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _isBlinking = false);
    });
  }

  void _cancelTimers() {
    _blinkTimer?.cancel();
    _blinkResetTimer?.cancel();
    _talkTimer?.cancel();
    _blinkTimer = null;
    _blinkResetTimer = null;
    _talkTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  String _resolveAsset() {
    if (_isBlinking && widget.mood != TindaAvatarMood.happy) {
      return 'assets/avatar/avatar_blink.svg';
    }
    return switch (widget.mood) {
      TindaAvatarMood.idle => 'assets/avatar/avatar_idle.svg',
      TindaAvatarMood.thinking => 'assets/avatar/avatar_thinking.svg',
      TindaAvatarMood.talking => _isMouthOpen
          ? 'assets/avatar/avatar_talking.svg'
          : 'assets/avatar/avatar_idle.svg',
      TindaAvatarMood.happy => 'assets/avatar/avatar_happy.svg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SvgPicture.asset(
        _resolveAsset(),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// 60x60 circular mango FAB showing [TindaAiAvatar].
class TindaAiFab extends StatelessWidget {
  /// Creates the AI FAB.
  const TindaAiFab({
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.mood = TindaAvatarMood.idle,
  });

  /// Tap callback.
  final VoidCallback onPressed;

  /// Accessibility label.
  final String tooltip;

  /// Avatar mood.
  final TindaAvatarMood mood;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: palette.accent,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: palette.primary.withValues(alpha: 0.32),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppSizes.aiFab,
              height: AppSizes.aiFab,
              child: Center(
                child: TindaAiAvatar(
                  mood: mood,
                  size: AppSizes.aiFab - 4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
