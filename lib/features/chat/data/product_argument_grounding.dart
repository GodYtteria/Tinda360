import 'package:tinda360/core/catalog/stocked_product.dart';
import 'package:tinda360/features/chat/data/entity_resolver.dart';

const String productArgumentName = 'product_name';

const Set<String> appFilledArgumentNames = <String>{
  productArgumentName,
  'customer_name',
};

const Set<String> productToolNames = <String>{
  'get_product_info',
  'get_stock_forecast',
};

bool needsProductGrounding(String toolName, Map<String, dynamic> arguments) =>
    arguments.containsKey(productArgumentName) ||
    productToolNames.contains(toolName);

Map<String, dynamic>? groundProductArgument(
  String toolName,
  Map<String, dynamic> modelArguments,
  String question,
  List<StockedProduct> products,
) {
  if (!needsProductGrounding(toolName, modelArguments)) return modelArguments;
  final resolution = const EntityResolver().resolveProduct(question, products);
  if (resolution.kind != ResolutionKind.single) return null;
  return <String, dynamic>{
    ...modelArguments,
    productArgumentName: resolution.mention,
  };
}
