final class ClarificationOption {
  const new({required this.toolName, required this.label});

  final String toolName;

  final String label;
}

const String _englishPrompt = 'Which one did you mean?';
const String _filipinoPrompt = 'Alin po dito ang ibig ninyong sabihin?';

const Map<String, ({String english, String filipino})> _labelsByToolName =
    <String, ({String english, String filipino})>{
      'get_sales_summary': (
        english: 'Sales summary',
        filipino: 'Buod ng benta',
      ),
      'get_top_products': (
        english: 'Best-selling products',
        filipino: 'Mga pinakamabentang paninda',
      ),
      'get_product_info': (
        english: 'Product price and stock',
        filipino: 'Presyo at stock ng produkto',
      ),
      'get_low_stock': (
        english: 'Low stock items',
        filipino: 'Mga paubos na stock',
      ),
      'get_stock_forecast': (
        english: 'Stock running-out forecast',
        filipino: 'Forecast ng mauubos na stock',
      ),
      'get_utang_list': (
        english: 'Who owes utang',
        filipino: 'Listahan ng may utang',
      ),
      'get_utang_risk': (
        english: 'Overdue utang',
        filipino: 'Mga overdue na utang',
      ),
      'get_expenses': (english: 'Expenses', filipino: 'Mga gastos'),
      'get_expiry_alerts': (
        english: 'Items about to expire',
        filipino: 'Mga malapit nang mag-expire',
      ),
      'get_slow_moving': (
        english: "Items that aren't selling",
        filipino: 'Mga matumal na paninda',
      ),
      'get_profit_margins': (
        english: 'Profit margins',
        filipino: 'Tubo sa bawat produkto',
      ),
      'get_sales_compare': (
        english: 'Compare sales periods',
        filipino: 'Paghambing ng benta',
      ),
      'get_sales_trend': (
        english: 'Sales trend',
        filipino: 'Takbo ng benta',
      ),
      'get_busiest_hours': (
        english: 'Busiest hours',
        filipino: 'Pinaka-busy na oras',
      ),
      'get_suki_loyalty': (
        english: 'Top suki customers',
        filipino: 'Mga top suki',
      ),
      'get_payment_breakdown': (
        english: 'Payment methods breakdown',
        filipino: 'Hati ng paraan ng bayad',
      ),
      'get_store_info': (
        english: 'Store info',
        filipino: 'Impormasyon ng tindahan',
      ),
      'get_product_count': (
        english: 'Number of products',
        filipino: 'Bilang ng paninda',
      ),
      'get_restock_suggestions': (
        english: 'What to restock',
        filipino: 'Dapat i-restock',
      ),
      'get_overview': (
        english: 'Store overview',
        filipino: 'Pangkalahatang takbo ng tindahan',
      ),
    };

String clarificationPrompt({required bool isFilipino}) {
  return isFilipino ? _filipinoPrompt : _englishPrompt;
}

String? clarificationLabel(String toolName, {required bool isFilipino}) {
  final labels = _labelsByToolName[toolName];
  if (labels == null) {
    return null;
  }
  return isFilipino ? labels.filipino : labels.english;
}

List<ClarificationOption> buildClarificationOptions(
  List<String> toolNames, {
  required bool isFilipino,
}) {
  final seenToolNames = <String>{};
  final options = <ClarificationOption>[];
  for (final toolName in toolNames) {
    final label = clarificationLabel(toolName, isFilipino: isFilipino);
    if (label == null || !seenToolNames.add(toolName)) {
      continue;
    }
    options.add(ClarificationOption(toolName: toolName, label: label));
  }
  return options;
}
