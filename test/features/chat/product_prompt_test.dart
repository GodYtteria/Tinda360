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

  test('forecast question words do not count as a product name', () {
    expect(namesUnknownProduct('kailan mauubos'), isFalse);
    expect(namesUnknownProduct('how long will it last'), isFalse);
    expect(namesUnknownProduct('kailan mauubos ang itlog'), isTrue);
    expect(namesUnknownProduct('ilang araw bago maubos ang bigas'), isTrue);
  });
}
