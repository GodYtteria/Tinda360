import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/shared/widgets/scan_debouncer.dart';

void main() {
  late DateTime currentTime;
  late ScanDebouncer debouncer;

  setUp(() {
    currentTime = DateTime(2026, 1, 1);
    debouncer = ScanDebouncer(now: () => currentTime);
  });

  test('first scan accepted, repeat inside window rejected', () {
    expect(debouncer.accept('4800'), isTrue);
    currentTime = currentTime.add(const Duration(milliseconds: 1499));
    expect(debouncer.accept('4800'), isFalse);
  });

  test('same code accepted again at window boundary', () {
    expect(debouncer.accept('4800'), isTrue);
    currentTime = currentTime.add(const Duration(milliseconds: 1500));
    expect(debouncer.accept('4800'), isTrue);
  });

  test('different code accepted immediately', () {
    expect(debouncer.accept('4800'), isTrue);
    expect(debouncer.accept('4801'), isTrue);
  });

  test('rejected scan does not extend the window', () {
    expect(debouncer.accept('4800'), isTrue);
    currentTime = currentTime.add(const Duration(milliseconds: 1000));
    expect(debouncer.accept('4800'), isFalse);
    currentTime = currentTime.add(const Duration(milliseconds: 600));
    expect(debouncer.accept('4800'), isTrue);
  });

  test('unicode codes are tracked independently', () {
    expect(debouncer.accept('ñ-1'), isTrue);
    expect(debouncer.accept('ñ-1'), isFalse);
    expect(debouncer.accept('n-1'), isTrue);
  });
}
