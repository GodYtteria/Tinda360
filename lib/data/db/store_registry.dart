import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Metadata for a single on-device store database.
final class StoreEntry {
  /// Creates a store entry.
  const StoreEntry({
    required this.id,
    required this.name,
    required this.fileName,
  });

  /// Parses a store entry from JSON, validating the database filename.
  factory StoreEntry.fromJson(Map<String, dynamic> json) {
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

  /// Unique identifier for this store.
  final String id;

  /// Display name for this store.
  final String name;

  /// SQLite file basename inside the application support directory.
  final String fileName;

  /// Serializes this entry to JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fileName': fileName,
  };

  /// Returns a copy with updated fields.
  StoreEntry copyWith({String? name}) => StoreEntry(
    id: id,
    name: name ?? this.name,
    fileName: fileName,
  );
}

/// Persisted registry of all local stores and the currently active store.
final class StoreRegistry {
  /// Creates a store registry snapshot.
  StoreRegistry({
    required this.activeStoreId,
    required List<StoreEntry> stores,
  }) : stores = List<StoreEntry>.unmodifiable(stores);

  /// Returns the default single-store registry.
  factory StoreRegistry.defaultRegistry() => StoreRegistry(
    activeStoreId: defaultStoreId,
    stores: const [
      StoreEntry(
        id: defaultStoreId,
        name: '',
        fileName: defaultFileName,
      ),
    ],
  );

  /// Parses a registry from decoded JSON.
  factory StoreRegistry.fromJson(Map<String, dynamic> json) {
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

  /// Default store id used on first run or reset.
  static const String defaultStoreId = 'default';

  /// Default SQLite filename preserving existing single-store data.
  static const String defaultFileName = 'tinda360.sqlite';

  /// Registry filename inside the application support directory.
  static const String registryFileName = 'stores.json';

  /// Id of the active store.
  final String activeStoreId;

  /// All registered stores.
  final List<StoreEntry> stores;

  /// Returns the currently active [StoreEntry].
  StoreEntry get activeStore => stores.firstWhere(
    (entry) => entry.id == activeStoreId,
    orElse: () => stores.first,
  );

  /// Serializes this registry to JSON.
  Map<String, dynamic> toJson() => {
    'activeStoreId': activeStoreId,
    'stores': stores.map((entry) => entry.toJson()).toList(),
  };

  /// Validates that [fileName] is a safe basename without traversal or null bytes.
  static bool isValidDatabaseFileName(String fileName) {
    if (fileName.isEmpty) return false;
    if (fileName.contains(r'\x00') || fileName.contains('\u0000')) return false;
    if (fileName.contains('..')) return false;
    if (fileName.contains('/') || fileName.contains(r'\')) return false;
    return p.basename(fileName) == fileName;
  }

  /// Builds the unique database filename for [storeId].
  static String databaseFileNameForId(String storeId) {
    final sanitized = storeId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '');
    if (sanitized.isEmpty) return defaultFileName;
    return 'tinda360_$sanitized.sqlite';
  }

  /// Loads the registry from `stores.json`, falling back to default if missing
  /// or if the platform directory is unavailable (e.g., in widget tests).
  static Future<StoreRegistry> load({
    Future<Directory> Function()? directoryProvider,
  }) async {
    try {
      final directory = await (directoryProvider ?? getApplicationSupportDirectory)();
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

  /// Persists this registry to `stores.json`.
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
      tempFile.writeAsStringSync(jsonEncode(toJson()), flush: true);
      if (file.existsSync()) {
        file.deleteSync();
      }
      tempFile.renameSync(file.path);
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

  /// Deletes the SQLite database file and WAL/SHM sidecars for [fileName].
  static Future<void> deleteDatabaseFiles(
    String fileName, {
    Future<Directory> Function()? directoryProvider,
  }) async {
    if (!isValidDatabaseFileName(fileName)) return;
    try {
      final directory = await (directoryProvider ?? getApplicationSupportDirectory)();
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
