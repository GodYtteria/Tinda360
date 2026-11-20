import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/tool_call_validator.dart';

void main() {
  final toolsJson = File('assets/ai/tools.json').readAsStringSync();
  final validator = ToolCallValidator.fromToolsJson(toolsJson);
  const question = 'Magkano ang Coke, ice at Señor Pedro?';

  ToolCallValidation check(
    String? toolName,
    Map<String, dynamic>? arguments, {
    String text = question,
  }) {
    return validator.validate(toolName, arguments, question: text);
  }

  void expectRejected(
    ToolCallValidation result,
    ToolCallRejection rejection, [
    String? argument,
  ]) {
    expect(result.isValid, isFalse);
    expect(result.rejection, rejection);
    expect(result.rejectedArgument, argument);
  }

  group('tool names', () {
    test(
      'every tool in tools.json is accepted with valid minimal arguments',
      () {
        final tools = jsonDecode(toolsJson) as List<dynamic>;
        expect(tools, isNotEmpty);
        for (final tool in tools) {
          final function =
              (tool as Map<String, dynamic>)['function']
                  as Map<String, dynamic>;
          final parameters = function['parameters'] as Map<String, dynamic>;
          final properties =
              (parameters['properties'] as Map<String, dynamic>?) ?? const {};
          final required =
              ((parameters['required'] as List<dynamic>?) ?? const [])
                  .cast<String>();
          final arguments = <String, dynamic>{};
          for (final name in required) {
            final property = properties[name] as Map<String, dynamic>;
            final enumValues = property['enum'] as List<dynamic>?;
            if (enumValues != null) {
              arguments[name] = enumValues.first;
            } else if (property['type'] == 'string') {
              arguments[name] = 'coke';
            } else {
              arguments[name] = 5;
            }
          }
          final result = check(function['name'] as String, arguments);
          expect(
            result.isValid,
            isTrue,
            reason: '${function['name']} rejected: ${result.rejection}',
          );
          expect(result.toolName, function['name']);
        }
      },
    );

    test('unknown tool is rejected', () {
      expectRejected(
        check('delete_everything', {}),
        ToolCallRejection.unknownTool,
      );
    });

    test('null tool is rejected', () {
      expectRejected(check(null, {}), ToolCallRejection.unknownTool);
    });

    test('null arguments are treated as empty', () {
      expect(check('get_store_info', null).isValid, isTrue);
    });
  });

  group('arguments', () {
    test('undeclared argument is rejected and named', () {
      expectRejected(
        check('get_store_info', {'secret': 1}),
        ToolCallRejection.unknownArgument,
        'secret',
      );
    });

    test('missing required argument is rejected', () {
      expectRejected(
        check('get_product_info', {}),
        ToolCallRejection.missingRequired,
        'product_name',
      );
    });

    test('defaults are not filled in', () {
      final result = check('get_low_stock', {});
      expect(result.isValid, isTrue);
      expect(result.arguments, isEmpty);
    });

    test('nested map is wrongType', () {
      expectRejected(
        check('get_low_stock', {
          'threshold': {'value': 5},
        }),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });

    test('nested list is wrongType', () {
      expectRejected(
        check('get_product_info', {
          'product_name': ['coke'],
        }),
        ToolCallRejection.wrongType,
        'product_name',
      );
    });

    test('null value is wrongType', () {
      expectRejected(
        check('get_low_stock', {'threshold': null}),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });
  });

  group('types', () {
    test('integer given as string is wrongType', () {
      expectRejected(
        check('get_low_stock', {'threshold': '5'}),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });

    test('integer given as whole double is converted to int', () {
      final result = check('get_low_stock', {'threshold': 5.0});
      expect(result.isValid, isTrue);
      expect(result.arguments['threshold'], isA<int>());
      expect(result.arguments['threshold'], 5);
    });

    test('integer given as fractional double is wrongType', () {
      expectRejected(
        check('get_low_stock', {'threshold': 5.5}),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });

    test('integer given as infinity is wrongType', () {
      expectRejected(
        check('get_low_stock', {'threshold': double.infinity}),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });

    test('number accepts int and double', () {
      expect(check('get_utang_list', {'min_balance': 500}).arguments, {
        'min_balance': 500,
      });
      expect(check('get_utang_list', {'min_balance': 500.5}).arguments, {
        'min_balance': 500.5,
      });
    });

    test('boolean is never a number', () {
      expectRejected(
        check('get_utang_list', {'min_balance': true}),
        ToolCallRejection.wrongType,
        'min_balance',
      );
      expectRejected(
        check('get_low_stock', {'threshold': true}),
        ToolCallRejection.wrongType,
        'threshold',
      );
    });

    test('number given as string is wrongType', () {
      expectRejected(
        check('get_utang_list', {'min_balance': '500'}),
        ToolCallRejection.wrongType,
        'min_balance',
      );
    });

    test('string given as number is wrongType', () {
      expectRejected(
        check('get_sales_summary', {'timeframe': 7}),
        ToolCallRejection.wrongType,
        'timeframe',
      );
    });
  });

  group('enums', () {
    test('valid value is accepted', () {
      expect(check('get_sales_summary', {'timeframe': 'week'}).isValid, isTrue);
    });

    test('value is trimmed and lowercased', () {
      final result = check('get_sales_summary', {'timeframe': '  WeeK '});
      expect(result.isValid, isTrue);
      expect(result.arguments['timeframe'], 'week');
    });

    test('invalid value is outOfRange', () {
      expectRejected(
        check('get_sales_summary', {'timeframe': 'year'}),
        ToolCallRejection.outOfRange,
        'timeframe',
      );
    });

    test('partial value is outOfRange', () {
      expectRejected(
        check('get_sales_summary', {'timeframe': 'wee'}),
        ToolCallRejection.outOfRange,
        'timeframe',
      );
    });
  });

  group('ranges', () {
    void expectBoundaries(
      String tool,
      String argument,
      num lowest,
      num highest,
    ) {
      expect(check(tool, {argument: lowest}).isValid, isTrue);
      expect(check(tool, {argument: highest}).isValid, isTrue);
      expectRejected(
        check(tool, {argument: lowest - 1}),
        ToolCallRejection.outOfRange,
        argument,
      );
      expectRejected(
        check(tool, {argument: highest + 1}),
        ToolCallRejection.outOfRange,
        argument,
      );
    }

    test('limit is 1 to 50', () {
      expectBoundaries('get_profit_margins', 'limit', 1, 50);
    });

    test('days is 1 to 365', () {
      expectBoundaries('get_slow_moving', 'days', 1, 365);
    });

    test('days_overdue is 1 to 365', () {
      expectBoundaries('get_utang_risk', 'days_overdue', 1, 365);
    });

    test('days_ahead is 1 to 365', () {
      expectBoundaries('get_expiry_alerts', 'days_ahead', 1, 365);
    });

    test('threshold is 0 to 100000', () {
      expectBoundaries('get_low_stock', 'threshold', 0, 100000);
    });

    test('min_balance is 0 to 10000000', () {
      expectBoundaries('get_utang_list', 'min_balance', 0, 10000000);
    });

    test('budget is 0 to 10000000', () {
      expectBoundaries('get_restock_suggestions', 'budget', 0, 10000000);
    });

    test('fractional number just above maximum is outOfRange', () {
      expectRejected(
        check('get_utang_list', {'min_balance': 10000000.5}),
        ToolCallRejection.outOfRange,
        'min_balance',
      );
    });

    test('negative number is outOfRange', () {
      expectRejected(
        check('get_utang_list', {'min_balance': -0.5}),
        ToolCallRejection.outOfRange,
        'min_balance',
      );
    });
  });

  group('entity text', () {
    test('name present in question is accepted as written there', () {
      final result = check('get_product_info', {'product_name': 'coke'});
      expect(result.isValid, isTrue);
      expect(result.arguments['product_name'], 'Coke');
    });

    test('case and punctuation are folded', () {
      final result = check('get_product_info', {'product_name': 'COKE!!'});
      expect(result.isValid, isTrue);
      expect(result.arguments['product_name'], 'Coke');
    });

    test('accents and enye are folded', () {
      final result = check('get_product_info', {'product_name': 'senor pedro'});
      expect(result.isValid, isTrue);
      expect(result.arguments['product_name'], 'Señor Pedro');
    });

    test('accented value matches plain question', () {
      final result = check(
        'get_product_info',
        {'product_name': 'Café'},
        text: 'magkano cafe',
      );
      expect(result.isValid, isTrue);
      expect(result.arguments['product_name'], 'cafe');
    });

    test('multi word name must be consecutive in question', () {
      expect(
        check('get_product_info', {'product_name': 'coke pedro'}).rejection,
        ToolCallRejection.notInQuestion,
      );
      expect(
        check(
          'get_product_info',
          {'product_name': 'ice   cream'},
          text: 'may ice-cream ba?',
        ).isValid,
        isTrue,
      );
    });

    test('invented name is notInQuestion', () {
      expectRejected(
        check('get_product_info', {
          'product_name': 'shampoo',
        }, text: 'magkano ang coke'),
        ToolCallRejection.notInQuestion,
        'product_name',
      );
    });

    test('substring of a longer word is notInQuestion', () {
      expectRejected(
        check('get_product_info', {
          'product_name': 'ice',
        }, text: 'magkano ang price'),
        ToolCallRejection.notInQuestion,
        'product_name',
      );
    });

    test('empty and blank name is notInQuestion', () {
      expectRejected(
        check('get_product_info', {'product_name': ''}),
        ToolCallRejection.notInQuestion,
        'product_name',
      );
      expectRejected(
        check('get_product_info', {'product_name': '  !! '}),
        ToolCallRejection.notInQuestion,
        'product_name',
      );
    });

    test('stock forecast also checks product name', () {
      expectRejected(
        check('get_stock_forecast', {'product_name': 'shampoo'}),
        ToolCallRejection.notInQuestion,
        'product_name',
      );
    });
  });

  group('malformed tools json', () {
    test('bad entries are skipped without throwing', () {
      final tolerant = ToolCallValidator.fromToolsJson(
        jsonEncode([
          42,
          'text',
          {'type': 'function'},
          {
            'function': {'name': 7},
          },
          {
            'function': {
              'name': 'bad_property',
              'parameters': {
                'properties': {'x': 'not a map'},
              },
            },
          },
          {
            'function': {
              'name': 'bad_type',
              'parameters': {
                'properties': {
                  'x': {'type': 'boolean'},
                },
              },
            },
          },
          {
            'function': {
              'name': 'good_tool',
              'parameters': {
                'properties': {
                  'limit': {'type': 'integer'},
                },
                'required': ['limit', 3],
              },
            },
          },
        ]),
      );
      expect(
        tolerant.validate('good_tool', {'limit': 3}, question: 'q').isValid,
        isTrue,
      );
      for (final skipped in ['bad_property', 'bad_type']) {
        expect(
          tolerant.validate(skipped, {}, question: 'q').rejection,
          ToolCallRejection.unknownTool,
        );
      }
    });

    test('invalid json and non list json yield a validator rejecting all', () {
      for (final raw in ['not json', '{"a": 1}', '']) {
        final empty = ToolCallValidator.fromToolsJson(raw);
        expect(
          empty.validate('get_overview', {}, question: 'q').rejection,
          ToolCallRejection.unknownTool,
        );
      }
    });
  });
}
