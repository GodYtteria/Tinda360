import 'package:uuid/uuid.dart';

/// Creates stable row identifiers.
abstract interface class IdGenerator {
  /// A new unique identifier.
  String next();
}

/// Time-ordered UUID v7 identifiers.
final class UuidIdGenerator implements IdGenerator {
  /// Creates the generator.
  UuidIdGenerator();

  final Uuid _uuid = const Uuid();

  @override
  String next() => _uuid.v7();
}
