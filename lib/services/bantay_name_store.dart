import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tinda360/core/sales/cashier_name.dart';
import 'package:tinda360/data/data_providers.dart';

abstract interface class BantayNameStore {
  Future<String?> read(String storeId);

  Future<void> write(String storeId, String? name);
}

final class FileBantayNameStore implements BantayNameStore {
  new({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _fileName = 'tinda360_bantay_names.json';
  final Future<Directory> Function() _directoryProvider;
  Future<void> _lastWrite = Future<void>.value();

  @override
  Future<String?> read(String storeId) async {
    final names = await _readNames();
    final value = names[storeId];
    return value is String ? normalizeCashierName(value) : null;
  }

  @override
  Future<void> write(String storeId, String? name) {
    final normalized = normalizeCashierName(name);
    final pending = _lastWrite.then((_) async {
      final file = await _resolveFile();
      final names = await _readNames();
      if (normalized == null) {
        names.remove(storeId);
      } else {
        names[storeId] = normalized;
      }
      await file.parent.create(recursive: true);
      final stagedFile = File('${file.path}.tmp');
      await stagedFile.writeAsString(jsonEncode(names), flush: true);
      await stagedFile.rename(file.path);
    });
    _lastWrite = pending.then((_) {}, onError: (Object error) {});
    return pending;
  }

  Future<Map<String, dynamic>> _readNames() async {
    final file = await _resolveFile();
    if (!file.existsSync()) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Future<File> _resolveFile() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}

final bantayNameStoreProvider = Provider<BantayNameStore>(
  (ref) => FileBantayNameStore(),
);

final class BantayNameNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final storeId = ref.watch(storeRegistryProvider).value?.activeStoreId;
    if (storeId == null) return null;
    return ref.read(bantayNameStoreProvider).read(storeId);
  }

  Future<void> setName(String? rawName) async {
    final storeId = ref.read(storeRegistryProvider).value?.activeStoreId;
    if (storeId == null) return;
    final normalized = normalizeCashierName(rawName);
    await ref.read(bantayNameStoreProvider).write(storeId, normalized);
    state = AsyncData(normalized);
  }
}

final bantayNameProvider = AsyncNotifierProvider<BantayNameNotifier, String?>(
  BantayNameNotifier.new,
);
