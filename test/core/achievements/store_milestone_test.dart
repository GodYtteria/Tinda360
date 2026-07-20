import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/achievements/store_milestone.dart';

void main() {
  group('computeStoreMilestones', () {
    test('returns all five milestones locked when counts are zero', () {
      final milestones = computeStoreMilestones(
        saleCount: 0,
        totalRevenueMinor: 0,
        productCount: 0,
      );

      expect(
        milestones.map((milestone) => milestone.id).toList(),
        <String>[
          'first_sale',
          'ten_sales',
          'sales_1000',
          'sales_5000',
          'catalog_10',
        ],
      );
      expect(
        milestones.map((milestone) => milestone.target).toList(),
        <int>[1, 10, 100000, 500000, 10],
      );
      for (final milestone in milestones) {
        expect(milestone.current, 0);
        expect(milestone.isUnlocked, isFalse);
        expect(milestone.titleEn, isNotEmpty);
        expect(milestone.titleFil, isNotEmpty);
      }
    });

    test('unlocks only reached milestones in partial progress state', () {
      final milestones = computeStoreMilestones(
        saleCount: 5,
        totalRevenueMinor: 150000,
        productCount: 4,
      );

      final byId = <String, StoreMilestone>{
        for (final milestone in milestones) milestone.id: milestone,
      };

      expect(byId['first_sale']!.isUnlocked, isTrue);
      expect(byId['first_sale']!.current, 5);

      expect(byId['ten_sales']!.isUnlocked, isFalse);
      expect(byId['ten_sales']!.current, 5);

      expect(byId['sales_1000']!.isUnlocked, isTrue);
      expect(byId['sales_1000']!.current, 150000);

      expect(byId['sales_5000']!.isUnlocked, isFalse);
      expect(byId['sales_5000']!.current, 150000);

      expect(byId['catalog_10']!.isUnlocked, isFalse);
      expect(byId['catalog_10']!.current, 4);
    });

    test('unlocks all milestones at exact targets and above', () {
      final exactMilestones = computeStoreMilestones(
        saleCount: 10,
        totalRevenueMinor: 500000,
        productCount: 10,
      );

      for (final milestone in exactMilestones) {
        expect(milestone.isUnlocked, isTrue);
      }

      final exceededMilestones = computeStoreMilestones(
        saleCount: 25,
        totalRevenueMinor: 750000,
        productCount: 18,
      );

      for (final milestone in exceededMilestones) {
        expect(milestone.isUnlocked, isTrue);
      }
    });

    test('clamps negative inputs to zero', () {
      final milestones = computeStoreMilestones(
        saleCount: -3,
        totalRevenueMinor: -1000,
        productCount: -2,
      );

      for (final milestone in milestones) {
        expect(milestone.current, 0);
        expect(milestone.isUnlocked, isFalse);
      }
    });
  });
}
