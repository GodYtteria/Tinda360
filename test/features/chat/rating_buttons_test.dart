import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/features/chat/data/feedback_log.dart';
import 'package:tinda360/features/chat/presentation/chat_notifier.dart';
import 'package:tinda360/features/chat/presentation/chat_sheet.dart';
import 'package:tinda360/features/chat/presentation/clarification_reply.dart';
import 'package:tinda360/l10n/app_delegates.dart';
import 'package:tinda360/l10n/app_localizations.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';
import 'package:tinda360/theme/app_theme.dart';

const double _minimumTapSize = 48;
const double _narrowWidth = 320;
const double _tallHeight = 900;
const int _longAnswerRepeats = 40;
const String _helpfulLabel = 'Helpful answer';
const String _notHelpfulLabel = 'Not helpful';

const List<ClarificationOption> _options = [
  ClarificationOption(toolName: 'get_sales_summary', label: 'Sales summary'),
  ClarificationOption(toolName: 'get_top_products', label: 'Top products'),
];

class _RecordingChatNotifier extends ChatNotifier {
  new(this.initialState);

  final ChatState initialState;
  final List<ChatMessage> ratedMessages = [];
  final List<FeedbackRating> ratings = [];

  @override
  ChatState build() => initialState;

  @override
  Future<void> rateMessage(ChatMessage message, FeedbackRating rating) async {
    ratedMessages.add(message);
    ratings.add(rating);
  }
}

ChatMessage _assistantMessage(
  String id, {
  String text = 'Plain answer',
  String? feedbackEventId,
  FeedbackRating? rating,
  List<ClarificationOption> options = const [],
}) => ChatMessage(
  id: id,
  role: ChatRole.assistant,
  text: text,
  createdAt: DateTime(2026),
  options: options,
  feedbackEventId: feedbackEventId,
  rating: rating,
);

ChatState _state(List<ChatMessage> messages) => ChatState(
  messages: messages,
  mood: TindaAvatarMood.idle,
  isThinking: false,
);

Future<_RecordingChatNotifier> _pumpSheet(
  WidgetTester tester,
  List<ChatMessage> messages, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, _tallHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifier = _RecordingChatNotifier(_state(messages));
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

Finder _upButton() => find.widgetWithIcon(IconButton, Icons.thumb_up_outlined);

Finder _downButton() =>
    find.widgetWithIcon(IconButton, Icons.thumb_down_outlined);

Finder _anyThumb() => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      const [
        Icons.thumb_up,
        Icons.thumb_up_outlined,
        Icons.thumb_down,
        Icons.thumb_down_outlined,
      ].contains(widget.icon),
);

void main() {
  testWidgets('shows both buttons when feedbackEventId is set', (
    tester,
  ) async {
    await _pumpSheet(tester, [_assistantMessage('a1', feedbackEventId: 'e1')]);

    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
  });

  testWidgets('hides buttons when feedbackEventId is null', (tester) async {
    await _pumpSheet(tester, [_assistantMessage('a1')]);

    expect(_anyThumb(), findsNothing);
  });

  testWidgets('hides buttons on a clarification message', (tester) async {
    await _pumpSheet(tester, [
      _assistantMessage('a1', feedbackEventId: 'e1', options: _options),
    ]);

    expect(_anyThumb(), findsNothing);
    expect(find.byType(ActionChip), findsNWidgets(_options.length));
  });

  testWidgets('tapping thumb up rates the message up exactly once', (
    tester,
  ) async {
    final message = _assistantMessage('a1', feedbackEventId: 'e1');
    final notifier = await _pumpSheet(tester, [message]);

    await tester.tap(_upButton());
    await tester.pump();

    expect(notifier.ratings, [FeedbackRating.up]);
    expect(notifier.ratedMessages.single.id, 'a1');
  });

  testWidgets('tapping thumb down rates the message down exactly once', (
    tester,
  ) async {
    final message = _assistantMessage('a1', feedbackEventId: 'e1');
    final notifier = await _pumpSheet(tester, [message]);

    await tester.tap(_downButton());
    await tester.pump();

    expect(notifier.ratings, [FeedbackRating.down]);
    expect(notifier.ratedMessages.single.id, 'a1');
  });

  testWidgets('selected up shows filled up and outlined down', (tester) async {
    await _pumpSheet(tester, [
      _assistantMessage('a1', feedbackEventId: 'e1', rating: FeedbackRating.up),
    ]);

    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down), findsNothing);
  });

  testWidgets('selected down shows filled down and outlined up', (
    tester,
  ) async {
    await _pumpSheet(tester, [
      _assistantMessage(
        'a1',
        feedbackEventId: 'e1',
        rating: FeedbackRating.down,
      ),
    ]);

    expect(find.byIcon(Icons.thumb_down), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsNothing);
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up), findsNothing);
  });

  testWidgets('tapping the selected rating makes no call', (tester) async {
    final notifier = await _pumpSheet(tester, [
      _assistantMessage('a1', feedbackEventId: 'e1', rating: FeedbackRating.up),
    ]);

    await tester.tap(find.byIcon(Icons.thumb_up));
    await tester.pump();

    expect(notifier.ratings, isEmpty);
  });

  testWidgets('changing the rating from up to down makes one call', (
    tester,
  ) async {
    final notifier = await _pumpSheet(tester, [
      _assistantMessage('a1', feedbackEventId: 'e1', rating: FeedbackRating.up),
    ]);

    await tester.tap(_downButton());
    await tester.pump();

    expect(notifier.ratings, [FeedbackRating.down]);
  });

  testWidgets('changing the rating from down to up makes one call', (
    tester,
  ) async {
    final notifier = await _pumpSheet(tester, [
      _assistantMessage(
        'a1',
        feedbackEventId: 'e1',
        rating: FeedbackRating.down,
      ),
    ]);

    await tester.tap(_upButton());
    await tester.pump();

    expect(notifier.ratings, [FeedbackRating.up]);
  });

  testWidgets('a message that is not the latest can still be rated', (
    tester,
  ) async {
    final notifier = await _pumpSheet(tester, [
      _assistantMessage('a1', text: 'First answer', feedbackEventId: 'e1'),
      _assistantMessage('a2', text: 'Second answer', feedbackEventId: 'e2'),
    ]);

    await tester.tap(_upButton().first);
    await tester.pump();

    expect(notifier.ratings, [FeedbackRating.up]);
    expect(notifier.ratedMessages.single.id, 'a1');
  });

  testWidgets('only the message with an event id gets buttons', (
    tester,
  ) async {
    await _pumpSheet(tester, [
      _assistantMessage('a1', text: 'First answer', feedbackEventId: 'e1'),
      _assistantMessage('a2', text: 'Second answer'),
    ]);

    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);
  });

  testWidgets('buttons are at least 48 by 48 with localized labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpSheet(tester, [_assistantMessage('a1', feedbackEventId: 'e1')]);

    for (final entry in {
      _upButton(): _helpfulLabel,
      _downButton(): _notHelpfulLabel,
    }.entries) {
      final size = tester.getSize(entry.key);
      expect(size.width, greaterThanOrEqualTo(_minimumTapSize));
      expect(size.height, greaterThanOrEqualTo(_minimumTapSize));
      expect(
        tester.getSemantics(entry.key).getSemanticsData().tooltip,
        entry.value,
      );
      expect(find.byTooltip(entry.value), findsOneWidget);
    }
    handle.dispose();
  });

  testWidgets('selected state is exposed to semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpSheet(tester, [
      _assistantMessage('a1', feedbackEventId: 'e1', rating: FeedbackRating.up),
    ]);

    final selectedData = tester
        .getSemantics(find.widgetWithIcon(IconButton, Icons.thumb_up))
        .getSemanticsData();
    final unselectedData = tester
        .getSemantics(_downButton())
        .getSemanticsData();

    expect(selectedData.flagsCollection.isSelected, Tristate.isTrue);
    expect(unselectedData.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('does not overflow at 320 width with a long answer', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      [
        _assistantMessage(
          'a1',
          text: List.filled(
            _longAnswerRepeats,
            'sales and utang report',
          ).join(' '),
          feedbackEventId: 'e1',
          rating: FeedbackRating.down,
        ),
      ],
      width: _narrowWidth,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopRight(find.byIcon(Icons.thumb_up_outlined)).dx,
      lessThanOrEqualTo(_narrowWidth),
    );
  });

  testWidgets('rating buttons come after the source line and chips', (
    tester,
  ) async {
    await _pumpSheet(tester, [
      ChatMessage(
        id: 'a1',
        role: ChatRole.assistant,
        text: 'Your sales and utang report',
        createdAt: DateTime(2026),
        source: 'Reports',
        feedbackEventId: 'e1',
      ),
    ]);

    final chipBottom = tester
        .getBottomLeft(find.widgetWithText(ActionChip, 'Reports'))
        .dy;
    final buttonTop = tester.getTopLeft(_upButton()).dy;
    expect(buttonTop, greaterThanOrEqualTo(chipBottom));
  });
}
