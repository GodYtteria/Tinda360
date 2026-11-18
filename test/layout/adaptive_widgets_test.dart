import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/shared/widgets/adaptive_widgets.dart';
import 'package:tinda360/theme/adaptive_layout.dart';

Widget _host({
  required double width,
  required Widget child,
  double textScale = 1.0,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  group('MoneyText', () {
    testWidgets('keeps a huge amount on one line at a narrow width', (
      tester,
    ) async {
      const hugeAmount = Money(123456789012, Currency.php);
      await tester.pumpWidget(
        _host(
          width: 80,
          child: Row(
            children: [
              Flexible(
                child: MoneyText(
                  hugeAmount,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ],
          ),
        ),
      );

      final textFinder = find.byType(Text);
      final renderParagraph = tester.renderObject<RenderParagraph>(textFinder);
      final lineMetrics = renderParagraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: renderParagraph.text.toPlainText().length,
        ),
      );
      expect(lineMetrics.map((box) => box.top).toSet().length, 1);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(MoneyText)).width,
        lessThanOrEqualTo(80),
      );
    });

    testWidgets('does not scale a short amount in a wide container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          width: 400,
          child: MoneyText(
            const Money(54500, Currency.php),
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );

      final scale = tester.widget<FittedBox>(find.byType(FittedBox)).fit;
      expect(scale, BoxFit.scaleDown);
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.data, '₱545.00');
    });
  });

  group('AdaptiveBadges', () {
    const contentKey = ValueKey('content');
    const badgeKey = ValueKey('badge');

    Widget badges() => const AdaptiveBadges(
      content: SizedBox(key: contentKey, height: 40, child: Text('Product')),
      badges: [SizedBox(key: badgeKey, width: 60, height: 20)],
    );

    testWidgets('places badges beside the content on a wide screen', (
      tester,
    ) async {
      await tester.pumpWidget(_host(width: 420, child: badges()));

      final contentRect = tester.getRect(find.byKey(contentKey));
      final badgeRect = tester.getRect(find.byKey(badgeKey));
      expect(badgeRect.left, greaterThanOrEqualTo(contentRect.right));
    });

    testWidgets('places badges below the content on a compact screen', (
      tester,
    ) async {
      await tester.pumpWidget(_host(width: 320, child: badges()));

      final contentRect = tester.getRect(find.byKey(contentKey));
      final badgeRect = tester.getRect(find.byKey(badgeKey));
      expect(badgeRect.top, greaterThanOrEqualTo(contentRect.bottom));
    });

    testWidgets('places badges below the content at large text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(width: 420, textScale: 1.5, child: badges()),
      );

      final contentRect = tester.getRect(find.byKey(contentKey));
      final badgeRect = tester.getRect(find.byKey(badgeKey));
      expect(badgeRect.top, greaterThanOrEqualTo(contentRect.bottom));
    });

    test('breakpoints follow the named widths', () {
      expect(AdaptiveWidth.ofWidth(320), AdaptiveWidth.compact);
      expect(AdaptiveWidth.ofWidth(360), AdaptiveWidth.regular);
      expect(AdaptiveWidth.ofWidth(599), AdaptiveWidth.regular);
      expect(AdaptiveWidth.ofWidth(600), AdaptiveWidth.wide);
    });
  });
}
