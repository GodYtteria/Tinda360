import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/connection.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/db/store_registry.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';
import 'package:tinda360/services/service_providers.dart';

/// Factory used to open [AppDatabase]; tests may override [appDatabaseProvider]
/// directly.
final appDatabaseFactoryProvider = Provider<AppDatabase Function()>(
  (ref) => () => AppDatabase(openConnection()),
);

/// Resolves the on-device SQLite file used for Drive backup and restore.
final databaseFileProvider = Provider<Future<File> Function()>(
  (ref) => databaseFile,
);

/// The open database. Disposed automatically when invalidated after a restore.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = ref.watch(appDatabaseFactoryProvider)();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// Row id source.
final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidIdGenerator());

/// The store's currency. Single-currency for v1.
final storeCurrencyProvider = Provider<Currency>((ref) => Currency.php);

/// Products and stock.
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

/// Sales.
final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

/// Customers and utang.
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

/// The store profile.
final storeProfileRepositoryProvider = Provider<StoreProfileRepository>(
  (ref) => StoreProfileRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    log: ref.watch(appLogProvider),
  ),
);

/// Store expenses (gastos).
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

/// Multi-store registry and active store switcher.
final storeRegistryProvider =
    AsyncNotifierProvider<StoreRegistryNotifier, StoreRegistry>(
      StoreRegistryNotifier.new,
    );

/// Manages creating, switching, and deleting local stores.
class StoreRegistryNotifier extends AsyncNotifier<StoreRegistry> {
  @override
  Future<StoreRegistry> build() => StoreRegistry.load();

  /// Returns all currently registered stores.
  List<StoreEntry> listStores() => state.value?.stores ?? const [];

  Future<List<StoreEntry>> _syncActiveStoreName(List<StoreEntry> stores, String activeStoreId) async {
    final activeIndex = stores.indexWhere((entry) => entry.id == activeStoreId);
    if (activeIndex < 0 || stores[activeIndex].name.isNotEmpty) return stores;
    try {
      final profile = await ref.read(storeProfileRepositoryProvider).watch().first;
      final profileName = profile.name.trim();
      if (profileName.isEmpty) return stores;
      final updatedStores = [...stores];
      updatedStores[activeIndex] = StoreEntry(
        id: stores[activeIndex].id,
        name: profileName,
        fileName: stores[activeIndex].fileName,
      );
      return updatedStores;
    } on Exception {
      return stores;
    }
  }

  /// Creates a new store database, switches to it, and completes onboarding.
  Future<void> createAndSwitchStore(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final current = state.value ?? await StoreRegistry.load();
    final syncedStores = await _syncActiveStoreName(
      current.stores,
      current.activeStoreId,
    );
    final storeId = ref.read(idGeneratorProvider).next();
    final fileName = StoreRegistry.databaseFileNameForId(storeId);
    final newEntry = StoreEntry(
      id: storeId,
      name: trimmedName,
      fileName: fileName,
    );
    final updated = StoreRegistry(
      activeStoreId: storeId,
      stores: [...syncedStores, newEntry],
    );

    await ref.read(appDatabaseProvider).close();
    await updated.save();
    state = AsyncData(updated);
    ref.invalidate(appDatabaseProvider);
    final onboardingResult = await ref
        .read(storeProfileRepositoryProvider)
        .completeOnboarding(trimmedName);
    if (onboardingResult case Err(:final failure)) {
      ref.read(appLogProvider).error(
        'store.create_and_switch_onboarding',
        failure,
        StackTrace.current,
      );
    }
  }

  /// Switches the active store to [storeId] and reopens the database.
  Future<void> switchStore(String storeId) async {
    final current = state.value ?? await StoreRegistry.load();
    if (current.activeStoreId == storeId) return;
    if (!current.stores.any((entry) => entry.id == storeId)) return;

    final syncedStores = await _syncActiveStoreName(
      current.stores,
      current.activeStoreId,
    );
    await ref.read(appDatabaseProvider).close();
    final updated = StoreRegistry(
      activeStoreId: storeId,
      stores: syncedStores,
    );
    await updated.save();
    state = AsyncData(updated);
    ref.invalidate(appDatabaseProvider);
  }

  /// Deletes [storeId] and its database files, switching or resetting if active.
  Future<void> deleteStore(String storeId) async {
    final current = state.value ?? await StoreRegistry.load();
    final targetIndex = current.stores.indexWhere((entry) => entry.id == storeId);
    if (targetIndex == -1) return;

    final target = current.stores[targetIndex];
    final wasActive = target.id == current.activeStoreId;
    if (wasActive) {
      await ref.read(appDatabaseProvider).close();
    }

    await StoreRegistry.deleteDatabaseFiles(target.fileName);

    final remaining = current.stores
        .where((entry) => entry.id != storeId)
        .toList();
    final updated = remaining.isEmpty
        ? StoreRegistry.defaultRegistry()
        : StoreRegistry(
            activeStoreId: wasActive ? remaining.first.id : current.activeStoreId,
            stores: remaining,
          );

    await updated.save();
    state = AsyncData(updated);
    if (wasActive || remaining.isEmpty) {
      ref.invalidate(appDatabaseProvider);
    }
  }
}
