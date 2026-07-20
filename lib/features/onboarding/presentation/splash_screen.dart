import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_logo.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Watches the store profile so the splash screen knows whether onboarding is
/// complete.
final splashStoreProfileProvider = StreamProvider.autoDispose<StoreProfile>(
  (ref) => ref.watch(storeProfileRepositoryProvider).watch(),
);

/// Full-screen launch splash matching `Main.dc.html`.
class SplashScreen extends ConsumerStatefulWidget {
  /// Creates the splash screen.
  const SplashScreen({
    required this.onDone,
    super.key,
  });

  /// Called once the store profile loads with `onboardingDone`.
  final void Function(bool onboardingDone) onDone;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _hasNavigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spinController.stop();
    } else if (!_spinController.isAnimating) {
      unawaited(_spinController.repeat());
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _handleProfileLoaded(StoreProfile profile) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      widget.onDone(profile.onboardingDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final profileAsync = ref.watch(splashStoreProfileProvider);

    ref.listen<AsyncValue<StoreProfile>>(
      splashStoreProfileProvider,
      (previous, next) {
        final loaded = next.value;
        if (loaded != null) _handleProfileLoaded(loaded);
      },
    );

    final alreadyLoaded = profileAsync.value;
    if (alreadyLoaded != null && !_hasNavigated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleProfileLoaded(alreadyLoaded);
      });
    }

    return Scaffold(
      backgroundColor: palette.header,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.s24,
              AppSpacing.s24,
              AppSpacing.s24,
              48,
            ),
            child: Column(
              children: [
              const Spacer(),
              _SplashAnimatedLogo(
                size: 104,
                spin: _spinController,
                ringColor: palette.onHeader.withValues(alpha: 0.18),
                arcColor: palette.accent,
                storeColor: palette.onHeader,
              ),
              const SizedBox(height: AppSpacing.s20),
              const TindaWordmark(fontSize: 32),
              const SizedBox(height: 6),
              Text(
                localizations.splashTagline,
                textAlign: TextAlign.center,
                style: AppTypography.bodyStrong(
                  palette.onHeader.withValues(alpha: 0.85),
                  size: 15,
                  weight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (profileAsync.hasError)
                _SplashErrorView(
                  message: localizations.homeLoadFailed,
                  retryLabel: localizations.commonRetry,
                  onRetry: () => ref.invalidate(splashStoreProfileProvider),
                )
              else
                _SplashProgress(label: localizations.splashPreparingAi),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: palette.onHeader.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.meta(
            palette.onHeader.withValues(alpha: 0.85),
            size: 13,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SplashErrorView extends StatelessWidget {
  const _SplashErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body(palette.onHeader),
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          width: 200,
          child: TindaAccentButton(
            label: retryLabel,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}

class _SplashAnimatedLogo extends StatelessWidget {
  const _SplashAnimatedLogo({
    required this.size,
    required this.spin,
    required this.ringColor,
    required this.arcColor,
    required this.storeColor,
  });

  final double size;
  final Animation<double> spin;
  final Color ringColor;
  final Color arcColor;
  final Color storeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, _) => CustomPaint(
          painter: _SplashLogoPainter(
            progress: spin.value,
            ringColor: ringColor,
            arcColor: arcColor,
            storeColor: storeColor,
          ),
        ),
      ),
    );
  }
}

class _SplashLogoPainter extends CustomPainter {
  const _SplashLogoPainter({
    required this.progress,
    required this.ringColor,
    required this.arcColor,
    required this.storeColor,
  });

  final double progress;
  final Color ringColor;
  final Color arcColor;
  final Color storeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    final center = Offset(60 * scale, 60 * scale);
    final radius = 50 * scale;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * scale;
    canvas.drawCircle(center, radius, ringPaint);

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * scale
      ..strokeCap = StrokeCap.round;
    const sweepAngle = (80 / 315) * 2 * math.pi;
    final startAngle = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    final storePaint = Paint()
      ..color = storeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeJoin = StrokeJoin.round;

    final roof = Path()
      ..moveTo(36 * scale, 52 * scale)
      ..lineTo(42 * scale, 40 * scale)
      ..lineTo(78 * scale, 40 * scale)
      ..lineTo(84 * scale, 52 * scale);
    canvas.drawPath(roof, storePaint);

    final awning = Path()
      ..moveTo(36 * scale, 52 * scale)
      ..quadraticBezierTo(42 * scale, 60 * scale, 48 * scale, 52 * scale)
      ..quadraticBezierTo(54 * scale, 60 * scale, 60 * scale, 52 * scale)
      ..quadraticBezierTo(66 * scale, 60 * scale, 72 * scale, 52 * scale)
      ..quadraticBezierTo(78 * scale, 60 * scale, 84 * scale, 52 * scale);
    canvas.drawPath(awning, storePaint);

    final walls = Path()
      ..moveTo(40 * scale, 58 * scale)
      ..lineTo(40 * scale, 82 * scale)
      ..lineTo(80 * scale, 82 * scale)
      ..lineTo(80 * scale, 58 * scale);
    canvas.drawPath(walls, storePaint);

    final doorPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeJoin = StrokeJoin.round;
    final door = Path()
      ..moveTo(54 * scale, 82 * scale)
      ..lineTo(54 * scale, 68 * scale)
      ..lineTo(66 * scale, 68 * scale)
      ..lineTo(66 * scale, 82 * scale);
    canvas.drawPath(door, doorPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashLogoPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.storeColor != storeColor;
}
