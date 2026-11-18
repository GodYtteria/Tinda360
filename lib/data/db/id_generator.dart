import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String next();
}

final class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator();

  final Uuid _uuid = const Uuid();

  @override
  String next() => _uuid.v7();
}
