final class StoreMilestone {
  const new({
    required this.id,
    required this.titleEn,
    required this.titleFil,
    required this.current,
    required this.target,
    required this.isUnlocked,
  });

  final String id;

  final String titleEn;

  final String titleFil;

  final int current;

  final int target;

  final bool isUnlocked;
}

List<StoreMilestone> computeStoreMilestones({
  required int saleCount,
  required int totalRevenueMinor,
  required int productCount,
}) {
  final normalizedSaleCount = saleCount < 0 ? 0 : saleCount;
  final normalizedRevenueMinor = totalRevenueMinor < 0 ? 0 : totalRevenueMinor;
  final normalizedProductCount = productCount < 0 ? 0 : productCount;

  return <StoreMilestone>[
    StoreMilestone(
      id: 'first_sale',
      titleEn: 'First Sale',
      titleFil: 'Unang Benta',
      current: normalizedSaleCount,
      target: 1,
      isUnlocked: normalizedSaleCount >= 1,
    ),
    StoreMilestone(
      id: 'ten_sales',
      titleEn: '10 Sales',
      titleFil: '10 Benta',
      current: normalizedSaleCount,
      target: 10,
      isUnlocked: normalizedSaleCount >= 10,
    ),
    StoreMilestone(
      id: 'sales_1000',
      titleEn: '₱1,000 in Sales',
      titleFil: '₱1,000 na Benta',
      current: normalizedRevenueMinor,
      target: 100000,
      isUnlocked: normalizedRevenueMinor >= 100000,
    ),
    StoreMilestone(
      id: 'sales_5000',
      titleEn: '₱5,000 in Sales',
      titleFil: '₱5,000 na Benta',
      current: normalizedRevenueMinor,
      target: 500000,
      isUnlocked: normalizedRevenueMinor >= 500000,
    ),
    StoreMilestone(
      id: 'catalog_10',
      titleEn: '10 Products Listed',
      titleFil: '10 Paninda',
      current: normalizedProductCount,
      target: 10,
      isUnlocked: normalizedProductCount >= 10,
    ),
  ];
}
