import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

const int _typingDotCount = 3;
const double _typingDotStagger = 0.15;
const double _typingLiftPortion = 0.6;
const double _typingDotLift = 4;

class ChatThinkingBubble extends StatelessWidget {
  const new({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TindaAiAvatar(size: 28, mood: TindaAvatarMood.thinking),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s10,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.body(palette.textMuted),
                ),
                const SizedBox(width: AppSpacing.s8),
                const _TypingDots(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const new();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: palette.primary,
        shape: BoxShape.circle,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _typingDotCount,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: dot,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_typingDotCount, (index) {
          final phase = (_controller.value - index * _typingDotStagger) % 1.0;
          final lift = phase < _typingLiftPortion
              ? math.sin(phase / _typingLiftPortion * math.pi)
              : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(
              offset: Offset(0, -_typingDotLift * lift),
              child: dot,
            ),
          );
        }),
      ),
    );
  }
}
