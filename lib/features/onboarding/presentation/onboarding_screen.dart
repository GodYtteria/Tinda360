import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/catalog/product_draft.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/failures/store_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/services/google_drive_backup_service.dart';
import 'package:tinda360/services/service_providers.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/shared/widgets/tinda_logo.dart';
import 'package:tinda360/shared/widgets/tinda_surfaces.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

/// Two-step first-run onboarding flow for naming the store and choosing
/// fresh start vs. Google Drive restore.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding screen.
  const OnboardingScreen({
    required this.onCompleted,
    super.key,
  });

  /// Called when onboarding is saved and ready to enter POS.
  final VoidCallback onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _stepIndex = 0;
  bool _isSaving = false;
  bool _showRestoreUnavailable = false;
  bool _addSampleItems = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goToStepTwo() {
    final localizations = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = localizations.failureStoreNameRequired);
      return;
    }
    setState(() {
      _errorMessage = null;
      _stepIndex = 1;
    });
  }

  Future<void> _completeAsNewStore() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final repository = ref.read(storeProfileRepositoryProvider);
    final result = await repository.completeOnboarding(_nameController.text);
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    switch (result) {
      case Ok<void, StoreFailure>():
        if (_addSampleItems) {
          await _seedSampleProducts();
          if (!mounted) return;
        }
        setState(() => _isSaving = false);
        widget.onCompleted();
      case Err<void, StoreFailure>(:final failure):
        setState(() {
          _isSaving = false;
          _errorMessage = localizedFailureMessage(localizations, failure);
        });
    }
  }

  Future<void> _seedSampleProducts() async {
    const initialStock = Quantity.whole(20);
    const lowStockAt = Quantity.whole(5);
    const sampleDrafts = [
      ProductDraft(
        name: 'Lucky Me Pancit Canton',
        unit: ProductUnit.pack,
        price: Money(1500, Currency.php),
        cost: Money(1200, Currency.php),
        lowStockAt: lowStockAt,
        initialStock: initialStock,
      ),
      ProductDraft(
        name: 'Bear Brand Swak',
        unit: ProductUnit.sachet,
        price: Money(1200, Currency.php),
        cost: Money(1000, Currency.php),
        lowStockAt: lowStockAt,
        initialStock: initialStock,
      ),
      ProductDraft(
        name: 'Kopiko Brown',
        unit: ProductUnit.sachet,
        price: Money(900, Currency.php),
        cost: Money(700, Currency.php),
        lowStockAt: lowStockAt,
        initialStock: initialStock,
      ),
      ProductDraft(
        name: 'Silver Swan Toyo',
        unit: ProductUnit.bottle,
        price: Money(1800, Currency.php),
        cost: Money(1400, Currency.php),
        lowStockAt: lowStockAt,
        initialStock: initialStock,
      ),
      ProductDraft(
        name: 'Coca-Cola Mismo',
        unit: ProductUnit.bottle,
        price: Money(2000, Currency.php),
        cost: Money(1600, Currency.php),
        lowStockAt: lowStockAt,
        initialStock: initialStock,
      ),
    ];

    final productRepository = ref.read(productRepositoryProvider);
    final log = ref.read(appLogProvider);
    for (final draft in sampleDrafts) {
      final createResult = await productRepository.create(draft);
      if (createResult case Err(:final failure)) {
        log.error('onboarding.sample_item_create', failure, StackTrace.current);
      }
    }
  }

  Future<void> _restoreFromGoogle() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _showRestoreUnavailable = false;
      _errorMessage = null;
    });
    final backupService = ref.read(driveBackupServiceProvider);
    final authResult = await backupService.signIn();
    if (!mounted) return;
    switch (authResult) {
      case BackupAuthCancelled():
        setState(() => _isSaving = false);
        return;
      case BackupAuthFailed():
        setState(() {
          _isSaving = false;
          _showRestoreUnavailable = true;
        });
        return;
      case BackupAuthSuccess(:final email):
        await ref.read(backupPreferencesProvider).writeConnectedEmail(email);
        break;
    }

    final file = await ref.read(databaseFileProvider)();
    final db = ref.read(appDatabaseProvider);
    await db.close();
    final syncResult = await backupService.downloadDatabaseTo(file);
    if (syncResult is BackupSyncSuccess) {
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('${file.path}$suffix');
        if (sidecar.existsSync()) sidecar.deleteSync();
      }
      await ref.read(backupPreferencesProvider).writeBackupConnected(true);
      ref.invalidate(appDatabaseProvider);
      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.onCompleted();
      return;
    }
    ref.invalidate(appDatabaseProvider);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _showRestoreUnavailable = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingTopBar(
              stepIndex: _stepIndex,
              backTooltip: localizations.commonBack,
              onBack: _stepIndex == 1 && !_isSaving
                  ? () => setState(() {
                        _stepIndex = 0;
                        _errorMessage = null;
                      })
                  : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.s16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _stepIndex == 0
                        ? _StepOneName(
                            controller: _nameController,
                            errorMessage: _errorMessage,
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                            onNext: _goToStepTwo,
                          )
                        : _StepTwoBackup(
                            isSaving: _isSaving,
                            showRestoreUnavailable: _showRestoreUnavailable,
                            addSampleItems: _addSampleItems,
                            errorMessage: _errorMessage,
                            onAddSampleItemsChanged: (value) =>
                                setState(() => _addSampleItems = value),
                            onNewStore: _completeAsNewStore,
                            onGoogleRestore: () =>
                                unawaited(_restoreFromGoogle()),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.stepIndex,
    required this.backTooltip,
    required this.onBack,
  });

  final int stepIndex;
  final String backTooltip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screenHorizontal,
        AppSpacing.s12,
        AppSpacing.screenHorizontal,
        AppSpacing.s8,
      ),
      child: Row(
        children: [
          if (onBack != null)
            TindaIconButton(
              icon: Icons.arrow_back,
              tooltip: backTooltip,
              onPressed: onBack,
            )
          else
            const TindaLogoMark(size: 40),
          const Spacer(),
          _StepDots(currentStep: stepIndex),
          const Spacer(),
          const SizedBox(width: AppSizes.touchTargetMin),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 2; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.s8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: currentStep == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: currentStep == index
                  ? palette.primary
                  : palette.borderStrong,
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepOneName extends StatelessWidget {
  const _StepOneName({
    required this.controller,
    required this.errorMessage,
    required this.onChanged,
    required this.onNext,
  });

  final TextEditingController controller;
  final String? errorMessage;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s16),
        Text(
          localizations.onboardingStep1Title,
          style: AppTypography.display(palette.text, size: 26),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          localizations.onboardingStep1Subtitle,
          style: AppTypography.body(palette.textMuted, size: 15),
        ),
        const SizedBox(height: AppSpacing.s24),
        TindaTextInput(
          label: localizations.onboardingStoreNameLabel,
          hintText: localizations.onboardingStoreNameHint,
          controller: controller,
          errorText: errorMessage,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onChanged: onChanged,
          onSubmitted: (_) => onNext(),
        ),
        const SizedBox(height: AppSpacing.s24),
        TindaPrimaryButton(
          label: localizations.commonNext,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _StepTwoBackup extends StatelessWidget {
  const _StepTwoBackup({
    required this.isSaving,
    required this.showRestoreUnavailable,
    required this.addSampleItems,
    required this.errorMessage,
    required this.onAddSampleItemsChanged,
    required this.onNewStore,
    required this.onGoogleRestore,
  });

  final bool isSaving;
  final bool showRestoreUnavailable;
  final bool addSampleItems;
  final String? errorMessage;
  final ValueChanged<bool> onAddSampleItemsChanged;
  final VoidCallback onNewStore;
  final VoidCallback onGoogleRestore;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s16),
        Text(
          localizations.onboardingStep2Title,
          style: AppTypography.display(palette.text, size: 26),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          localizations.onboardingStep2Subtitle,
          style: AppTypography.body(palette.textMuted, size: 15),
        ),
        const SizedBox(height: AppSpacing.s24),
        TindaCard(
          borderColor: palette.primary,
          onTap: isSaving ? null : onNewStore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.onboardingNewStoreTitle,
                style: AppTypography.bodyStrong(palette.text, size: 17),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                localizations.onboardingNewStoreSubtitle,
                style: AppTypography.body(palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isSaving
                          ? null
                          : () => onAddSampleItemsChanged(!addSampleItems),
                      child: Text(
                        localizations.onboardingSampleItemsToggle,
                        style: AppTypography.body(palette.text, size: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  TindaToggleSwitch(
                    value: addSampleItems,
                    onChanged: (value) {
                      if (!isSaving) onAddSampleItemsChanged(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              TindaPrimaryButton(
                label: localizations.onboardingNewStoreTitle,
                isLoading: isSaving,
                onPressed: isSaving ? null : onNewStore,
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            errorMessage!,
            style: AppTypography.meta(palette.danger, size: 13),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        TindaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.onboardingRestoreTitle,
                style: AppTypography.bodyStrong(palette.text, size: 17),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                localizations.onboardingRestoreSubtitle,
                style: AppTypography.body(palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.s16),
              TindaGoogleButton(
                label: localizations.onboardingGoogleButton,
                onPressed: isSaving ? null : onGoogleRestore,
              ),
              if (showRestoreUnavailable) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  localizations.onboardingRestoreUnavailable,
                  style: AppTypography.meta(palette.textMuted, size: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
