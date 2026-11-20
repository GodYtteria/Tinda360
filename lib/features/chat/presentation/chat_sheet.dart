import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/calendar/time_greeting.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';
import 'package:tinda360/features/chat/presentation/yumi_screen.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/shared/widgets/tinda_buttons.dart';
import 'package:tinda360/shared/widgets/tinda_inputs.dart';
import 'package:tinda360/theme/app_palette.dart';
import 'package:tinda360/theme/app_tokens.dart';

const double _clarificationChipMinHeight = 48;
const double _ratingButtonSize = 48;

class ChatSheet extends ConsumerStatefulWidget {
  const new({
    super.key,
    this.contextHint,
    this.extraSuggestions = const [],
    this.onOpenTab,
  });

  final String? contextHint;

  final List<String> extraSuggestions;

  final ValueChanged<int>? onOpenTab;

  static Future<void> show(
    BuildContext context, {
    String? contextHint,
    List<String> extraSuggestions = const [],
    ValueChanged<int>? onOpenTab,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppPalette.of(context).scrim,
    builder: (_) => ChatSheet(
      contextHint: contextHint,
      extraSuggestions: extraSuggestions,
      onOpenTab: onOpenTab,
    ),
  );

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  String? _revealingMessageId;
  final Set<String> _revealedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final shouldShow = max - offset > 120;
    if (shouldShow != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendCurrentText(AppLocalizations localizations) {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    if (ref.read(chatNotifierProvider).isThinking) return;
    _inputController.clear();
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      ref.read(chatNotifierProvider.notifier).sendMessage(text, localizations),
    );
    _scrollToBottom(force: true);
  }

  void _sendSuggestion(String suggestion, AppLocalizations localizations) {
    if (ref.read(chatNotifierProvider).isThinking) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      ref
          .read(chatNotifierProvider.notifier)
          .sendMessage(suggestion, localizations),
    );
    _scrollToBottom(force: true);
  }

  void _answerClarification(
    ChatMessage clarification,
    ClarificationOption option,
    AppLocalizations localizations,
  ) {
    if (ref.read(chatNotifierProvider).isThinking) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      ref
          .read(chatNotifierProvider.notifier)
          .answerClarification(clarification, option, localizations),
    );
    _scrollToBottom(force: true);
  }

  void _rateMessage(ChatMessage message, FeedbackRating rating) {
    if (message.rating == rating) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      ref.read(chatNotifierProvider.notifier).rateMessage(message, rating),
    );
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final offset = _scrollController.offset;
      final nearBottom = max - offset <= 140;
      if (!force && !nearBottom) {
        if (!_showScrollToBottom) setState(() => _showScrollToBottom = true);
        return;
      }
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      if (_showScrollToBottom) setState(() => _showScrollToBottom = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final chatState = ref.watch(chatNotifierProvider);
    final yumiScreen = ref.watch(yumiScreenProvider);
    if (_revealedIds.isEmpty && chatState.messages.isNotEmpty) {
      _revealedIds.addAll(chatState.messages.map((m) => m.id));
    }
    ref.listen<ChatState>(chatNotifierProvider, (previous, next) {
      if (previous != null && next.messages.length > previous.messages.length) {
        final last = next.messages.last;
        if (last.role == ChatRole.assistant) {
          _revealedIds.remove(last.id);
          _revealingMessageId = last.id;
        }
      }
      if (previous?.messages.length != next.messages.length ||
          previous?.isThinking != next.isThinking) {
        _scrollToBottom();
      }
    });
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight - viewInsets.bottom).clamp(360.0, 560.0);

    return Container(
      margin: EdgeInsets.only(bottom: viewInsets.bottom),
      height: sheetHeight,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheetTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: palette.borderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            _ChatHeader(
              mood: chatState.mood,
              isThinking: chatState.isThinking,
              onClose: () => Navigator.of(context).pop(),
            ),
            Divider(height: 1, color: palette.border),
            if (widget.contextHint case final hint?) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.sheetPadding,
                  AppSpacing.s8,
                  AppSpacing.sheetPadding,
                  0,
                ),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                ),
                child: Text(
                  hint,
                  style: AppTypography.meta(palette.onAccentSoft, size: 12),
                ),
              ),
            ],
            Expanded(
              child: Stack(
                children: [
                  _MessageList(
                    messages: chatState.messages,
                    yumiScreen: yumiScreen,
                    isThinking: chatState.isThinking,
                    scrollController: _scrollController,
                    revealingMessageId: _revealingMessageId,
                    onRevealComplete: (id) {
                      if (!mounted) return;
                      setState(() {
                        _revealedIds.add(id);
                        if (_revealingMessageId == id) {
                          _revealingMessageId = null;
                        }
                      });
                    },
                    onSelectOption: (clarification, option) =>
                        _answerClarification(
                          clarification,
                          option,
                          localizations,
                        ),
                    onRate: _rateMessage,
                    onOpenTab: widget.onOpenTab == null
                        ? null
                        : (index) {
                            Navigator.of(context).pop();
                            widget.onOpenTab!(index);
                          },
                  ),
                  if (_showScrollToBottom)
                    Positioned(
                      right: AppSpacing.s12,
                      bottom: AppSpacing.s12,
                      child: Material(
                        color: palette.primary,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _scrollToBottom(force: true),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: palette.onPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _SuggestionBar(
              enabled: !chatState.isThinking,
              onSelect: (suggestion) =>
                  _sendSuggestion(suggestion, localizations),
              suggestions: [
                ...widget.extraSuggestions,
                ...yumiSuggestionsFor(yumiScreen, localizations),
              ],
            ),
            _ChatInputBar(
              controller: _inputController,
              enabled: !chatState.isThinking,
              onSend: () => _sendCurrentText(localizations),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const new({
    required this.mood,
    required this.isThinking,
    required this.onClose,
  });

  final TindaAvatarMood mood;
  final bool isThinking;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final statusText = isThinking
        ? localizations.chatStatusThinking
        : localizations.chatStatusOffline;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sheetPadding,
        AppSpacing.s12,
        AppSpacing.sheetPadding,
        AppSpacing.s12,
      ),
      child: Row(
        children: [
          TindaAiAvatar(size: 44, mood: mood),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.chatTitle,
                  style: AppTypography.title(palette.text),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    TindaStatusDot(
                      active: true,
                      color: isThinking ? palette.accent : palette.success,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Flexible(
                      child: Text(
                        statusText,
                        style: AppTypography.meta(palette.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TindaIconButton(
            icon: Icons.close,
            tooltip: localizations.commonClose,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const new({
    required this.messages,
    required this.yumiScreen,
    required this.isThinking,
    required this.scrollController,
    required this.onSelectOption,
    required this.onRate,
    this.revealingMessageId,
    this.onRevealComplete,
    this.onOpenTab,
  });

  final List<ChatMessage> messages;
  final YumiScreen yumiScreen;
  final bool isThinking;
  final ScrollController scrollController;
  final void Function(ChatMessage clarification, ClarificationOption option)
  onSelectOption;
  final void Function(ChatMessage message, FeedbackRating rating) onRate;
  final String? revealingMessageId;
  final ValueChanged<String>? onRevealComplete;
  final ValueChanged<int>? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final itemCount = messages.length + (isThinking ? 1 : 0);
    if (itemCount == 0) {
      final isFilipino = localizations.localeName.startsWith('fil');
      final welcome = ChatMessage(
        id: 'welcome',
        role: ChatRole.assistant,
        text:
            '${localizations.chatWelcomeMessage(timeOfDayGreeting(DateTime.now(), isFilipino: isFilipino))} '
            '${yumiHintFor(yumiScreen, localizations)}',
        createdAt: DateTime.now(),
        source: localizations.chatTitle,
      );
      return ListView(
        controller: scrollController,
        padding: const EdgeInsetsDirectional.all(AppSpacing.sheetPadding),
        children: [_AssistantBubble(message: welcome)],
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsetsDirectional.all(AppSpacing.sheetPadding),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, index) {
        if (isThinking && index == messages.length) {
          return _ThinkingBubble(label: localizations.chatThinkingBubble);
        }
        final message = messages[index];
        return message.role == ChatRole.user
            ? _UserBubble(text: message.text)
            : _AssistantBubble(
                message: message,
                animate: message.id == revealingMessageId,
                onRevealComplete: onRevealComplete == null
                    ? null
                    : () => onRevealComplete!(message.id),
                onSelectOption: index == messages.length - 1 && !isThinking
                    ? (option) => onSelectOption(message, option)
                    : null,
                onOpenTab: onOpenTab,
                onRate: (rating) => onRate(message, rating),
              );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Material(
          color: palette.primary,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onLongPress: () => Clipboard.setData(ClipboardData(text: text)),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.s14,
                vertical: AppSpacing.s10,
              ),
              child: Text(
                text,
                style: AppTypography.body(palette.onPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const new({
    required this.message,
    this.animate = false,
    this.onRevealComplete,
    this.onSelectOption,
    this.onOpenTab,
    this.onRate,
  });

  final ChatMessage message;
  final bool animate;
  final VoidCallback? onRevealComplete;
  final ValueChanged<ClarificationOption>? onSelectOption;
  final ValueChanged<int>? onOpenTab;
  final ValueChanged<FeedbackRating>? onRate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TindaAiAvatar(size: 28),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  onLongPress: () =>
                      Clipboard.setData(ClipboardData(text: message.text)),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.s14,
                      vertical: AppSpacing.s10,
                    ),
                    child: animate
                        ? _ProgressiveText(
                            text: message.text,
                            style: AppTypography.body(palette.text),
                            onDone: onRevealComplete,
                          )
                        : Text(
                            message.text,
                            style: AppTypography.body(palette.text),
                          ),
                  ),
                ),
              ),
              if (message.source != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  localizations.chatSourcePrefix(message.source!),
                  style: AppTypography.meta(palette.textMuted),
                ),
              ],
              if (message.options.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final option in message.options)
                      Semantics(
                        button: true,
                        enabled: onSelectOption != null,
                        label: option.label,
                        excludeSemantics: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: _clarificationChipMinHeight,
                          ),
                          child: ActionChip(
                            label: Text(option.label),
                            onPressed: onSelectOption == null
                                ? null
                                : () => onSelectOption!(option),
                          ),
                        ),
                      ),
                  ],
                ),
              ] else if (onOpenTab != null) ...[
                for (final action in _suggestedActions(message, localizations))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: ActionChip(
                      label: Text(action.label),
                      onPressed: () => onOpenTab!(action.tabIndex),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
              if (message.feedbackEventId != null &&
                  message.options.isEmpty &&
                  onRate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RatingButton(
                      outlinedIcon: Icons.thumb_up_outlined,
                      filledIcon: Icons.thumb_up,
                      tooltip: localizations.chatFeedbackHelpful,
                      selected: message.rating == FeedbackRating.up,
                      onPressed: () => onRate!(FeedbackRating.up),
                    ),
                    _RatingButton(
                      outlinedIcon: Icons.thumb_down_outlined,
                      filledIcon: Icons.thumb_down,
                      tooltip: localizations.chatFeedbackNotHelpful,
                      selected: message.rating == FeedbackRating.down,
                      onPressed: () => onRate!(FeedbackRating.down),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const new({
    required this.outlinedIcon,
    required this.filledIcon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData outlinedIcon;
  final IconData filledIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      constraints: const BoxConstraints.tightFor(
        width: _ratingButtonSize,
        height: _ratingButtonSize,
      ),
      icon: Icon(outlinedIcon, color: palette.textMuted),
      selectedIcon: Icon(filledIcon, color: palette.accent),
      onPressed: onPressed,
    );
  }
}

class _AssistantAction {
  const new(this.label, this.tabIndex);
  final String label;
  final int tabIndex;
}

List<_AssistantAction> _suggestedActions(
  ChatMessage message,
  AppLocalizations localizations,
) {
  final text = '${message.text} ${message.source ?? ''}'.toLowerCase();
  final actions = <_AssistantAction>[];
  if (text.contains('stock') ||
      text.contains('imbentaryo') ||
      text.contains('restock') ||
      text.contains('mababa')) {
    actions.add(_AssistantAction(localizations.navInventory, 1));
  }
  if (text.contains('utang') ||
      text.contains('suki') ||
      text.contains('credit') ||
      text.contains('may utang')) {
    actions.add(_AssistantAction(localizations.navUtang, 2));
  }
  if (text.contains('sales') ||
      text.contains('benta') ||
      text.contains('profit') ||
      text.contains('report') ||
      text.contains('ulat') ||
      text.contains('top')) {
    actions.add(_AssistantAction(localizations.navReports, 3));
  }
  if (actions.isEmpty) return const [];
  final seen = <int>{};
  return actions.where((action) => seen.add(action.tabIndex)).take(2).toList();
}

class _ProgressiveText extends StatefulWidget {
  const new({
    required this.text,
    required this.style,
    this.onDone,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onDone;

  @override
  State<_ProgressiveText> createState() => _ProgressiveTextState();
}

class _ProgressiveTextState extends State<_ProgressiveText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final length = widget.text.length.clamp(1, 400);
    final millis = (length * 12).clamp(300, 1400);
    _controller =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: millis),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onDone?.call();
            }
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final count = (widget.text.length * _controller.value).ceil().clamp(
          0,
          widget.text.length,
        );
        final visible = widget.text.substring(0, count);
        return Text(visible, style: widget.style);
      },
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const new({required this.label});

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
    if (MediaQuery.disableAnimationsOf(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final t = (_controller.value + index / 3) % 1.0;
          final opacity = 0.25 + 0.75 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SuggestionBar extends StatelessWidget {
  const new({
    required this.suggestions,
    required this.onSelect,
    this.enabled = true,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: enabled ? 1 : 0.5,
    duration: const Duration(milliseconds: 150),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sheetPadding,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          for (var index = 0; index < suggestions.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.s8),
            TindaFilterChip(
              label: suggestions[index],
              selected: false,
              onTap: enabled ? () => onSelect(suggestions[index]) : null,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ChatInputBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.onSend,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sheetPadding,
        AppSpacing.s8,
        AppSpacing.sheetPadding,
        AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: AppTypography.body(palette.text),
              decoration: InputDecoration(
                hintText: localizations.chatInputHint,
                hintStyle: AppTypography.body(palette.textMuted),
                filled: true,
                fillColor: palette.surfaceMuted,
                contentPadding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Semantics(
            button: true,
            label: localizations.chatSend,
            child: Tooltip(
              message: localizations.chatSend,
              child: Material(
                color: enabled ? palette.primary : palette.borderStrong,
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: InkWell(
                  onTap: enabled ? onSend : null,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  child: SizedBox(
                    width: AppSizes.touchTargetMin,
                    height: AppSizes.touchTargetMin,
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: palette.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
