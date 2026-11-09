import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final class StorePinService {
  new({
    Future<Directory> Function()? directoryProvider,
    DateTime Function()? now,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  static const String _fileName = 'tinda360_pin.json';
  static const String _attemptsFileName = 'tinda360_pin_attempts.json';
  static const int _freeAttempts = 5;
  static const Duration _firstLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(hours: 1);
  static const int _saltByteLength = 16;
  static const int _hashRounds = 1000;
  static const String _recoveryAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const int _recoverySuffixLength = 4;
  static const String _recoveryPrefix = 'T360';
  static final RegExp _fourDigitPattern = RegExp(r'^\d{4}$');

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _now;
  DateTime? _unsavedLockoutUntil;

  Future<Duration?> lockoutRemaining() async {
    final now = _now();
    final unsavedRemaining = _unsavedLockoutUntil?.difference(now);
    if (unsavedRemaining != null && unsavedRemaining > Duration.zero) {
      return unsavedRemaining;
    }
    final attempts = await _readAttempts();
    final remaining = attempts.lockedUntil?.difference(now);
    if (remaining == null || remaining <= Duration.zero) return null;
    if (remaining <= _maxLockout) return remaining;
    await _saveAttemptsOrLockBriefly(
      failures: attempts.failures,
      lockedUntil: now.add(_maxLockout),
    );
    return _maxLockout;
  }

  Future<bool> isPinDamaged() async {
    final pinFile = await _resolveFile();
    if (!pinFile.existsSync()) return false;
    return await _readRecord() == null;
  }

  Future<bool> hasPin() async {
    final pinFile = await _resolveFile();
    return pinFile.existsSync();
  }

  Future<String> setPin(String pin) async {
    if (!_fourDigitPattern.hasMatch(pin)) {
      throw const FormatException('Store PIN must be exactly 4 digits.');
    }

    final saltHex = _generateSaltHex();
    final pinHashHex = _hashSecret(saltHex: saltHex, secret: pin);
    final formattedRecoveryCode = _generateRecoveryCode();
    final normalizedRecoveryCode = _normalizeRecoveryCode(
      formattedRecoveryCode,
    );
    final recoverySaltHex = _generateSaltHex();
    final recoveryHashHex = _hashSecret(
      saltHex: recoverySaltHex,
      secret: normalizedRecoveryCode,
    );

    final pinFile = await _resolveFile();
    await pinFile.parent.create(recursive: true);
    final payload = jsonEncode(<String, String>{
      'salt': saltHex,
      'hash': pinHashHex,
      'recoverySalt': recoverySaltHex,
      'recoveryHash': recoveryHashHex,
    });
    final stagedFile = File('${pinFile.path}.tmp');
    await stagedFile.writeAsString(payload, flush: true);
    await stagedFile.rename(pinFile.path);
    await _recordGuess(succeeded: true);
    return formattedRecoveryCode;
  }

  Future<bool> verifyPin(String pin) async {
    if (!_fourDigitPattern.hasMatch(pin)) {
      return false;
    }

    if (await lockoutRemaining() != null) return false;

    final storedRecord = await _readRecord();
    if (storedRecord == null) {
      return false;
    }

    final candidateHash = _hashSecret(
      saltHex: storedRecord.saltHex,
      secret: pin,
    );
    final matches = _constantTimeEquals(candidateHash, storedRecord.hashHex);
    await _recordGuess(succeeded: matches);
    return matches;
  }

  Future<bool> resetWithRecoveryCode(String code) async {
    final normalizedCode = _normalizeRecoveryCode(code);
    if (normalizedCode.isEmpty) {
      return false;
    }
    if (await lockoutRemaining() != null) return false;

    final storedRecord = await _readRecord();
    final recoverySaltHex = storedRecord?.recoverySaltHex;
    final recoveryHashHex = storedRecord?.recoveryHashHex;
    if (recoverySaltHex == null || recoveryHashHex == null) {
      return false;
    }

    final candidateHash = _hashSecret(
      saltHex: recoverySaltHex,
      secret: normalizedCode,
    );
    if (!_constantTimeEquals(candidateHash, recoveryHashHex)) {
      await _recordGuess(succeeded: false);
      return false;
    }

    await _recordGuess(succeeded: true);
    await clearPin();
    return true;
  }

  Future<void> clearPin() async {
    final pinFile = await _resolveFile();
    if (pinFile.existsSync()) {
      await pinFile.delete();
    }
  }

  Future<void> _recordGuess({required bool succeeded}) async {
    final attemptsFile = await _resolveAttemptsFile();
    if (succeeded) {
      _unsavedLockoutUntil = null;
      try {
        if (attemptsFile.existsSync()) await attemptsFile.delete();
      } on FileSystemException catch (error, stack) {
        developer.log(
          'pin attempts reset failed',
          error: error,
          stackTrace: stack,
        );
      }
      return;
    }
    final failures = (await _readAttempts()).failures + 1;
    DateTime? lockedUntil;
    if (failures >= _freeAttempts) {
      final doublings = failures - _freeAttempts;
      final lockout = doublings >= 7
          ? _maxLockout
          : _firstLockout * (1 << doublings);
      lockedUntil = _now().add(
        lockout > _maxLockout ? _maxLockout : lockout,
      );
    }
    await _saveAttemptsOrLockBriefly(
      failures: failures,
      lockedUntil: lockedUntil,
    );
  }

  Future<void> _saveAttemptsOrLockBriefly({
    required int failures,
    required DateTime? lockedUntil,
  }) async {
    try {
      await _writeAttempts(failures: failures, lockedUntil: lockedUntil);
    } on FileSystemException catch (error, stack) {
      developer.log(
        'pin attempts save failed',
        error: error,
        stackTrace: stack,
      );
      _unsavedLockoutUntil = _now().add(_firstLockout);
    }
  }

  Future<void> _writeAttempts({
    required int failures,
    required DateTime? lockedUntil,
  }) async {
    final attemptsFile = await _resolveAttemptsFile();
    await attemptsFile.parent.create(recursive: true);
    final stagedFile = File('${attemptsFile.path}.tmp');
    await stagedFile.writeAsString(
      jsonEncode(<String, int?>{
        'failures': failures,
        'lockedUntilMs': lockedUntil?.millisecondsSinceEpoch,
      }),
      flush: true,
    );
    await stagedFile.rename(attemptsFile.path);
  }

  Future<_PinAttempts> _readAttempts() async {
    final attemptsFile = await _resolveAttemptsFile();
    if (!attemptsFile.existsSync()) return const _PinAttempts(failures: 0);
    try {
      final decoded = jsonDecode(await attemptsFile.readAsString());
      if (decoded is Map<String, dynamic> && decoded['failures'] is int) {
        final lockedUntilMs = decoded['lockedUntilMs'];
        return _PinAttempts(
          failures: decoded['failures'] as int,
          lockedUntil: lockedUntilMs is int
              ? DateTime.fromMillisecondsSinceEpoch(lockedUntilMs)
              : null,
        );
      }
    } on FormatException {
      return _corruptAttempts(attemptsFile);
    } on FileSystemException catch (error, stack) {
      developer.log(
        'pin attempts read failed',
        error: error,
        stackTrace: stack,
      );
      return _PinAttempts(
        failures: _freeAttempts,
        lockedUntil: _now().add(_firstLockout),
      );
    }
    return _corruptAttempts(attemptsFile);
  }

  _PinAttempts _corruptAttempts(File attemptsFile) {
    DateTime lockStart;
    try {
      lockStart = attemptsFile.lastModifiedSync();
    } on FileSystemException {
      lockStart = _now();
    }
    return _PinAttempts(
      failures: _freeAttempts,
      lockedUntil: lockStart.add(_firstLockout),
    );
  }

  Future<File> _resolveAttemptsFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _attemptsFileName));
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }

  Future<_PinRecord?> _readRecord() async {
    try {
      final pinFile = await _resolveFile();
      if (!pinFile.existsSync()) {
        return null;
      }
      final decoded = jsonDecode(await pinFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final saltValue = decoded['salt'];
      final hashValue = decoded['hash'];
      if (saltValue is! String ||
          hashValue is! String ||
          saltValue.isEmpty ||
          hashValue.isEmpty) {
        return null;
      }
      final recoverySaltValue = decoded['recoverySalt'];
      final recoveryHashValue = decoded['recoveryHash'];
      final validRecovery =
          recoverySaltValue is String &&
          recoveryHashValue is String &&
          recoverySaltValue.isNotEmpty &&
          recoveryHashValue.isNotEmpty;
      return _PinRecord(
        saltHex: saltValue,
        hashHex: hashValue,
        recoverySaltHex: validRecovery ? recoverySaltValue : null,
        recoveryHashHex: validRecovery ? recoveryHashValue : null,
      );
    } on Object {
      return null;
    }
  }

  String _generateRecoveryCode() {
    final random = Random.secure();
    final suffixBuffer = StringBuffer();
    for (var charIndex = 0; charIndex < _recoverySuffixLength; charIndex++) {
      suffixBuffer.write(
        _recoveryAlphabet[random.nextInt(_recoveryAlphabet.length)],
      );
    }
    return '$_recoveryPrefix-$suffixBuffer';
  }

  String _normalizeRecoveryCode(String code) =>
      code.toUpperCase().replaceAll(' ', '').replaceAll('-', '');

  String _generateSaltHex() {
    final random = Random.secure();
    final saltBytes = Uint8List(_saltByteLength);
    for (var byteIndex = 0; byteIndex < _saltByteLength; byteIndex++) {
      saltBytes[byteIndex] = random.nextInt(256);
    }
    return _bytesToHex(saltBytes);
  }

  String _hashSecret({required String saltHex, required String secret}) {
    var digest = _sha256(utf8.encode('$saltHex:$secret'));
    for (var round = 1; round < _hashRounds; round++) {
      digest = _sha256(digest);
    }
    return _bytesToHex(digest);
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }
    var difference = 0;
    for (var charIndex = 0; charIndex < left.length; charIndex++) {
      difference |= left.codeUnitAt(charIndex) ^ right.codeUnitAt(charIndex);
    }
    return difference == 0;
  }

  String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byteValue in bytes) {
      buffer.write(byteValue.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Uint8List _sha256(List<int> inputBytes) {
    const roundConstants = <int>[
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];

    var hash0 = 0x6a09e667;
    var hash1 = 0xbb67ae85;
    var hash2 = 0x3c6ef372;
    var hash3 = 0xa54ff53a;
    var hash4 = 0x510e527f;
    var hash5 = 0x9b05688c;
    var hash6 = 0x1f83d9ab;
    var hash7 = 0x5be0cd19;

    final bitLength = inputBytes.length * 8;
    final paddedLength = ((inputBytes.length + 9 + 63) ~/ 64) * 64;
    final paddedBytes = Uint8List(paddedLength)
      ..setRange(0, inputBytes.length, inputBytes)
      ..[inputBytes.length] = 0x80;

    final lengthView = ByteData.sublistView(paddedBytes)
      ..setUint32(paddedLength - 8, (bitLength >> 32) & 0xffffffff)
      ..setUint32(paddedLength - 4, bitLength & 0xffffffff);

    final schedule = Uint32List(64);
    for (var offset = 0; offset < paddedLength; offset += 64) {
      for (var wordIndex = 0; wordIndex < 16; wordIndex++) {
        schedule[wordIndex] = lengthView.getUint32(offset + wordIndex * 4);
      }
      for (var wordIndex = 16; wordIndex < 64; wordIndex++) {
        final previous15 = schedule[wordIndex - 15];
        final previous2 = schedule[wordIndex - 2];
        final sigma0 =
            _rotateRight(previous15, 7) ^
            _rotateRight(previous15, 18) ^
            (previous15 >>> 3);
        final sigma1 =
            _rotateRight(previous2, 17) ^
            _rotateRight(previous2, 19) ^
            (previous2 >>> 10);
        schedule[wordIndex] =
            (schedule[wordIndex - 16] +
                sigma0 +
                schedule[wordIndex - 7] +
                sigma1) &
            0xffffffff;
      }

      var wordA = hash0;
      var wordB = hash1;
      var wordC = hash2;
      var wordD = hash3;
      var wordE = hash4;
      var wordF = hash5;
      var wordG = hash6;
      var wordH = hash7;

      for (var round = 0; round < 64; round++) {
        final upperSigma1 =
            _rotateRight(wordE, 6) ^
            _rotateRight(wordE, 11) ^
            _rotateRight(wordE, 25);
        final choice = (wordE & wordF) ^ ((~wordE) & wordG);
        final temp1 =
            (wordH +
                upperSigma1 +
                choice +
                roundConstants[round] +
                schedule[round]) &
            0xffffffff;
        final upperSigma0 =
            _rotateRight(wordA, 2) ^
            _rotateRight(wordA, 13) ^
            _rotateRight(wordA, 22);
        final majority = (wordA & wordB) ^ (wordA & wordC) ^ (wordB & wordC);
        final temp2 = (upperSigma0 + majority) & 0xffffffff;

        wordH = wordG;
        wordG = wordF;
        wordF = wordE;
        wordE = (wordD + temp1) & 0xffffffff;
        wordD = wordC;
        wordC = wordB;
        wordB = wordA;
        wordA = (temp1 + temp2) & 0xffffffff;
      }

      hash0 = (hash0 + wordA) & 0xffffffff;
      hash1 = (hash1 + wordB) & 0xffffffff;
      hash2 = (hash2 + wordC) & 0xffffffff;
      hash3 = (hash3 + wordD) & 0xffffffff;
      hash4 = (hash4 + wordE) & 0xffffffff;
      hash5 = (hash5 + wordF) & 0xffffffff;
      hash6 = (hash6 + wordG) & 0xffffffff;
      hash7 = (hash7 + wordH) & 0xffffffff;
    }

    final outputBytes = Uint8List(32);
    ByteData.sublistView(outputBytes)
      ..setUint32(0, hash0)
      ..setUint32(4, hash1)
      ..setUint32(8, hash2)
      ..setUint32(12, hash3)
      ..setUint32(16, hash4)
      ..setUint32(20, hash5)
      ..setUint32(24, hash6)
      ..setUint32(28, hash7);
    return outputBytes;
  }

  int _rotateRight(int value, int shift) =>
      ((value >>> shift) | (value << (32 - shift))) & 0xffffffff;
}

final class _PinRecord {
  const new({
    required this.saltHex,
    required this.hashHex,
    this.recoverySaltHex,
    this.recoveryHashHex,
  });

  final String saltHex;
  final String hashHex;
  final String? recoverySaltHex;
  final String? recoveryHashHex;
}

final class _PinAttempts {
  const new({required this.failures, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;
}
