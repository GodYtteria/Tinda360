import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

enum TindaAvatarMood {
  idle,

  thinking,

  talking,

  happy,
}

class TindaAiAvatar extends StatefulWidget {
  const new({
    super.key,
    this.mood = TindaAvatarMood.idle,
    this.size = 44,
  });

  final TindaAvatarMood mood;

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
      TindaAvatarMood.talking =>
        _isMouthOpen
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

class TindaAiFab extends StatelessWidget {
  const new({
    required this.onPressed,
    required this.tooltip,
    super.key,
    this.mood = TindaAvatarMood.idle,
  });

  final VoidCallback onPressed;

  final String tooltip;

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

class TindaStatusDot extends StatefulWidget {
  const new({
    required this.active,
    required this.color,
    super.key,
    this.size = 8,
  });

  final bool active;

  final Color color;

  final double size;

  @override
  State<TindaStatusDot> createState() => _TindaStatusDotState();
}

class _TindaStatusDotState extends State<TindaStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TindaStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = 1 + (_controller.value * 0.18);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.scale(
        scale: scale,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
