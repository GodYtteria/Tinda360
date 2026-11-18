import 'package:tinda360/data/db/id_generator.dart';

final class SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'id-${(++_next).toString().padLeft(6, '0')}';
}
