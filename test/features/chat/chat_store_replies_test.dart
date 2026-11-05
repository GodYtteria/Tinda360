import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/catalog/product.dart';
import 'package:tinda360/core/catalog/product_unit.dart';
import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/currency.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/features/chat/presentation/chat_store_replies.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

StockedProduct _product(String id, int stockCount, {int? lowAt}) =>
    StockedProduct(
      product: Product(
        id: id,
        name: 'Item $id',
        unit: ProductUnit.piece,
        price: const Money(1000, Currency.php),
        cost: const Money(800, Currency.php),
        lowStockAt: lowAt == null ? null : Quantity.whole(lowAt),
      ),
      stock: Quantity.whole(stockCount),
    );

ExpenseEntry _expense(String id, String title, int centavos) => ExpenseEntry(
  id: id,
  createdAtMs: 0,
  daySerial: 1,
  title: title,
  amount: Money(centavos, Currency.php),
);

SalesSummary _summary(int revenue, int cost) => SalesSummary(
  revenue: Money(revenue, Currency.php),
  cost: Money(cost, Currency.php),
  saleCount: 1,
);

void main() {
  test('untracked product is never counted out of stock', () {
    const untracked = StockedProduct(
      product: Product(
        id: 'u',
        name: 'Load',
        unit: ProductUnit.piece,
        price: Money(1000, Currency.php),
        cost: Money(800, Currency.php),
        tracksStock: false,
      ),
      stock: Quantity.zero,
    );
    final reply = productCountReply(products: [untracked], isFilipino: false);
    expect(reply.text, contains('0 out of stock'));
  });

  group('storeInfoReply', () {
    final products = [_product('a', 10, lowAt: 5), _product('b', 2, lowAt: 5)];

    test('English names store, product count and low count', () {
      final reply = storeInfoReply(
        storeName: 'Tindahan ni Aling Nena ñ',
        products: products,
        isFilipino: false,
      );
      expect(
        reply.text,
        'Your store is Tindahan ni Aling Nena ñ. You have 2 products, 1 low '
        'on stock.',
      );
      expect(reply.mood, TindaAvatarMood.thinking);
    });

    test('Filipino names store, product count and low count', () {
      final reply = storeInfoReply(
        storeName: 'Tindahan ni Aling Nena ñ',
        products: products,
        isFilipino: true,
      );
      expect(
        reply.text,
        'Ang tindahan mo ay Tindahan ni Aling Nena ñ. May 2 produkto ka, 1 '
        'ang paubos na.',
      );
    });

    test('trims surrounding whitespace of the name', () {
      final reply = storeInfoReply(
        storeName: '  Nena Store  ',
        products: [_product('a', 10, lowAt: 5)],
        isFilipino: false,
      );
      expect(
        reply.text,
        'Your store is Nena Store. You have 1 product, none low on stock.',
      );
      expect(reply.mood, TindaAvatarMood.talking);
    });

    test('empty name explains how to set it in both languages', () {
      final english = storeInfoReply(
        storeName: '',
        products: products,
        isFilipino: false,
      );
      expect(
        english.text,
        'Your store has no name yet. Set it in Settings > Store name. You '
        'have 2 products right now.',
      );
      final filipino = storeInfoReply(
        storeName: '',
        products: products,
        isFilipino: true,
      );
      expect(
        filipino.text,
        'Wala pang pangalan ang tindahan mo. Ilagay ito sa Settings > Store '
        'name. May 2 produkto ka ngayon.',
      );
    });

    test('whitespace-only name counts as blank', () {
      final reply = storeInfoReply(
        storeName: ' \t ',
        products: const [],
        isFilipino: false,
      );
      expect(
        reply.text,
        'Your store has no name yet. Set it in Settings > Store name. You '
        'have 0 products right now.',
      );
    });

    test('no products suggests Inventory in both languages', () {
      expect(
        storeInfoReply(
          storeName: 'Nena',
          products: const [],
          isFilipino: false,
        ).text,
        'Your store is Nena. You have no products yet, add some in '
        'Inventory > + Product.',
      );
      expect(
        storeInfoReply(
          storeName: 'Nena',
          products: const [],
          isFilipino: true,
        ).text,
        'Ang tindahan mo ay Nena. Wala ka pang produkto, idagdag sa '
        'Inventory > + Product.',
      );
    });

    test('Filipino with none low says no low stock', () {
      expect(
        storeInfoReply(
          storeName: 'Nena',
          products: [_product('a', 10, lowAt: 5)],
          isFilipino: true,
        ).text,
        'Ang tindahan mo ay Nena. May 1 produkto ka, wala pang paubos na '
        'stock.',
      );
    });
  });

  group('productCountReply', () {
    test('zero products suggests adding in both languages', () {
      expect(
        productCountReply(products: const [], isFilipino: false).text,
        'You have no products yet. Add your first one in '
        'Inventory > + Product.',
      );
      expect(
        productCountReply(products: const [], isFilipino: true).text,
        'Wala ka pang produkto. Idagdag ang una sa Inventory > + Product.',
      );
    });

    test('counts low and out of stock separately', () {
      final products = [
        _product('a', 20, lowAt: 5),
        _product('b', 3, lowAt: 5),
        _product('c', 0, lowAt: 5),
        _product('d', 0),
        _product('e', -2),
      ];
      expect(
        productCountReply(products: products, isFilipino: false).text,
        'You have 5 products in your store. 1 low on stock and 3 out of '
        'stock.',
      );
      expect(
        productCountReply(products: products, isFilipino: true).text,
        'May 5 produkto ka sa tindahan. 1 ang paubos na at 3 ang ubos na.',
      );
    });

    test('single product is singular in English', () {
      final reply = productCountReply(
        products: [_product('a', 10)],
        isFilipino: false,
      );
      expect(
        reply.text,
        'You have 1 product in your store. 0 low on stock and 0 out of '
        'stock.',
      );
      expect(reply.mood, TindaAvatarMood.talking);
    });

    test('all out of stock', () {
      final products = [_product('a', 0), _product('b', 0)];
      final reply = productCountReply(products: products, isFilipino: false);
      expect(
        reply.text,
        'You have 2 products in your store. 0 low on stock and 2 out of '
        'stock.',
      );
      expect(reply.mood, TindaAvatarMood.thinking);
    });
  });

  group('expensesReply', () {
    test('no expenses in both languages', () {
      final summary = _summary(50000, 30000);
      expect(
        expensesReply(
          expenses: const [],
          summary: summary,
          periodLabel: 'today',
          isFilipino: false,
        ).text,
        'No expenses today yet. Your profit is ₱200.00, with nothing '
        'deducted.',
      );
      expect(
        expensesReply(
          expenses: const [],
          summary: summary,
          periodLabel: 'ngayong araw',
          isFilipino: true,
        ).text,
        'Wala pang gastos ngayong araw. Tubo mo ay ₱200.00, wala pang bawas.',
      );
    });

    test('positive net income and biggest category in English', () {
      final reply = expensesReply(
        expenses: [
          _expense('1', 'Ice', 5000),
          _expense('2', 'Rent', 10000),
          _expense('3', 'ice', 2500),
        ],
        summary: _summary(50000, 30000),
        periodLabel: 'today',
        isFilipino: false,
      );
      expect(
        reply.text,
        'Expenses today: ₱175.00. Profit: ₱200.00. Your net income is '
        '₱25.00. Biggest: Rent (₱100.00).',
      );
      expect(reply.mood, TindaAvatarMood.talking);
    });

    test('same titles are merged case-insensitively and can win', () {
      final reply = expensesReply(
        expenses: [
          _expense('1', 'Ice', 6000),
          _expense('2', 'Rent', 10000),
          _expense('3', 'ice', 5000),
        ],
        summary: _summary(50000, 30000),
        periodLabel: 'today',
        isFilipino: false,
      );
      expect(reply.text, endsWith('Biggest: Ice (₱110.00).'));
    });

    test('Filipino positive net income', () {
      final reply = expensesReply(
        expenses: [_expense('1', 'Kuryente', 4000)],
        summary: _summary(50000, 30000),
        periodLabel: 'ngayong linggo',
        isFilipino: true,
      );
      expect(
        reply.text,
        'Gastos ngayong linggo: ₱40.00. Tubo: ₱200.00. Netong kita mo ay '
        '₱160.00. Pinakamalaking gastos: Kuryente (₱40.00).',
      );
    });

    test('loss is shown clearly in both languages', () {
      final expenses = [_expense('1', 'Rent', 30000)];
      final summary = _summary(50000, 30000);
      final english = expensesReply(
        expenses: expenses,
        summary: summary,
        periodLabel: 'today',
        isFilipino: false,
      );
      expect(
        english.text,
        'Expenses today: ₱300.00. Profit: ₱200.00. You are at a loss of '
        '₱100.00 (-₱100.00). Biggest: Rent (₱300.00).',
      );
      expect(english.mood, TindaAvatarMood.thinking);
      expect(
        expensesReply(
          expenses: expenses,
          summary: summary,
          periodLabel: 'ngayon',
          isFilipino: true,
        ).text,
        'Gastos ngayon: ₱300.00. Tubo: ₱200.00. Lugi ka ng ₱100.00 '
        '(-₱100.00). Pinakamalaking gastos: Rent (₱300.00).',
      );
    });

    test('exact break-even is net zero, not a loss', () {
      final reply = expensesReply(
        expenses: [_expense('1', 'Rent', 20000)],
        summary: _summary(50000, 30000),
        periodLabel: 'today',
        isFilipino: false,
      );
      expect(reply.text, contains('Your net income is ₱0.00.'));
    });

    test('blank titles skip the biggest part', () {
      final reply = expensesReply(
        expenses: [_expense('1', '   ', 1000)],
        summary: _summary(0, 0),
        periodLabel: 'today',
        isFilipino: false,
      );
      expect(
        reply.text,
        'Expenses today: ₱10.00. Profit: ₱0.00. You are at a loss of ₱10.00 '
        '(-₱10.00).',
      );
    });

    test('very large amounts do not break formatting', () {
      final reply = expensesReply(
        expenses: [_expense('1', 'Warehouse', 99999999900)],
        summary: _summary(100000000000, 0),
        periodLabel: 'this year',
        isFilipino: false,
      );
      expect(
        reply.text,
        'Expenses this year: ₱999999999.00. Profit: ₱1000000000.00. Your net '
        'income is ₱1.00. Biggest: Warehouse (₱999999999.00).',
      );
    });
  });
}
