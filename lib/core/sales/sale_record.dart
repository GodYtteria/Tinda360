import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';

/// A single line item inside a recorded [SaleRecord].
final class SaleRecordLine {
  /// Creates a recorded sale line.
  const SaleRecordLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  /// Product identifier.
  final String productId;

  /// Product display name.
  final String productName;

  /// Product unit.
  final ProductUnit unit;

  /// Sold quantity.
  final Quantity quantity;

  /// Price per unit at the time of sale.
  final Money unitPrice;

  /// Computed line subtotal.
  final Money lineTotal;
}

/// A recorded sale transaction with its itemized lines.
final class SaleRecord {
  /// Creates a sale record.
  const SaleRecord({
    required this.id,
    required this.createdAtMs,
    required this.method,
    required this.paid,
    required this.total,
    required this.lines,
    this.customerName,
    this.ewalletReference,
  });

  /// Sale identifier.
  final String id;

  /// UTC epoch milliseconds when the sale was recorded.
  final int createdAtMs;

  /// Payment method used.
  final PaymentMethod method;

  /// Cash/payment amount tendered.
  final Money paid;

  /// Total sale amount.
  final Money total;

  /// Itemized lines in this sale.
  final List<SaleRecordLine> lines;

  /// Suki name when sold on utang, if any.
  final String? customerName;

  /// Optional e-wallet reference number.
  final String? ewalletReference;
}
