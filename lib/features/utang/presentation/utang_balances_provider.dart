import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinda360/core/customers/customer_balance.dart';
import 'package:tinda360/data/data_providers.dart';

final utangBalancesProvider = StreamProvider.autoDispose<List<CustomerBalance>>(
  (ref) => ref.watch(customerRepositoryProvider).watchBalances(),
);
