import 'package:tinda360/core/catalog/quantity.dart';
import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/core/expenses/expense_entry.dart';
import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/sales_summary.dart';
import 'package:tinda360/shared/widgets/formatters.dart';
import 'package:tinda360/shared/widgets/tinda_ai_avatar.dart';

final class StoreReplyText {
  const new({required this.text, required this.mood});

  final String text;

  final TindaAvatarMood mood;
}

bool _isOutOfStock(StockedProduct product) =>
    product.product.tracksStock && product.stock.compareTo(Quantity.zero) <= 0;

int _countOutOfStock(List<StockedProduct> products) =>
    products.where(_isOutOfStock).length;

int _countLowOnStock(List<StockedProduct> products) => products
    .where((product) => product.isLowOnStock && !_isOutOfStock(product))
    .length;

String _productCountPhrase(int count, bool isFilipino) {
  if (isFilipino) return '$count produkto';
  return count == 1 ? '1 product' : '$count products';
}

StoreReplyText storeInfoReply({
  required String storeName,
  required List<StockedProduct> products,
  required bool isFilipino,
}) {
  final trimmedName = storeName.trim();
  final lowCount = _countLowOnStock(products);
  final countPhrase = _productCountPhrase(products.length, isFilipino);
  final String text;
  if (trimmedName.isEmpty) {
    text = isFilipino
        ? 'Wala pang pangalan ang tindahan mo. Ilagay ito sa Settings > '
              'Store name. May $countPhrase ka ngayon.'
        : 'Your store has no name yet. Set it in Settings > Store name. '
              'You have $countPhrase right now.';
  } else if (products.isEmpty) {
    text = isFilipino
        ? 'Ang tindahan mo ay $trimmedName. Wala ka pang produkto, idagdag '
              'sa Inventory > + Product.'
        : 'Your store is $trimmedName. You have no products yet, add some in '
              'Inventory > + Product.';
  } else if (lowCount == 0) {
    text = isFilipino
        ? 'Ang tindahan mo ay $trimmedName. May $countPhrase ka, wala pang '
              'paubos na stock.'
        : 'Your store is $trimmedName. You have $countPhrase, none low on '
              'stock.';
  } else {
    text = isFilipino
        ? 'Ang tindahan mo ay $trimmedName. May $countPhrase ka, $lowCount '
              'ang paubos na.'
        : 'Your store is $trimmedName. You have $countPhrase, $lowCount low '
              'on stock.';
  }
  return StoreReplyText(
    text: text,
    mood: trimmedName.isEmpty || lowCount > 0
        ? TindaAvatarMood.thinking
        : TindaAvatarMood.talking,
  );
}

StoreReplyText productCountReply({
  required List<StockedProduct> products,
  required bool isFilipino,
}) {
  if (products.isEmpty) {
    return StoreReplyText(
      text: isFilipino
          ? 'Wala ka pang produkto. Idagdag ang una sa Inventory > + Product.'
          : 'You have no products yet. Add your first one in '
                'Inventory > + Product.',
      mood: TindaAvatarMood.thinking,
    );
  }
  final lowCount = _countLowOnStock(products);
  final outCount = _countOutOfStock(products);
  final countPhrase = _productCountPhrase(products.length, isFilipino);
  final text = isFilipino
      ? 'May $countPhrase ka sa tindahan. $lowCount ang paubos na at '
            '$outCount ang ubos na.'
      : 'You have $countPhrase in your store. $lowCount low on stock and '
            '$outCount out of stock.';
  return StoreReplyText(
    text: text,
    mood: lowCount + outCount > 0
        ? TindaAvatarMood.thinking
        : TindaAvatarMood.talking,
  );
}

StoreReplyText expensesReply({
  required List<ExpenseEntry> expenses,
  required SalesSummary summary,
  required String periodLabel,
  required bool isFilipino,
}) {
  final currency = summary.revenue.currency;
  final grossProfit = summary.profit;
  if (expenses.isEmpty) {
    final profitText = formatMoney(grossProfit);
    return StoreReplyText(
      text: isFilipino
          ? 'Wala pang gastos $periodLabel. Tubo mo ay $profitText, wala pang '
                'bawas.'
          : 'No expenses $periodLabel yet. Your profit is $profitText, with '
                'nothing deducted.',
      mood: TindaAvatarMood.talking,
    );
  }
  var totalExpenses = Money.zero(currency);
  final totalsByTitle = <String, Money>{};
  for (final expense in expenses) {
    totalExpenses = totalExpenses + expense.amount;
    final title = expense.title.trim();
    final key = title.toLowerCase();
    totalsByTitle[key] =
        (totalsByTitle[key] ?? Money.zero(currency)) + expense.amount;
  }
  final netIncome = grossProfit - totalExpenses;
  final biggestKey = totalsByTitle.keys.reduce(
    (best, key) => totalsByTitle[key]! > totalsByTitle[best]! ? key : best,
  );
  final biggestTitle = expenses
      .firstWhere((expense) => expense.title.trim().toLowerCase() == biggestKey)
      .title
      .trim();
  final biggestAmount = formatMoney(totalsByTitle[biggestKey]!);
  final expensesText = formatMoney(totalExpenses);
  final profitText = formatMoney(grossProfit);
  final netText = formatMoney(netIncome);
  final biggestText = biggestTitle.isEmpty
      ? ''
      : (isFilipino
            ? ' Pinakamalaking gastos: $biggestTitle ($biggestAmount).'
            : ' Biggest: $biggestTitle ($biggestAmount).');
  final String resultText;
  if (netIncome.isNegative) {
    resultText = isFilipino
        ? 'Lugi ka ng ${formatMoney(Money(-netIncome.minorUnits, currency))} '
              '($netText).'
        : 'You are at a loss of '
              '${formatMoney(Money(-netIncome.minorUnits, currency))} '
              '($netText).';
  } else {
    resultText = isFilipino
        ? 'Netong kita mo ay $netText.'
        : 'Your net income is $netText.';
  }
  final text = isFilipino
      ? 'Gastos $periodLabel: $expensesText. Tubo: $profitText. '
            '$resultText$biggestText'
      : 'Expenses $periodLabel: $expensesText. Profit: $profitText. '
            '$resultText$biggestText';
  return StoreReplyText(
    text: text,
    mood: netIncome.isNegative
        ? TindaAvatarMood.thinking
        : TindaAvatarMood.talking,
  );
}
