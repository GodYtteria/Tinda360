import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class StoreEntry {
  const new({
    required this.id,
    required this.name,
    required this.fileName,
  });

  factory fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final rawFileName = json['fileName'] as String? ?? '';
    final safeFileName = StoreRegistry.isValidDatabaseFileName(rawFileName)
        ? rawFileName
        : StoreRegistry.defaultFileName;
    return StoreEntry(
      id: id.isEmpty ? StoreRegistry.defaultStoreId : id,
      name: name,
      fileName: safeFileName,
    );
  }

  final String id;

  final String name;

  final String fileName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
  };

  StoreEntry copyWith({String? name}) => StoreEntry(
    id: id,
    name: name ?? this.name,
    fileName: fileName,
  );
}

final class StoreRegistry {
  new({
    required this.activeStoreId,
    required List<StoreEntry> stores,
  }) : stores = List<StoreEntry>.unmodifiable(stores);

  factory defaultRegistry() => StoreRegistry(
    activeStoreId: defaultStoreId,
    stores: const [
      StoreEntry(
        id: defaultStoreId,
        name: '',
        fileName: defaultFileName,
      ),
    ],
  );

  factory fromJson(Map<String, dynamic> json) {
    final rawStores = json['stores'];
    final parsedStores = <StoreEntry>[];
    if (rawStores is List) {
      for (final item in rawStores) {
        if (item is Map<String, dynamic>) {
          parsedStores.add(StoreEntry.fromJson(item));
        }
      }
    }
    if (parsedStores.isEmpty) {
      return StoreRegistry.defaultRegistry();
    }
    final rawActiveId = json['activeStoreId'] as String? ?? '';
    final hasActive = parsedStores.any((entry) => entry.id == rawActiveId);
    return StoreRegistry(
      activeStoreId: hasActive ? rawActiveId : parsedStores.first.id,
      stores: parsedStores,
    );
  }

  static const String defaultStoreId = 'default';

  static const String defaultFileName = 'tinda360.sqlite';

  static const String registryFileName = 'stores.json';

  final String activeStoreId;

  final List<StoreEntry> stores;

  StoreEntry get activeStore => stores.firstWhere(
    (entry) => entry.id == activeStoreId,
    orElse: () => stores.first,
  );

  Map<String, dynamic> toJson() => {
    'activeStoreId': activeStoreId,
    'stores': stores.map((entry) => entry.toJson()).toList(),
  };

  static bool isValidDatabaseFileName(String fileName) {
    if (fileName.isEmpty) return false;
    if (fileName.contains(r'\x00') || fileName.contains('\u0000')) return false;
    if (fileName.contains('..')) return false;
    if (fileName.contains('/') || fileName.contains(r'\')) return false;
    return p.basename(fileName) == fileName;
  }

  static String databaseFileNameForId(String storeId) {
    final sanitized = storeId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    if (sanitized.isEmpty) return defaultFileName;
    return 'tinda360_$sanitized.sqlite';
  }

  static Future<StoreRegistry> load({
    Future<Directory> Function()? directoryProvider,
  }) async {
    try {
      final directory =
          await (directoryProvider ?? getApplicationSupportDirectory)();
      final file = File(p.join(directory.path, registryFileName));
      if (!file.existsSync()) {
        return StoreRegistry.defaultRegistry();
      }
      final rawContent = file.readAsStringSync();
      if (rawContent.trim().isEmpty) {
        return StoreRegistry.defaultRegistry();
      }
      final decoded = jsonDecode(rawContent);
      if (decoded is Map<String, dynamic>) {
        return StoreRegistry.fromJson(decoded);
      }
      return StoreRegistry.defaultRegistry();
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Failed to load store registry; using default.',
        name: 'StoreRegistry',
        error: error,
        stackTrace: stackTrace,
      );
      return StoreRegistry.defaultRegistry();
    }
  }

  Future<void> save({
    Future<Directory> Function()? directoryProvider,
  }) async {
    try {
      final directory =
          await (directoryProvider ?? getApplicationSupportDirectory)();
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      final file = File(p.join(directory.path, registryFileName));
      final tempFile = File('${file.path}.tmp');
      tempFile
        ..writeAsStringSync(jsonEncode(toJson()), flush: true)
        ..renameSync(file.path);
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Failed to save store registry.',
        name: 'StoreRegistry',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<void> deleteDatabaseFiles(
    String fileName, {
    Future<Directory> Function()? directoryProvider,
  }) async {
    if (!isValidDatabaseFileName(fileName)) return;
    try {
      final directory =
          await (directoryProvider ?? getApplicationSupportDirectory)();
      final basePath = p.join(directory.path, fileName);
      for (final candidatePath in [
        basePath,
        '$basePath-wal',
        '$basePath-shm',
      ]) {
        final candidate = File(candidatePath);
        if (candidate.existsSync()) {
          candidate.deleteSync();
        }
      }
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Failed to delete store database files.',
        name: 'StoreRegistry',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
