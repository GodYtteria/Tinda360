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

  test(
    'resetWithRecoveryCode returns false for wrong code or no PIN',
    () async {
      expect(await pinService.resetWithRecoveryCode('T360-AAAA'), isFalse);

      await pinService.setPin('5678');

      expect(await pinService.resetWithRecoveryCode(''), isFalse);
      expect(await pinService.resetWithRecoveryCode('WRONG-CODE'), isFalse);
      expect(await pinService.hasPin(), isTrue);
      expect(await pinService.verifyPin('5678'), isTrue);
    },
  );

  test(
    'resetWithRecoveryCode clears PIN with exact or normalized code',
    () async {
      final firstRecoveryCode = await pinService.setPin('2468');
      expect(await pinService.resetWithRecoveryCode(firstRecoveryCode), isTrue);
      expect(await pinService.hasPin(), isFalse);
      expect(await pinService.verifyPin('2468'), isFalse);
      expect(
        await pinService.resetWithRecoveryCode(firstRecoveryCode),
        isFalse,
      );

      final secondRecoveryCode = await pinService.setPin('1357');
      final normalizedInput =
          ' ${secondRecoveryCode.toLowerCase().replaceAll('-', ' ')} ';
      expect(await pinService.resetWithRecoveryCode(normalizedInput), isTrue);
      expect(await pinService.hasPin(), isFalse);
      expect(await pinService.verifyPin('1357'), isFalse);
    },
  );

  test(
    'a damaged PIN file still counts as a PIN so actions stay locked',
    () async {
      await pinService.setPin('4829');
      File('${tempDirectory.path}/tinda360_pin.json').writeAsStringSync('{bro');

      expect(await pinService.hasPin(), isTrue);
      expect(await pinService.verifyPin('4829'), isFalse);
    },
  );

  test('isPinDamaged is true only for an unreadable PIN file', () async {
    expect(await pinService.isPinDamaged(), isFalse);
    await pinService.setPin('4829');
    expect(await pinService.isPinDamaged(), isFalse);
    File('${tempDirectory.path}/tinda360_pin.json').writeAsStringSync('{bro');
    expect(await pinService.isPinDamaged(), isTrue);
    await pinService.clearPin();
    expect(await pinService.isPinDamaged(), isFalse);
    expect(await pinService.hasPin(), isFalse);
  });

  test(
    'a corrupt attempts file that vanishes mid-check never throws',
    () async {
      await pinService.setPin('4829');
      final attemptsFile = File(
        '${tempDirectory.path}/tinda360_pin_attempts.json',
      )..writeAsStringSync('{bro');
      expect(await pinService.lockoutRemaining(), isNotNull);
      attemptsFile.deleteSync();
      expect(await pinService.verifyPin('1111'), isFalse);
    },
  );

  test('an unreadable attempts file never makes PIN checks throw', () async {
    await pinService.setPin('4829');
    Directory('${tempDirectory.path}/tinda360_pin_attempts.json').createSync();

    expect(await pinService.verifyPin('1111'), isFalse);
    expect(await pinService.lockoutRemaining(), isNotNull);
  });

  test('locks out after five wrong guesses, even for the right PIN', () async {
    var clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');

    for (var attempt = 0; attempt < 4; attempt++) {
      expect(await lockingService.verifyPin('0000'), isFalse);
      expect(await lockingService.lockoutRemaining(), isNull);
    }
    expect(await lockingService.verifyPin('0000'), isFalse);
    expect(
      await lockingService.lockoutRemaining(),
      const Duration(seconds: 30),
    );
    expect(await lockingService.verifyPin('4829'), isFalse);

    clock = clock.add(const Duration(seconds: 31));
    expect(await lockingService.lockoutRemaining(), isNull);
    expect(await lockingService.verifyPin('4829'), isTrue);
    expect(await lockingService.verifyPin('0000'), isFalse);
    expect(await lockingService.lockoutRemaining(), isNull);
  });

  test('lockout doubles after each further wrong guess', () async {
    var clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');
    for (var attempt = 0; attempt < 5; attempt++) {
      await lockingService.verifyPin('0000');
    }
    clock = clock.add(const Duration(seconds: 31));
    expect(await lockingService.verifyPin('1111'), isFalse);
    expect(
      await lockingService.lockoutRemaining(),
      const Duration(seconds: 60),
    );
  });

  test('setting a new PIN clears an earlier lockout', () async {
    final clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');
    for (var attempt = 0; attempt < 5; attempt++) {
      await lockingService.verifyPin('0000');
    }
    expect(await lockingService.lockoutRemaining(), isNotNull);

    await lockingService.clearPin();
    await lockingService.setPin('7315');

    expect(await lockingService.lockoutRemaining(), isNull);
    expect(await lockingService.verifyPin('7315'), isTrue);
  });

  test('wrong recovery codes count toward the same lockout', () async {
    final clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    final recoveryCode = await lockingService.setPin('4829');
    for (var attempt = 0; attempt < 5; attempt++) {
      expect(await lockingService.resetWithRecoveryCode('T360-0000'), isFalse);
    }
    expect(await lockingService.resetWithRecoveryCode(recoveryCode), isFalse);
    expect(await lockingService.hasPin(), isTrue);
  });

  test('a corrupt attempts file locks only briefly, never forever', () async {
    var clock = DateTime.now();
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');
    File(path.join(tempDirectory.path, 'tinda360_pin_attempts.json'))
        .writeAsStringSync('{not json');

    expect(await lockingService.verifyPin('4829'), isFalse);
    clock = clock.add(const Duration(minutes: 1));
    expect(await lockingService.lockoutRemaining(), isNull);
    expect(await lockingService.verifyPin('4829'), isTrue);
  });

  test('a lockout far in the future is capped at one hour', () async {
    final clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');
    File(path.join(tempDirectory.path, 'tinda360_pin_attempts.json'))
        .writeAsStringSync(
          jsonEncode(<String, int>{
            'failures': 6,
            'lockedUntilMs': clock
                .add(const Duration(days: 3))
                .millisecondsSinceEpoch,
          }),
        );

    final remaining = await lockingService.lockoutRemaining();
    expect(remaining, isNotNull);
    expect(remaining! <= const Duration(hours: 1), isTrue);
  });

  test('a lockout far in the future ends one hour after it is seen', () async {
    var clock = DateTime(2026, 11, 18, 9);
    final lockingService = StorePinService(
      directoryProvider: () async => tempDirectory,
      now: () => clock,
    );
    await lockingService.setPin('4829');
    File(path.join(tempDirectory.path, 'tinda360_pin_attempts.json'))
        .writeAsStringSync(
          jsonEncode(<String, int>{
            'failures': 6,
            'lockedUntilMs': clock
                .add(const Duration(days: 3))
                .millisecondsSinceEpoch,
          }),
        );

    expect(await lockingService.lockoutRemaining(), const Duration(hours: 1));
    clock = clock.add(const Duration(hours: 1, seconds: 1));
    expect(await lockingService.lockoutRemaining(), isNull);
    expect(await lockingService.verifyPin('4829'), isTrue);
  });
}
