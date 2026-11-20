import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/feedback_redactor.dart';

void main() {
  const redactor = FeedbackRedactor();

  String redact(
    String text, {
    List<String> customers = const <String>[],
    List<String> products = const <String>[],
  }) {
    return redactor.redact(
      text,
      customerNames: customers,
      productNames: products,
    );
  }

  group('customer names', () {
    test('full customer name becomes the customer placeholder', () {
      expect(
        redact('magkano utang ni Maria Santos', customers: ['Maria Santos']),
        'magkano utang ni <CUSTOMER>',
      );
    });

    test('matching ignores case', () {
      expect(
        redact('utang ni MARIA SANTOS', customers: ['maria santos']),
        'utang ni <CUSTOMER>',
      );
    });

    test('single word of a full name is redacted alone', () {
      expect(
        redact('utang ni Maria', customers: ['Maria Santos']),
        'utang ni <CUSTOMER>',
      );
      expect(
        redact('utang ni santos', customers: ['Maria Santos']),
        'utang ni <CUSTOMER>',
      );
    });

    test('words shorter than three letters are not redacted alone', () {
      expect(
        redact('Jo ay nagbayad', customers: ['Jo Cruz']),
        'Jo ay nagbayad',
      );
    });

    test('honorific alone is never treated as a name', () {
      expect(
        redact('utang ni Aling Nena', customers: ['Nena Santos']),
        'utang ni Aling <CUSTOMER>',
      );
      expect(
        redact('tawag kay Aling', customers: ['Aling Nena']),
        'tawag kay Aling',
      );
      expect(
        redact('tawag kay Kuya at Mang', customers: ['Kuya Boss Pedro']),
        'tawag kay Kuya at Mang',
      );
    });

    test('every listed honorific stays when it is not the full name', () {
      const honorifics = [
        'aling',
        'mang',
        'ate',
        'kuya',
        'nanay',
        'tatay',
        'lola',
        'lolo',
        'tita',
        'tito',
        'sir',
        'maam',
        'mam',
        'mrs',
        'mr',
        'ms',
        'boss',
        'kap',
        'kapitan',
        'mare',
        'pare',
      ];
      for (final honorific in honorifics) {
        expect(
          redact('hi $honorific po', customers: ['$honorific Zandro']),
          'hi $honorific po',
          reason: honorific,
        );
      }
    });

    test('adjacent placeholders from one name collapse to one', () {
      expect(
        redact('utang ni Aling Nena Cruz', customers: ['Nena Cruz']),
        'utang ni Aling <CUSTOMER>',
      );
      expect(
        redact('Nena Cruz', customers: ['Nena', 'Cruz']),
        '<CUSTOMER>',
      );
    });

    test('name with accented letter matches exactly modulo case', () {
      expect(
        redact('utang ni Nuñez', customers: ['Nuñez']),
        'utang ni <CUSTOMER>',
      );
      expect(
        redact('utang ni NUÑEZ', customers: ['nuñez']),
        'utang ni <CUSTOMER>',
      );
    });

    test('name followed by an accented letter does not match', () {
      expect(
        redact('bayad na Bené', customers: ['Ben']),
        'bayad na Bené',
      );
    });
  });

  group('product names', () {
    test('full product name becomes the product placeholder', () {
      expect(
        redact('magkano Lucky Me Pancit Canton', products: ['Lucky Me']),
        'magkano <PRODUCT> Pancit Canton',
      );
    });

    test('punctuation differences are tolerated', () {
      const stored = ['Coca-Cola 1.5L'];
      expect(
        redact('presyo ng coca cola 1.5l', products: stored),
        'presyo ng <PRODUCT>',
      );
      expect(
        redact('presyo ng Coca-Cola 1.5L', products: stored),
        'presyo ng <PRODUCT>',
      );
      expect(
        redact('presyo ng coca---cola, 1 5l', products: stored),
        'presyo ng <PRODUCT>',
      );
    });

    test('words of a product name are not redacted alone', () {
      expect(
        redact('Lucky na ako', products: ['Lucky Me']),
        'Lucky na ako',
      );
    });

    test('piña keeps its exact letters', () {
      expect(
        redact('stock ng piña colada', products: ['Piña Colada']),
        'stock ng <PRODUCT>',
      );
    });
  });

  group('whole word matching', () {
    test('Ben does not match inside benta', () {
      expect(
        redact('benta ngayon at Bentahe', customers: ['Ben']),
        'benta ngayon at Bentahe',
      );
      expect(
        redact('utang ni Ben', customers: ['Ben']),
        'utang ni <CUSTOMER>',
      );
    });

    test('Ice does not match inside price', () {
      expect(
        redact('price ng ice', products: ['Ice']),
        'price ng <PRODUCT>',
      );
    });

    test('name is not matched when glued to digits', () {
      expect(
        redact('ben2 at 2ben', customers: ['Ben']),
        'ben2 at 2ben',
      );
    });
  });

  group('ordering', () {
    test('longest product name wins over shorter one', () {
      expect(
        redact('isang Coke Zero', products: ['Coke', 'Coke Zero']),
        'isang <PRODUCT>',
      );
      expect(
        redact('isang Coke Zero', products: ['Coke Zero', 'Coke']),
        'isang <PRODUCT>',
      );
    });

    test('longest customer name wins over a shorter one', () {
      expect(
        redact('ni Ana Reyes', customers: ['Ana', 'Ana Reyes']),
        'ni <CUSTOMER>',
      );
    });

    test('customer is processed before product', () {
      expect(
        redact('utang ni Mango', customers: ['Mango'], products: ['Mango']),
        'utang ni <CUSTOMER>',
      );
    });

    test('product still redacted when customer list lacks it', () {
      expect(
        redact('Mango at Pedro', customers: ['Pedro Lim'], products: ['Mango']),
        '<PRODUCT> at <CUSTOMER>',
      );
    });
  });

  group('numbers', () {
    test('six digits are kept', () {
      expect(redact('code 123456'), 'code 123456');
    });

    test('seven digits are redacted', () {
      expect(redact('code 1234567'), 'code <NUMBER>');
    });

    test('phone number with spaces becomes one placeholder', () {
      expect(redact('tawag 0917 123 4567 na'), 'tawag <NUMBER> na');
    });

    test('phone number with dashes becomes one placeholder', () {
      expect(redact('tawag 0917-123-4567 na'), 'tawag <NUMBER> na');
    });

    test('amounts are left alone', () {
      expect(
        redact('utang 500 at 2000 at 1,500'),
        'utang 500 at 2000 at 1,500',
      );
    });
  });

  group('input handling', () {
    test('empty text returns empty text', () {
      expect(redact('', customers: ['Ben'], products: ['Ice']), '');
    });

    test('empty and whitespace names are ignored', () {
      expect(
        redact('hello  world', customers: ['', '   '], products: ['', ' \t']),
        'hello  world',
      );
    });

    test('single character names are ignored', () {
      expect(
        redact('a b c', customers: ['a'], products: ['b', '+']),
        'a b c',
      );
    });

    test('duplicate names are fine', () {
      expect(
        redact('ni Pedro', customers: ['Pedro', 'pedro', 'Pedro']),
        'ni <CUSTOMER>',
      );
    });

    test('text with nothing to redact is unchanged', () {
      const text = '  magkano   ang bigas?\n\tsalamat  ';
      expect(
        redact(text, customers: ['Maria'], products: ['Ice']),
        text,
      );
    });

    test('regex metacharacters never throw', () {
      expect(
        redact('may C++ (Large) po', products: ['C++ (Large)']),
        'may <PRODUCT>) po',
      );
      expect(
        redact('A.B* ay utang', customers: ['A.B*']),
        '<CUSTOMER>* ay utang',
      );
      expect(
        redact(
          'x',
          customers: ['(', '[a-', r'\', '*+?'],
          products: ['|', r'$^'],
        ),
        'x',
      );
    });

    test('redacting already redacted text changes nothing', () {
      final once = redact(
        'utang ni Aling Nena Cruz sa Coke Zero 0917 123 4567',
        customers: ['Nena Cruz'],
        products: ['Coke Zero'],
      );
      final twice = redact(
        once,
        customers: ['Nena Cruz'],
        products: ['Coke Zero'],
      );
      expect(twice, once);
    });

    test('names equal to placeholder words do not corrupt placeholders', () {
      final once = redact(
        'ni Ben bili Coke',
        customers: ['Ben'],
        products: ['Coke', 'customer', 'product', 'number'],
      );
      expect(once, 'ni <CUSTOMER> bili <PRODUCT>');
      expect(
        redact(
          once,
          customers: ['Ben'],
          products: ['Coke', 'customer', 'product', 'number'],
        ),
        once,
      );
    });
  });

  group('people who are not in the customer list', () {
    test('a word after si, ni or kay is redacted', () {
      expect(
        redact('magkano utang ni Berto', customers: [], products: []),
        'magkano utang ni <CUSTOMER>',
      );
      expect(
        redact('pautangin ba si Lorna', customers: [], products: []),
        'pautangin ba si <CUSTOMER>',
      );
      expect(
        redact('singilin kay JUNJUN bukas', customers: [], products: []),
        'singilin kay <CUSTOMER> bukas',
      );
    });

    test('a word after a title is redacted, with or without a particle', () {
      expect(
        redact('utang ni aling nena', customers: [], products: []),
        'utang ni aling <CUSTOMER>',
      );
      expect(
        redact('may utang ba mang Kanor', customers: [], products: []),
        'may utang ba mang <CUSTOMER>',
      );
    });

    test('pronouns and question words after a particle are kept', () {
      for (final text in [
        'sino si yumi',
        'utang ni siya',
        'ate magkano benta',
        'kuya ano ang paubos',
        'kay lahat',
        'ni aling',
      ]) {
        expect(
          redact(text, customers: [], products: []),
          text,
          reason: text,
        );
      }
    });

    test('particles inside longer words do not trigger', () {
      for (final text in ['benta ngayon', 'mani presyo', 'kasi mahal']) {
        expect(
          redact(text, customers: [], products: []),
          text,
          reason: text,
        );
      }
    });

    test('an already redacted name is left alone', () {
      const text = 'utang ni <CUSTOMER> at kay aling <CUSTOMER>';
      expect(redact(text, customers: [], products: []), text);
    });
  });

  test('realistic sentence mixes customer, product and amount', () {
    expect(
      redact(
        'Pwede ba umutang si Aling Nena ng 2 Coca-Cola 1.5L, 500 pesos, '
        'tawagan 09171234567',
        customers: ['Nena Cruz'],
        products: ['Coca-Cola 1.5L'],
      ),
      'Pwede ba umutang si Aling <CUSTOMER> ng 2 <PRODUCT>, 500 pesos, '
      'tawagan <NUMBER>',
    );
  });
}
