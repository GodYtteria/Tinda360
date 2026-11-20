import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/features/chat/data/query_language.dart';

void main() {
  const language = QueryLanguage();

  test('a Tagalog question gets a Filipino reply in an English app', () {
    expect(
      language.isFilipino(
        'magkano ang pamasahe papuntang maynila',
        appIsFilipino: false,
      ),
      isTrue,
    );
    expect(
      language.isFilipino('ilan pa ang Kopiko Brown', appIsFilipino: false),
      isTrue,
    );
  });

  test('an English question gets an English reply in a Filipino app', () {
    expect(
      language.isFilipino('who are my regulars', appIsFilipino: true),
      isFalse,
    );
    expect(
      language.isFilipino(
        'how much is the Lucky Me Pancit Canton',
        appIsFilipino: true,
      ),
      isFalse,
    );
  });

  test('the English word pay does not count as Filipino', () {
    expect(
      language.isFilipino('did Ana pay', appIsFilipino: true),
      isFalse,
    );
  });

  test('Bisaya and Ilokano questions get a Filipino reply', () {
    expect(
      language.isFilipino('pila ang presyo sa bugas', appIsFilipino: false),
      isTrue,
    );
    expect(
      language.isFilipino('mano ti nailako ko ita', appIsFilipino: false),
      isTrue,
    );
  });

  test('a question with no language clue follows the app language', () {
    for (final appIsFilipino in [true, false]) {
      expect(
        language.isFilipino('Coke Mismo', appIsFilipino: appIsFilipino),
        appIsFilipino,
      );
      expect(
        language.isFilipino('', appIsFilipino: appIsFilipino),
        appIsFilipino,
      );
      expect(
        language.isFilipino('🙂 ₱20', appIsFilipino: appIsFilipino),
        appIsFilipino,
      );
    }
  });

  test('Taglish leans to whichever language has more words', () {
    expect(
      language.isFilipino(
        'magkano ang sales natin today',
        appIsFilipino: false,
      ),
      isTrue,
    );
    expect(
      language.isFilipino(
        'how many items are left sa stock',
        appIsFilipino: true,
      ),
      isFalse,
    );
  });

  test('capitalized brand words do not count as English', () {
    expect(
      language.isFilipino('magkano Lucky Me', appIsFilipino: false),
      isTrue,
    );
    expect(
      language.isFilipino('may Best Choice pa ba', appIsFilipino: false),
      isTrue,
    );
    expect(
      language.isFilipino('How much is the coke', appIsFilipino: true),
      isFalse,
    );
  });

  test('accented Filipino words still count as Filipino', () {
    expect(
      language.isFilipino('Magkanó ang bigás', appIsFilipino: false),
      isTrue,
    );
    expect(language.isFilipino('Ilán pa', appIsFilipino: false), isTrue);
  });

  test('decomposed accents still count as Filipino', () {
    expect(
      language.isFilipino(
        'ila\u0301n pa ang biga\u0301s',
        appIsFilipino: false,
      ),
      isTrue,
    );
    expect(
      language.isFilipino(
        'magka\u0301no\u0301 kahapo\u0301n',
        appIsFilipino: false,
      ),
      isTrue,
    );
  });

  test('loanwords alone still mark an English question', () {
    for (final query in [
      'sales today',
      'best sellers today',
      'low stock items',
      'top customers',
    ]) {
      expect(language.isFilipino(query, appIsFilipino: true), isFalse);
    }
  });

  test('Taglish loanwords do not outvote Tagalog words', () {
    expect(
      language.isFilipino(
        'ilan items left sa store today',
        appIsFilipino: false,
      ),
      isTrue,
    );
    expect(
      language.isFilipino('magkano sales ko today', appIsFilipino: false),
      isTrue,
    );
    expect(
      language.isFilipino('what are my sales today', appIsFilipino: true),
      isFalse,
    );
  });
}
