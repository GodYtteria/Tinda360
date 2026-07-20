import 'package:tinda360/data/db/id_generator.dart';

/// Predictable ids: id-1, id-2, ...
final class SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'id-${++_next}';
}
