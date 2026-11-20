import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/features/chat/data/entity_resolver.dart';

const String productArgumentName = 'product_name';

Map<String, dynamic>? groundProductArgument(
  Map<String, dynamic> modelArguments,
  String question,
  List<StockedProduct> products,
) {
  if (!modelArguments.containsKey(productArgumentName)) return modelArguments;
  final resolution = const EntityResolver().resolveProduct(question, products);
  if (resolution.kind == ResolutionKind.none) return null;
  return <String, dynamic>{
    ...modelArguments,
    productArgumentName: resolution.mention,
  };
}
