part of 'settings_screen.dart';

Future<void> _renameStore(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) async {
  final localizations = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final newName = await showDialog<String>(
    context: context,
    builder: (_) => _StoreNameDialog(
      title: localizations.onboardingStoreNameLabel,
      initialName: currentName,
    ),
  );
  if (newName == null || newName == currentName) return;
  final result = await ref
      .read(storeProfileRepositoryProvider)
      .completeOnboarding(newName);
  if (result case Err(:final failure)) {
    messenger.showSnackBar(
      SnackBar(content: Text(localizedFailureMessage(localizations, failure))),
    );
  }
}

Future<void> _editStoreContact(
  BuildContext context,
  WidgetRef ref, {
  required StoreProfile? profile,
  required bool isAddress,
}) async {
  final localizations = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final label = isAddress
      ? localizations.settingsAddressLabel
      : localizations.settingsPhoneLabel;
  final edited = await showOptionalTextDialog(
    context,
    title: label,
    label: label,
    initialText: (isAddress ? profile?.address : profile?.phone) ?? '',
    keyboardType: isAddress ? null : TextInputType.phone,
  );
  if (edited == null) return;
  final result = await ref
      .read(storeProfileRepositoryProvider)
      .updateContact(
        address: isAddress ? edited : profile?.address,
        phone: isAddress ? profile?.phone : edited,
      );
  if (result case Err(:final failure)) {
    messenger.showSnackBar(
      SnackBar(content: Text(localizedFailureMessage(localizations, failure))),
    );
  }
}

class _StoreSwitcherSection extends ConsumerWidget {
  const _StoreSwitcherSection({required this.activeStoreName});

  final String activeStoreName;

  Future<void> _showAddStoreDialog(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final createdName = await showDialog<String>(
      context: context,
      builder: (_) => _StoreNameDialog(title: localizations.settingsAddStore),
    );
    if (createdName == null || createdName.isEmpty) return;
    try {
      await ref.read(storeRegistryProvider.notifier).createStore(createdName);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLogProvider)
          .error('settings_add_store_failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.settingsAddStoreFailed)),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context).settingsAddStore}: $createdName',
        ),
      ),
    );
  }

  Future<void> _confirmSwitchStore(
    BuildContext context,
    WidgetRef ref,
    StoreEntry store,
    String displayName,
  ) async {
    final localizations = AppLocalizations.of(context);
    final router = ref.read(appRouterProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsSwitchStore),
        content: Text(localizations.settingsSwitchStoreConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () {
              unawaited(HapticFeedback.mediumImpact());
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(localizations.commonSwitch),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final registry = ref.read(storeRegistryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await leaveScreensReadingDatabase(router);
      await registry.switchStore(store.id);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLogProvider)
          .error('settings_switch_store_failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localizations.settingsSwitchStoreFailed,
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteStore(
    BuildContext context,
    WidgetRef ref,
    StoreEntry store,
    String displayName,
  ) async {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final router = ref.read(appRouterProvider);
    final wasActive =
        store.id == ref.read(storeRegistryProvider).value?.activeStoreId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.settingsDeleteStore),
        content: Text(localizations.settingsDeleteStoreConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.commonCancel),
          ),
          TextButton(
            onPressed: () {
              unawaited(HapticFeedback.mediumImpact());
              Navigator.of(dialogContext).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: Text(localizations.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final verified = await confirmStorePinIfSet(
      context,
      ref,
      title: localizations.settingsPinPromptTitle,
    );
    if (!verified || !context.mounted) return;
    final registry = ref.read(storeRegistryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (wasActive) await leaveScreensReadingDatabase(router);
      await registry.deleteStore(store.id);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLogProvider)
          .error('settings_delete_store_failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localizations.settingsDeleteStoreFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final registry =
        ref.watch(storeRegistryProvider).value ??
        StoreRegistry.defaultRegistry();
    String displayNameOf(StoreEntry store) {
      if (store.id == registry.activeStoreId && activeStoreName.isNotEmpty) {
        return activeStoreName;
      }
      return store.name.isNotEmpty ? store.name : '—';
    }

    return TindaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizations.settingsSwitchStore,
            style: AppTypography.bodyStrong(palette.text),
          ),
          const SizedBox(height: AppSpacing.s10),
          for (final store in registry.stores) ...[
            _StoreRow(
              displayName: displayNameOf(store),
              isActive: store.id == registry.activeStoreId,
              onSwitch: store.id == registry.activeStoreId
                  ? null
                  : () {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(
                        _confirmSwitchStore(
                          context,
                          ref,
                          store,
                          displayNameOf(store),
                        ),
                      );
                    },
              onDelete: () => unawaited(
                _confirmDeleteStore(
                  context,
                  ref,
                  store,
                  store.name.isNotEmpty
                      ? store.name
                      : (store.id == registry.activeStoreId &&
                                activeStoreName.isNotEmpty
                            ? activeStoreName
                            : store.id),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          const SizedBox(height: AppSpacing.s4),
          TindaSecondaryButton(
            label: localizations.settingsAddStore,
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(_showAddStoreDialog(context, ref));
            },
          ),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({
    required this.displayName,
    required this.isActive,
    required this.onSwitch,
    required this.onDelete,
  });

  final String displayName;
  final bool isActive;
  final VoidCallback? onSwitch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
      ),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isActive ? palette.surfaceMuted : palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.smallButton),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSwitch,
          borderRadius: BorderRadius.circular(AppRadii.smallButton),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: AppTypography.bodyStrong(palette.text),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: TindaBadge(label: localizations.settingsActiveBadge),
                  ),
                ],
                const SizedBox(width: AppSpacing.s4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: palette.danger,
                    size: 20,
                  ),
                  tooltip: localizations.settingsDeleteStore,
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreNameDialog extends StatefulWidget {
  const _StoreNameDialog({required this.title, this.initialName = ''});

  final String title;
  final String initialName;

  @override
  State<_StoreNameDialog> createState() => _StoreNameDialogState();
}

class _StoreNameDialogState extends State<_StoreNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _inlineError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations localizations) {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      unawaited(HapticFeedback.heavyImpact());
      setState(() => _inlineError = localizations.failureStoreNameRequired);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TindaTextInput(
        label: localizations.onboardingStoreNameLabel,
        hintText: localizations.onboardingStoreNameHint,
        controller: _controller,
        errorText: _inlineError,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_inlineError != null) {
            setState(() => _inlineError = null);
          }
        },
        onSubmitted: (_) => _submit(localizations),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.commonCancel),
        ),
        TextButton(
          onPressed: () => _submit(localizations),
          child: Text(localizations.commonSave),
        ),
      ],
    );
  }
}
