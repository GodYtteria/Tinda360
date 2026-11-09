import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/customers/ledger_record.dart';
import 'package:tinda360/core/customers/utang_breakdown.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/features/utang/presentation/ledger_entry_delete.dart';

LedgerRecord _record(
  String kind, {
  String? saleId,
  bool isDeleted = false,
  int amountMinor = 500,
}) => LedgerRecord(
  id: 'entry-$kind',
  createdAtMs: 1,
  kind: kind,
  amount: Money(amountMinor, Currency.php),
  saleId: saleId,
  isDeleted: isDeleted,
);

void main() {
  test('manual payment and manual interest ask for delete confirmation', () {
    expect(
      ledgerTapActionFor(_record('payment')),
      LedgerTapAction.confirmDelete,
    );
    expect(
      ledgerTapActionFor(_record('interest')),
      LedgerTapAction.confirmDelete,
    );
    expect(isLedgerEntryDeletable(_record('payment')), isTrue);
  });

  test('debt and sale-linked lines show the sale hint', () {
    expect(ledgerTapActionFor(_record('debt')), LedgerTapAction.showSaleHint);
    expect(
      ledgerTapActionFor(_record('payment', saleId: 's1')),
      LedgerTapAction.showSaleHint,
    );
    expect(
      ledgerTapActionFor(_record('interest', saleId: 's1')),
      LedgerTapAction.showSaleHint,
    );
    expect(isLedgerEntryDeletable(_record('debt')), isFalse);
  });

  test('deleted lines do nothing on tap', () {
    expect(
      ledgerTapActionFor(_record('payment', isDeleted: true)),
      LedgerTapAction.nothing,
    );
  });

  test('breakdown ignores deleted records', () {
    final breakdown = computeUtangBreakdown([
      _record('debt', amountMinor: 1000),
      _record('payment', isDeleted: true, amountMinor: 900),
    ], Currency.php);
    expect(breakdown.utang, const Money(1000, Currency.php));
  });
}
