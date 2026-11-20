import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/features/chat/presentation/chat_tool_result_replies.dart';
import 'package:tinda360/l10n/app_localizations.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  String reply(String toolName, Map<String, dynamic> result) =>
      replyFromToolResult(
        toolName: toolName,
        result: result,
        isFilipino: false,
        localizations: english,
        currency: Currency.php,
      )!.text;

  test('empty utang list names the minimum balance filter', () {
    final filtered = reply('get_utang_list', <String, dynamic>{
      'min_balance_minor': 50000,
      'customers': <Object>[],
    });
    expect(filtered, contains('500'));
    expect(filtered, isNot(contains('No customers have an outstanding')));

    final unfiltered = reply('get_utang_list', <String, dynamic>{
      'min_balance_minor': 0,
      'customers': <Object>[],
    });
    expect(unfiltered, contains('No customers have an outstanding'));
  });

  test('empty restock list blames the budget only when items need it', () {
    final overBudget = reply('get_restock_suggestions', <String, dynamic>{
      'budget_minor': 10000,
      'candidate_count': 3,
      'suggestions': <Object>[],
    });
    expect(overBudget, contains('budget'));

    final nothingNeeded = reply('get_restock_suggestions', <String, dynamic>{
      'budget_minor': 10000,
      'candidate_count': 0,
      'suggestions': <Object>[],
    });
    expect(nothingNeeded, 'No restock suggestions right now.');
  });
}
