import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:tinda360/services/store_pin_service.dart';

void main() {
  late Directory tempDirectory;
  late StorePinService pinService;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('tinda360_pin_test_');
    pinService = StorePinService(
      directoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() {
    if (tempDirectory.existsSync()) {
      tempDirectory.deleteSync(recursive: true);
    }
  });

  test('hasPin and verifyPin return false when no PIN is configured', () async {
    expect(await pinService.hasPin(), isFalse);
    expect(await pinService.verifyPin('1234'), isFalse);
  });

  test('setPin validates 4-digit format and throws FormatException', () async {
    const invalidPins = <String>['', '123', '12345', '12a4', 'abcd', ' 123'];
    for (final invalidPin in invalidPins) {
      await expectLater(
        pinService.setPin(invalidPin),
        throwsA(isA<FormatException>()),
      );
    }
    expect(await pinService.hasPin(), isFalse);
  });

  test('setPin stores salted hashes and verifyPin checks correctly', () async {
    final recoveryCode = await pinService.setPin('4829');

    expect(
      recoveryCode,
      matches(RegExp(r'^T360-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$')),
    );
    expect(await pinService.hasPin(), isTrue);
    expect(await pinService.verifyPin('4829'), isTrue);
    expect(await pinService.verifyPin('0000'), isFalse);
    expect(await pinService.verifyPin('482'), isFalse);

    final pinFile = File(path.join(tempDirectory.path, 'tinda360_pin.json'));
    expect(pinFile.existsSync(), isTrue);
    final rawContents = pinFile.readAsStringSync();
    expect(rawContents.contains('4829'), isFalse);
    expect(rawContents.contains(recoveryCode), isFalse);
    expect(rawContents.contains(recoveryCode.replaceAll('-', '')), isFalse);

    final decoded = jsonDecode(rawContents) as Map<String, dynamic>;
    expect(decoded['salt'], isA<String>());
    expect(decoded['hash'], isA<String>());
    expect(decoded['recoverySalt'], isA<String>());
    expect(decoded['recoveryHash'], isA<String>());
    expect((decoded['salt'] as String).isNotEmpty, isTrue);
    expect((decoded['hash'] as String).length, 64);
    expect((decoded['recoverySalt'] as String).isNotEmpty, isTrue);
    expect((decoded['recoveryHash'] as String).length, 64);
  });

  test('setPin generates a fresh salt on each call', () async {
    final pinFile = File(path.join(tempDirectory.path, 'tinda360_pin.json'));

    await pinService.setPin('1234');
    final firstRecord =
        jsonDecode(pinFile.readAsStringSync()) as Map<String, dynamic>;

    await pinService.setPin('1234');
    final secondRecord =
        jsonDecode(pinFile.readAsStringSync()) as Map<String, dynamic>;

    expect(firstRecord['salt'], isNot(equals(secondRecord['salt'])));
    expect(firstRecord['hash'], isNot(equals(secondRecord['hash'])));
    expect(await pinService.verifyPin('1234'), isTrue);
  });

  test('clearPin removes stored PIN and resets hasPin', () async {
    await pinService.setPin('9012');
    expect(await pinService.hasPin(), isTrue);

    await pinService.clearPin();

    expect(await pinService.hasPin(), isFalse);
    expect(await pinService.verifyPin('9012'), isFalse);
  });

  test('resetWithRecoveryCode returns false for wrong code or no PIN', () async {
    expect(await pinService.resetWithRecoveryCode('T360-AAAA'), isFalse);

    await pinService.setPin('5678');

    expect(await pinService.resetWithRecoveryCode(''), isFalse);
    expect(await pinService.resetWithRecoveryCode('WRONG-CODE'), isFalse);
    expect(await pinService.hasPin(), isTrue);
    expect(await pinService.verifyPin('5678'), isTrue);
  });

  test('resetWithRecoveryCode clears PIN with exact or normalized code', () async {
    final firstRecoveryCode = await pinService.setPin('2468');
    expect(await pinService.resetWithRecoveryCode(firstRecoveryCode), isTrue);
    expect(await pinService.hasPin(), isFalse);
    expect(await pinService.verifyPin('2468'), isFalse);
    expect(await pinService.resetWithRecoveryCode(firstRecoveryCode), isFalse);

    final secondRecoveryCode = await pinService.setPin('1357');
    final normalizedInput =
        ' ${secondRecoveryCode.toLowerCase().replaceAll('-', ' ')} ';
    expect(await pinService.resetWithRecoveryCode(normalizedInput), isTrue);
    expect(await pinService.hasPin(), isFalse);
    expect(await pinService.verifyPin('1357'), isFalse);
  });
}
