import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/data/db/connection.dart';
import 'package:tinda360/data/db/id_generator.dart';
import 'package:tinda360/data/db/store_registry.dart';
import 'package:tinda360/data/repositories/customer_repository.dart';
import 'package:tinda360/data/repositories/expense_repository.dart';
import 'package:tinda360/data/repositories/product_repository.dart';
import 'package:tinda360/data/repositories/sale_repository.dart';
import 'package:tinda360/data/repositories/store_profile_repository.dart';
import 'package:tinda360/features/chat/data/yumi_tool_executor.dart';
import 'package:tinda360/features/pos/data/cart_storage.dart';
import 'package:tinda360/services/service_providers.dart';

final appDatabaseFactoryProvider = Provider<AppDatabase Function()>(
  (ref) =>
      () => AppDatabase(openConnection()),
);

final databaseFileProvider = Provider<Future<File> Function()>(
  (ref) => databaseFile,
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = ref.watch(appDatabaseFactoryProvider)();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidIdGenerator());

final storeCurrencyProvider = Provider<Currency>((ref) => Currency.php);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final storeProfileRepositoryProvider = Provider<StoreProfileRepository>(
  (ref) => StoreProfileRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    log: ref.watch(appLogProvider),
  ),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    log: ref.watch(appLogProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final yumiToolExecutorProvider = Provider<YumiToolExecutor>(
  (ref) => YumiToolExecutor(
    db: ref.watch(appDatabaseProvider),
    products: ref.watch(productRepositoryProvider),
    sales: ref.watch(saleRepositoryProvider),
    customers: ref.watch(customerRepositoryProvider),
    expenses: ref.watch(expenseRepositoryProvider),
    storeProfile: ref.watch(storeProfileRepositoryProvider),
    clock: ref.watch(clockProvider),
    currency: ref.watch(storeCurrencyProvider),
  ),
);

final storeRegistryProvider =
    AsyncNotifierProvider<StoreRegistryNotifier, StoreRegistry>(
      StoreRegistryNotifier.new,
    );

class StoreRegistryNotifier extends AsyncNotifier<StoreRegistry> {
  @override
  Future<StoreRegistry> build() => StoreRegistry.load();

  List<StoreEntry> listStores() => state.value?.stores ?? const [];

  Future<List<StoreEntry>> _syncActiveStoreName(
    List<StoreEntry> stores,
    String activeStoreId,
  ) async {
    final activeIndex = stores.indexWhere((entry) => entry.id == activeStoreId);
    if (activeIndex < 0 || stores[activeIndex].name.isNotEmpty) return stores;
    try {
      final profile = await ref
          .read(storeProfileRepositoryProvider)
          .watch()
          .first;
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

  Future<void> createStore(String name) async {
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
      activeStoreId: current.activeStoreId,
      stores: [...syncedStores, newEntry],
    );

    await updated.save();
    state = AsyncData(updated);
  }

  Future<void> switchStore(String storeId) async {
    final current = state.value ?? await StoreRegistry.load();
    if (current.activeStoreId == storeId) return;
    if (!current.stores.any((entry) => entry.id == storeId)) return;

    final syncedStores = await _syncActiveStoreName(
      current.stores,
      current.activeStoreId,
    );
    final updated = StoreRegistry(
      activeStoreId: storeId,
      stores: syncedStores,
    );
    await updated.save();
    try {
      await ref.read(appDatabaseProvider).close();
    } on Exception catch (error, stack) {
      ref.read(appLogProvider).error('store.switch_close', error, stack);
    }
    state = AsyncData(updated);
    ref.invalidate(appDatabaseProvider);
  }

  Future<void> deleteStore(String storeId) async {
    final current = state.value ?? await StoreRegistry.load();
    final targetIndex = current.stores.indexWhere(
      (entry) => entry.id == storeId,
    );
    if (targetIndex == -1) return;

    final target = current.stores[targetIndex];
    final wasActive = target.id == current.activeStoreId;
    final remaining = current.stores
        .where((entry) => entry.id != storeId)
        .toList();
    final updated = remaining.isEmpty
        ? StoreRegistry.defaultRegistry()
        : StoreRegistry(
            activeStoreId: wasActive
                ? remaining.first.id
                : current.activeStoreId,
            stores: remaining,
          );

    await updated.save();
    var databaseClosed = true;
    if (wasActive) {
      try {
        await ref.read(appDatabaseProvider).close();
      } on Exception catch (error, stack) {
        databaseClosed = false;
        ref.read(appLogProvider).error('store.delete_close', error, stack);
      }
    }
    if (databaseClosed) {
      await StoreRegistry.deleteDatabaseFiles(target.fileName);
    }
    try {
      await ref.read(cartStorageProvider).deleteStore(storeId);
    } on Exception catch (error, stack) {
      ref.read(appLogProvider).error('store.delete_cart', error, stack);
    }
    state = AsyncData(updated);
    if (wasActive || remaining.isEmpty) {
      ref.invalidate(appDatabaseProvider);
    }
  }
}
