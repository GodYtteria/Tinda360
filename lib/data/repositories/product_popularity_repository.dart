import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:tinda360/data/db/app_database.dart';

class ProductPopularityRepository {
  ProductPopularityRepository({
    required AppDatabase db,
    required Clock clock,
    this.windowDays = defaultWindowDays,
  }) : _db = db,
       _clock = clock;

  static const int defaultWindowDays = 30;

  final AppDatabase _db;
  final Clock _clock;
  final int windowDays;

  Selectable<QueryRow> _soldQuery() {
    final now = _clock.now();
    final windowStart = DateTime(now.year, now.month, now.day - windowDays);
    return _db.customSelect(
      'SELECT si.product_id AS product_id, '
      'SUM(si.qty_milli) AS sold_milli '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'WHERE s.is_deleted = 0 AND si.is_deleted = 0 '
      'AND s.created_at >= ? '
      'GROUP BY si.product_id',
      variables: [Variable<int>(windowStart.toUtc().millisecondsSinceEpoch)],
      readsFrom: {_db.sales, _db.saleItems},
    );
  }

  Map<String, int> _toUnitsSold(List<QueryRow> rows) => {
    for (final row in rows)
      row.read<String>('product_id'): row.read<int>('sold_milli'),
  };

  Future<Map<String, int>> unitsSoldMilliByProductId() async =>
      _toUnitsSold(await _soldQuery().get());

  Stream<Map<String, int>> watchUnitsSoldMilliByProductId() =>
      _soldQuery().watch().map(_toUnitsSold);
}
