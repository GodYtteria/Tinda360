import 'package:tinda360/core/catalog/stocked_product.dart';

List<StockedProduct> sortProductsByPopularity(
  List<StockedProduct> products,
  Map<String, int> unitsSoldMilliByProductId,
) {
  final sorted = List<StockedProduct>.of(products);
  sorted.sort((left, right) {
    final leftSold = unitsSoldMilliByProductId[left.product.id] ?? 0;
    final rightSold = unitsSoldMilliByProductId[right.product.id] ?? 0;
    if (leftSold != rightSold) return rightSold.compareTo(leftSold);
    final byName = left.product.name.toLowerCase().compareTo(
      right.product.name.toLowerCase(),
    );
    if (byName != 0) return byName;
    return left.product.id.compareTo(right.product.id);
  });
  return sorted;
}
