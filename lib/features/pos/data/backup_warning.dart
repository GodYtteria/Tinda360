import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/data/data_providers.dart';
import 'package:tinda360/data/db/app_database.dart';
import 'package:tinda360/services/backup_status.dart';
import 'package:tinda360/services/service_providers.dart';

const Duration staleBackupThreshold = Duration(days: 7);

const int salesBeforeBackupReminder = 20;

bool shouldWarnAboutBackup({
  required bool backupConnected,
  required DateTime? lastSuccessfulBackup,
  required int saleCount,
  required DateTime now,
}) {
  if (!backupConnected) return saleCount >= salesBeforeBackupReminder;
  if (lastSuccessfulBackup == null) return true;
  return now.difference(lastSuccessfulBackup) > staleBackupThreshold;
}

String backupWarningDayKey(DateTime moment) {
  final local = moment.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

Future<int> _countActiveSales(AppDatabase database) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS sale_count FROM sales WHERE is_deleted = 0',
        readsFrom: {database.sales},
      )
      .getSingle();
  return row.read<int>('sale_count');
}

final FutureProvider<bool> backupWarningConnectedProvider =
    FutureProvider.autoDispose<bool>(
      (ref) => ref.watch(backupPreferencesProvider).readBackupConnected(),
    );

final FutureProvider<bool> backupWarningProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final now = ref.watch(clockProvider).now();
      final statusStore = ref.watch(backupStatusStoreProvider);
      final preferences = ref.watch(backupPreferencesProvider);
      final database = ref.watch(appDatabaseProvider);
      final dismissedDay = await statusStore.readWarningDismissedDay();
      if (dismissedDay == backupWarningDayKey(now)) return false;
      final connected = await preferences.readBackupConnected();
      final lastSuccessfulBackup = await statusStore.readLastSuccessfulBackup();
      final saleCount = connected ? 0 : await _countActiveSales(database);
      return shouldWarnAboutBackup(
        backupConnected: connected,
        lastSuccessfulBackup: lastSuccessfulBackup,
        saleCount: saleCount,
        now: now,
      );
    });
