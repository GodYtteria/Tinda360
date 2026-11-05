import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';

final class SaleRecordLine {
  const SaleRecordLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.returnedQuantity = Quantity.zero,
  });

  final Quantity returnedQuantity;

  Quantity get returnableQuantity => quantity - returnedQuantity;

  final String productId;

  final String productName;

  final ProductUnit unit;

  final Quantity quantity;

  final Money unitPrice;

  final Money lineTotal;
}

final class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.createdAtMs,
    required this.method,
    required this.paid,
    required this.total,
    required this.lines,
    this.tendered,
    this.receiptNumber,
    this.customerName,
    this.ewalletReference,
    this.refundedAmount,
    this.interestAmount,
    this.cashierName,
  });

  final String? cashierName;

  final Money? interestAmount;

  Money get interest => interestAmount ?? Money.zero(total.currency);

  final Money? refundedAmount;

  Money get refunded => refundedAmount ?? Money.zero(total.currency);

  Money get netTotal => total - refunded;

  final String id;

  final int createdAtMs;

  final PaymentMethod method;

  final Money paid;

  final Money? tendered;

  Money get received => tendered ?? paid;

  Money get change =>
      received > total ? received - total : Money.zero(total.currency);

  final Money total;

  final List<SaleRecordLine> lines;

  final String? receiptNumber;

  final String? customerName;

  final String? ewalletReference;
}
