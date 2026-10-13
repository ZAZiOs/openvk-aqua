import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_flutter/core/utils/json_safe.dart';

void main() {
  group('JsonSafe', () {
    test('toInt correctly parses various input types', () {
      expect(JsonSafe.toInt(10), 10);
      expect(JsonSafe.toInt(10.7), 10);
      expect(JsonSafe.toInt('42'), 42);
      expect(JsonSafe.toInt(' 100 '), 100);
      expect(JsonSafe.toInt('42.9'), 42);
      expect(JsonSafe.toInt(null), 0);
      expect(JsonSafe.toInt(null, -1), -1);
      expect(JsonSafe.toInt('invalid', 99), 99);
      expect(JsonSafe.toInt([]), 0);
      expect(JsonSafe.toInt({}), 0);
    });

    test('toBool handles bool, numbers, and strings', () {
      expect(JsonSafe.toBool(true), true);
      expect(JsonSafe.toBool(false), false);
      expect(JsonSafe.toBool(1), true);
      expect(JsonSafe.toBool(0), false);
      expect(JsonSafe.toBool('1'), true);
      expect(JsonSafe.toBool('0'), false);
      expect(JsonSafe.toBool('true'), true);
      expect(JsonSafe.toBool('false'), false);
      expect(JsonSafe.toBool('yes'), true);
      expect(JsonSafe.toBool('no'), false);
      expect(JsonSafe.toBool(null), false);
      expect(JsonSafe.toBool(null, true), true);
      expect(JsonSafe.toBool('other'), false);
    });

    test('toMap handles Map and handles PHP empty array [] without crash', () {
      expect(JsonSafe.toMap({'a': 1}), {'a': 1});
      expect(JsonSafe.toMap([]), isEmpty);
      expect(JsonSafe.toMap(null), isEmpty);
      expect(JsonSafe.toMap('not a map'), isEmpty);
    });

    test('toList isolates errors and successfully parses valid items', () {
      final rawList = [
        {'id': 1, 'name': 'First'},
        'broken_item_not_map',
        {'id': 2, 'name': 'Second'},
      ];

      final result = JsonSafe.toList(rawList, (item) {
        if (item is! Map) throw Exception('Item must be map');
        return item['name'] as String;
      });

      expect(result, ['First', 'Second']);
    });
  });
}
