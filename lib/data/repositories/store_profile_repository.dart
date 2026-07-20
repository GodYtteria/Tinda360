import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:tinda360/core/app_log.dart';
import 'package:tinda360/core/failures/store_failure.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/result.dart';
import 'package:tinda360/core/store/store_profile.dart';
import 'package:tinda360/data/db/app_database.dart';

/// Reads and writes the single store profile row.
final class StoreProfileRepository {
  /// Creates the repository.
  StoreProfileRepository({
    required AppDatabase db,
    required Clock clock,
    required AppLog log,
  }) : _db = db,
       _clock = clock,
       _log = log;

  final AppDatabase _db;
  final Clock _clock;
  final AppLog _log;

  /// The profile, re-emitted whenever it changes.
  Stream<StoreProfile> watch() =>
      (_db.select(_db.storeProfiles)
            ..where((s) => s.id.equals(AppDatabase.storeProfileId)))
          .watchSingle()
          .map(
            (row) => StoreProfile(
              name: row.name,
              currency:
                  Currency.tryParse(row.currencyCode) ??
                  (throw StateError('Unknown currency "${row.currencyCode}"')),
              onboardingDone: row.onboardingDone,
            ),
          );

  /// Saves the store name and marks first-run setup as done.
  @useResult
  Future<Result<void, StoreFailure>> completeOnboarding(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Err(StoreNameRequired());
    try {
      await _db.customUpdate(
        'UPDATE store_profiles SET name = ?, onboarding_done = 1, '
        'updated_at = ?, row_revision = row_revision + 1 WHERE id = ?',
        variables: [
          Variable.withString(trimmed),
          Variable.withInt(_clock.now().toUtc().millisecondsSinceEpoch),
          Variable.withString(AppDatabase.storeProfileId),
        ],
        updates: {_db.storeProfiles},
        updateKind: UpdateKind.update,
      );
      return const Ok(null);
    } on Exception catch (error, stack) {
      _log.error('store.complete_onboarding', error, stack);
      return const Err(StoreUnavailable());
    }
  }
}
