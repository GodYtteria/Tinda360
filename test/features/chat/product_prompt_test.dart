import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/presentation/chat_reply_builders.dart';

void main() {
  test('bare price questions name no product', () {
    expect(namesUnknownProduct('magkano'), isFalse);
    expect(namesUnknownProduct('magkano ang presyo'), isFalse);
    expect(namesUnknownProduct('how much is the price'), isFalse);
    expect(namesUnknownProduct(''), isFalse);
  });

  test('a leftover word is treated as a product name', () {
    expect(namesUnknownProduct('magkano bigas'), isTrue);
    expect(namesUnknownProduct('presyo ng pancit canton'), isTrue);
    expect(namesUnknownProduct('magkano ₱ gatas'), isTrue);
  });
}
