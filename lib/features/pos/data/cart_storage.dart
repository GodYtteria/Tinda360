import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/data/data_providers.dart';

final cartDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getApplicationSupportDirectory,
);

final cartStorageProvider = Provider<CartStorage>(
  (ref) => CartStorage(directoryProvider: ref.watch(cartDirectoryProvider)),
);

final activeCartStoreIdProvider = Provider<String?>(
  (ref) => ref.watch(storeRegistryProvider).value?.activeStoreId,
);

final class CartStorage {
  CartStorage({required Future<Directory> Function() directoryProvider})
    : _directoryProvider = directoryProvider;

  static const String _linesKey = 'lines';
  static final RegExp _unsafeCharacters = RegExp(r'[^A-Za-z0-9_-]');

  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  Future<Map<String, Quantity>> read(String storeId) async {
    await _lastWrite;
    try {
      final file = await _resolveFile(storeId);
      if (!file.existsSync()) return const {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const {};
      final lines = decoded[_linesKey];
      if (lines is! Map<String, dynamic>) return const {};
      final restored = <String, Quantity>{};
      for (final entry in lines.entries) {
        final milli = entry.value;
        if (milli is int && milli > 0) {
          restored[entry.key] = Quantity.milli(milli);
        }
      }
      return Map<String, Quantity>.unmodifiable(restored);
    } on Object catch (error) {
      debugPrint('cart_storage read failed: $error');
      return const {};
    }
  }

  Future<void> write(String storeId, Map<String, Quantity> cart) {
    final snapshot = <String, int>{
      for (final entry in cart.entries) entry.key: entry.value.milli,
    };
    return _enqueue(
      () async => await _replaceJson(
        await _resolveFile(storeId),
        snapshot.isEmpty ? null : {_linesKey: snapshot},
      ),
    );
  }

  Future<Map<String, int>> readPrices(String storeId) async {
    await _lastWrite;
    try {
      final file = await _resolvePricesFile(storeId);
      if (!file.existsSync()) return const {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is int && (entry.value as int) >= 0)
            entry.key: entry.value as int,
      };
    } on Object catch (error) {
      debugPrint('cart_storage prices read failed: $error');
      return const {};
    }
  }

  Future<void> writePrices(String storeId, Map<String, int> unitPricesMinor) {
    final snapshot = Map<String, int>.of(unitPricesMinor)
      ..removeWhere((productId, minor) => minor < 0);
    return _enqueue(
      () async => await _replaceJson(
        await _resolvePricesFile(storeId),
        snapshot.isEmpty ? null : snapshot,
      ),
    );
  }

  Future<void> deleteStore(String storeId) {
    return _enqueue(() async {
      final cartFile = await _resolveFile(storeId);
      if (cartFile.existsSync()) await cartFile.delete();
      final pricesFile = await _resolvePricesFile(storeId);
      if (pricesFile.existsSync()) await pricesFile.delete();
    });
  }

  Future<void> _replaceJson(File file, Object? content) async {
    if (content == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final stagedFile = File('${file.path}.tmp');
    await stagedFile.writeAsString(jsonEncode(content), flush: true);
    await stagedFile.rename(file.path);
  }

  Future<File> _resolvePricesFile(String storeId) =>
      _storeFile('tinda360_cart_prices', storeId);

  Future<void> _enqueue(Future<void> Function() operation) {
    final write = _lastWrite.then((_) => operation());
    _lastWrite = write.catchError((Object error) {
      debugPrint('cart_storage write failed: $error');
    });
    return write;
  }

  Future<File> _resolveFile(String storeId) =>
      _storeFile('tinda360_cart', storeId);

  Future<File> _storeFile(String prefix, String storeId) async {
    final directory = await _directoryProvider();
    final safeId = storeId.replaceAll(_unsafeCharacters, '_');
    return File(path.join(directory.path, '${prefix}_$safeId.json'));
  }
}
