import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/yumi_engine.dart';

void main() {
  final definitions = YumiEngine.formatToolDefinitions(
    File('assets/ai/tools.json').readAsStringSync(),
  ).split('\n');

  test('product tools are shown to the model without a product name', () {
    expect(definitions, contains('get_product_info()'));
    expect(definitions, contains('get_stock_forecast()'));
    expect(definitions.join('\n'), isNot(contains('product_name')));
    expect(definitions.join('\n'), isNot(contains('customer_name')));
  });

  test('numeric arguments are still shown to the model', () {
    expect(definitions, contains('get_sales_summary(timeframe: string)'));
    expect(definitions, contains('get_low_stock(threshold: integer)'));
  });

  test('the model sees every tool from the definitions file', () {
    expect(definitions, hasLength(20));
  });
}
