import 'package:flutter_test/flutter_test.dart';
import 'package:tinda360/core/failures/store_failure.dart';
import 'package:tinda360/core/result.dart';

import '../../support/test_repositories.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  tearDown(() => repos.close());

  test('contact is stored trimmed and read back', () async {
    final result = await repos.store.updateContact(
      address: '  12 Rizal St  ',
      phone: ' 0917 ',
    );
    expect(result, isA<Ok<void, StoreFailure>>());
    final profile = await repos.store.watch().first;
    expect(profile.address, '12 Rizal St');
    expect(profile.phone, '0917');
  });

  test('blank values clear the contact', () async {
    final first = await repos.store.updateContact(address: 'x', phone: '1');
    expect(first, isA<Ok<void, StoreFailure>>());
    final second = await repos.store.updateContact(address: '  ');
    expect(second, isA<Ok<void, StoreFailure>>());
    final profile = await repos.store.watch().first;
    expect(profile.address, isNull);
    expect(profile.phone, isNull);
  });
}
