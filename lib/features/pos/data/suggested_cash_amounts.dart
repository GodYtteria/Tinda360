const List<int> roundCashDenominationsPesos = [50, 100, 200, 500, 1000, 2000];

const int maxSuggestedCashAmounts = 5;

const int roundAmountsAboveTotal = 3;

List<int> suggestedCashAmounts(int totalMinorUnits) {
  final suggestions = <int>[];
  if (totalMinorUnits > 0 && totalMinorUnits % 100 == 0) {
    suggestions.add(totalMinorUnits ~/ 100);
  }
  var added = 0;
  for (final denominationPesos in roundCashDenominationsPesos) {
    if (added == roundAmountsAboveTotal) break;
    if (denominationPesos * 100 > totalMinorUnits &&
        !suggestions.contains(denominationPesos)) {
      suggestions.add(denominationPesos);
      added++;
    }
  }
  return suggestions.take(maxSuggestedCashAmounts).toList();
}
