import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/theme/app_theme.dart';

const double _minimumTapHeight = 48;
const double _narrowWidth = 320;
const double _thinkingBubbleWidth = 700;
const double _tallHeight = 900;
const int _longLabelLength = 32;

const List<ClarificationOption> _options = [
  ClarificationOption(toolName: 'get_sales_summary', label: 'Sales summary'),
  ClarificationOption(toolName: 'get_top_products', label: 'Top products'),
  ClarificationOption(toolName: 'get_low_stock', label: 'Low stock items'),
];

class _RecordingChatNotifier extends ChatNotifier {
  new(this.initialState);

  final ChatState initialState;
  final List<ClarificationOption> answered = [];

  @override
  ChatState build() => initialState;

  @override
  Future<void> answerClarification(
    ClarificationOption option,
    AppLocalizations localizations,
  ) async {
    answered.add(option);
  }
}

ChatMessage _assistantMessage(
  String id,
  String text, {
  List<ClarificationOption>? options,
}) => options == null
    ? ChatMessage(
        id: id,
        role: ChatRole.assistant,
        text: text,
        createdAt: DateTime(2026),
      )
    : ChatMessage(
        id: id,
        role: ChatRole.assistant,
        text: text,
        createdAt: DateTime(2026),
        options: options,
      );

ChatState _state(List<ChatMessage> messages, {bool isThinking = false}) =>
    ChatState(
      messages: messages,
      mood: TindaAvatarMood.idle,
      isThinking: isThinking,
    );

Future<_RecordingChatNotifier> _pumpSheet(
  WidgetTester tester,
  ChatState state, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, _tallHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifier = _RecordingChatNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChatSheet(onOpenTab: (_) {})),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return notifier;
}

Finder _chip(String label) => find.widgetWithText(ActionChip, label);

bool _isEnabled(WidgetTester tester, String label) =>
    tester.widget<ActionChip>(_chip(label)).onPressed != null;

void main() {
  testWidgets('shows one chip per option in order', (tester) async {
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Which one?', options: _options)]),
    );

    final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
    final labels = chips.map((chip) => (chip.label as Text).data).toList();
    expect(labels, ['Sales summary', 'Top products', 'Low stock items']);
    final firstLeft = tester.getTopLeft(_chip('Sales summary'));
    final secondLeft = tester.getTopLeft(_chip('Top products'));
    expect(
      secondLeft.dx > firstLeft.dx || secondLeft.dy > firstLeft.dy,
      isTrue,
    );
  });

  testWidgets('tapping a chip answers the clarification exactly once', (
    tester,
  ) async {
    final notifier = await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Which one?', options: _options)]),
    );

    await tester.tap(_chip('Top products'));
    await tester.pump();

    expect(notifier.answered, hasLength(1));
    expect(notifier.answered.single.toolName, 'get_top_products');
    expect(notifier.answered.single.label, 'Top products');
  });

  testWidgets('chips on an older message are disabled', (tester) async {
    final notifier = await _pumpSheet(
      tester,
      _state([
        _assistantMessage('a1', 'Which one?', options: _options),
        _assistantMessage('a2', 'Later answer'),
      ]),
    );

    expect(_isEnabled(tester, 'Sales summary'), isFalse);
    await tester.tap(_chip('Sales summary'), warnIfMissed: false);
    await tester.pump();

    expect(notifier.answered, isEmpty);
  });

  testWidgets('chips are disabled while the assistant is thinking', (
    tester,
  ) async {
    final notifier = await _pumpSheet(
      tester,
      _state([
        _assistantMessage('a1', 'Which one?', options: _options),
      ], isThinking: true),
      width: _thinkingBubbleWidth,
    );

    expect(_isEnabled(tester, 'Sales summary'), isFalse);
    await tester.tap(_chip('Sales summary'), warnIfMissed: false);
    await tester.pump();

    expect(notifier.answered, isEmpty);
  });

  testWidgets('latest message chips are enabled when not thinking', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Which one?', options: _options)]),
    );

    for (final option in _options) {
      expect(_isEnabled(tester, option.label), isTrue, reason: option.label);
    }
  });

  testWidgets('a message without options shows no chips', (tester) async {
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Hello there')]),
    );

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('tab shortcut chips stay for messages without options', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Your sales and utang report')]),
    );

    expect(find.byType(ActionChip), findsWidgets);
    expect(find.widgetWithText(ActionChip, 'Reports'), findsOneWidget);
  });

  testWidgets('tab shortcut chips are hidden when options are present', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      _state([
        _assistantMessage(
          'a1',
          'Which sales or utang report did you mean?',
          options: _options,
        ),
      ]),
    );

    expect(find.byType(ActionChip), findsNWidgets(_options.length));
    expect(find.widgetWithText(ActionChip, 'Reports'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Utang'), findsNothing);
  });

  testWidgets('each chip is at least 48 tall with a matching semantics label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Which one?', options: _options)]),
    );

    for (final option in _options) {
      final semanticsFinder = find.ancestor(
        of: _chip(option.label),
        matching: find.byType(Semantics),
      );
      final height = tester.getSize(_chip(option.label)).height;
      expect(height, greaterThanOrEqualTo(_minimumTapHeight));
      expect(
        tester.getSemantics(semanticsFinder.first).label,
        option.label,
      );
    }
    handle.dispose();
  });

  testWidgets('three long labels do not overflow at 320 width', (
    tester,
  ) async {
    final longOptions = [
      for (var index = 0; index < 3; index++)
        ClarificationOption(
          toolName: 'tool_$index',
          label: List.filled(_longLabelLength, 'abc'[index]).join(),
        ),
    ];
    await _pumpSheet(
      tester,
      _state([_assistantMessage('a1', 'Which one?', options: longOptions)]),
      width: _narrowWidth,
    );

    expect(tester.takeException(), isNull);
    for (final option in longOptions) {
      expect(_chip(option.label), findsOneWidget);
      final right = tester.getTopRight(_chip(option.label)).dx;
      expect(right, lessThanOrEqualTo(_narrowWidth));
    }
  });
}
