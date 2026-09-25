import 'package:uuid/uuid.dart';

abstract final class IdService {
  static const _uuid = Uuid();
  static String newId() => _uuid.v4();
}
