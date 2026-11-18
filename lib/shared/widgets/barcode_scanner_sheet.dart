import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/scan_debouncer.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key, this.continuous = false, this.onCode});

  final bool continuous;
  final bool Function(String code)? onCode;

  static Future<String?> show(
    BuildContext context, {
    bool continuous = false,
    bool Function(String code)? onCode,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) => BarcodeScannerSheet(continuous: continuous, onCode: onCode),
  );

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _hasPopped = false;
  bool _torchEnabled = false;
  final ScanDebouncer _debouncer = ScanDebouncer();
  int _scannedCount = 0;

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (!mounted) return;
      setState(() {
        _torchEnabled = !_torchEnabled;
      });
    } on Exception catch (error) {
      debugPrint('Failed to toggle scanner torch: $error');
    }
  }

  void _submitCode(String rawCode) {
    final trimmed = rawCode.trim();
    if (_hasPopped || trimmed.isEmpty || !mounted) return;
    if (widget.continuous) {
      _acceptContinuous(trimmed);
      return;
    }
    _hasPopped = true;
    Navigator.of(context).pop(trimmed);
  }

  void _acceptContinuous(String code) {
    if (!_debouncer.accept(code)) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _scannedCount++;
    });
    _manualController.clear();
    final keepScanning = widget.onCode?.call(code) ?? false;
    if (!keepScanning && mounted) {
      _hasPopped = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return TindaBottomSheet(
      title: localizations.posScanBarcode,
      closeTooltip: localizations.commonClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final value = barcode.rawValue;
                        if (value != null && value.trim().isNotEmpty) {
                          _submitCode(value);
                          return;
                        }
                      }
                    },
                    errorBuilder: (context, error) => Container(
                      color: palette.surfaceMuted,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_photography_outlined,
                            size: 36,
                            color: palette.textMuted,
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            localizations.posScanUnavailable,
                            textAlign: TextAlign.center,
                            style: AppTypography.body(palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.input),
                          border: Border.all(color: palette.accent, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(child: _ScanLine()),
                  Positioned(
                    top: AppSpacing.s8,
                    right: AppSpacing.s8,
                    child: IconButton(
                      onPressed: _toggleTorch,
                      tooltip: localizations.posScanTorchTooltip,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.scrim,
                        foregroundColor: palette.onPrimary,
                      ),
                      icon: Icon(
                        _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.continuous) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              localizations.scannerScannedCount(_scannedCount),
              style: AppTypography.bodyStrong(palette.text),
            ),
          ],
          const SizedBox(height: AppSpacing.s14),
          TindaTextInput(
            label: localizations.productBarcodeLabel,
            hintText: localizations.scannerManualHint,
            controller: _manualController,
            textInputAction: TextInputAction.done,
            onSubmitted: _submitCode,
          ),
          const SizedBox(height: AppSpacing.s12),
          TindaPrimaryButton(
            label: localizations.scannerUseCode,
            onPressed: () => _submitCode(_manualController.text),
          ),
        ],
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return Center(
      child: SizedBox(
        width: 220,
        height: 120,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Align(
            alignment: Alignment(0, -1 + 2 * _controller.value),
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
