import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/tool_argument_parser.dart';

const String _queriesDirectory = 'ai-model/queries';
const String _separator = '||';
const double _minimumAgreement = 0.98;
const Map<String, Map<String, Object>> _toolDefaults =
    <String, Map<String, Object>>{
      'get_low_stock': <String, Object>{'threshold': 5},
      'get_utang_list': <String, Object>{'min_balance': 0},
      'get_utang_risk': <String, Object>{'days_overdue': 30},
      'get_expiry_alerts': <String, Object>{'days_ahead': 7},
      'get_slow_moving': <String, Object>{'days': 14},
      'get_sales_trend': <String, Object>{'days': 7},
      'get_profit_margins': <String, Object>{'sort': 'highest', 'limit': 10},
      'get_suki_loyalty': <String, Object>{'sort_by': 'spend', 'limit': 10},
      'get_restock_suggestions': <String, Object>{'limit': 10},
      'get_top_products': <String, Object>{'limit': 5},
    };

final class _Case {
  const new(this.tool, this.query, this.expected);

  final String tool;
  final String query;
  final Map<String, dynamic> expected;
}

List<_Case> _loadCases() {
  final cases = <_Case>[];
  for (final tool in _toolDefaults.keys) {
    var sectionArguments = <String, dynamic>{};
    for (final line in File('$_queriesDirectory/$tool.txt').readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('@')) {
        sectionArguments =
            jsonDecode(trimmed.substring(1).trim()) as Map<String, dynamic>;
        continue;
      }
      final parts = trimmed.split(_separator);
      final arguments = parts.length > 1
          ? jsonDecode(parts[1].trim()) as Map<String, dynamic>
          : sectionArguments;
      cases.add(_Case(tool, parts.first.trim(), arguments));
    }
  }
  return cases;
}

bool _agrees(_Case testCase, Map<String, dynamic>? parsed) {
  final defaults = _toolDefaults[testCase.tool]!;
  final effective = <String, dynamic>{...defaults, ...?parsed}
    ..remove('timeframe');
  final expected = <String, dynamic>{...defaults, ...testCase.expected}
    ..remove('timeframe');
  if (effective.length != expected.length) return false;
  return expected.entries.every(
    (entry) => '${effective[entry.key]}' == '${entry.value}',
  );
}

void main() {
  const parser = ToolArgumentParser();

  Map<String, dynamic>? parse(String tool, String query) =>
      parser.parse(tool, query, timeframe: 'week');

  group('explicit numbers', () {
    test('utang balance threshold in digits and words', () {
      expect(parse('get_utang_list', 'sino ang may utang na lampas 500'), {
        'min_balance': 500,
      });
      expect(parse('get_utang_list', 'utang na higit isang libo'), {
        'min_balance': 1000,
      });
      expect(parse('get_utang_list', 'mga balance na lampas dalawang daan'), {
        'min_balance': 200,
      });
    });

    test('durations convert weeks and months to days', () {
      expect(parse('get_utang_risk', 'sino ang 2 weeks late na'), {
        'days_overdue': 14,
      });
      expect(parse('get_expiry_alerts', 'mapapaso sa loob ng isang buwan'), {
        'days_ahead': 30,
      });
      expect(parse('get_slow_moving', 'hindi nabenta nitong 3 araw'), {
        'days': 3,
      });
    });

    test('restock separates budget from limit', () {
      expect(parse('get_restock_suggestions', 'may budget akong 2000'), {
        'budget': 2000,
      });
      expect(
        parse('get_restock_suggestions', 'top 5 na dapat kong i-restock'),
        {
          'limit': 5,
        },
      );
    });

    test('ranking tools read limit and sort direction', () {
      expect(parse('get_top_products', 'top 3 ngayong linggo'), {
        'timeframe': 'week',
        'limit': 3,
      });
      expect(parse('get_profit_margins', 'tatlong pinakamaliit ang tubo'), {
        'sort': 'lowest',
        'limit': 3,
      });
      expect(parse('get_suki_loyalty', 'sino ang pinakamadalas bumisita'), {
        'sort_by': 'visits',
      });
    });
  });

  group('nothing explicit', () {
    test('a plain question yields no arguments', () {
      expect(parse('get_utang_list', 'sino ang may utang'), isNull);
      expect(parse('get_low_stock', 'ano ang paubos na'), isNull);
      expect(parse('get_top_products', 'ano ang pinakamabenta'), isNull);
      expect(parse('get_utang_list', ''), isNull);
    });

    test('an article is not read as the number one', () {
      expect(parse('get_utang_list', 'may isang suki na may utang'), isNull);
    });

    test('tools without numeric arguments yield nothing', () {
      expect(parse('get_store_info', 'top 5 store info 2000'), isNull);
      expect(parse('not_a_tool', 'lampas 500'), isNull);
    });
  });

  test(
    'parser agrees with the arguments written in the query files',
    () {
      final cases = _loadCases();
      expect(cases, isNotEmpty);
      final disagreements = <String>[];
      for (final testCase in cases) {
        final parsed = parse(testCase.tool, testCase.query);
        if (!_agrees(testCase, parsed)) {
          disagreements.add(
            '${testCase.tool}: "${testCase.query}" parsed $parsed, '
            'expected ${testCase.expected}',
          );
        }
      }
      final agreement = 1 - disagreements.length / cases.length;
      printOnFailure(disagreements.join('\n'));
      printOnFailure('agreement $agreement over ${cases.length}');
      expect(agreement, greaterThanOrEqualTo(_minimumAgreement));
    },
    skip: Directory(_queriesDirectory).existsSync()
        ? false
        : 'no ai-model data',
  );
}
