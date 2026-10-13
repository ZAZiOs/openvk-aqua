import 'package:flutter/foundation.dart';

class JsonSafe {
  const JsonSafe._();

  static int toInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      return int.tryParse(trimmed) ??
          double.tryParse(trimmed)?.toInt() ??
          fallback;
    }
    return fallback;
  }

  static int? toNullableInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final trimmed = val.trim();
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  static double toDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.trim()) ?? fallback;
    }
    return fallback;
  }

  static String toStr(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    if (val is String) return val;
    return val.toString();
  }

  static String? toNullableStr(dynamic val, {bool nullIfEmpty = false}) {
    if (val == null) return null;
    final str = val.toString();
    if (nullIfEmpty && str.trim().isEmpty) return null;
    return str;
  }

  static bool toBool(dynamic val, [bool fallback = false]) {
    if (val == null) return fallback;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) {
      final lower = val.trim().toLowerCase();
      if (lower == '1' || lower == 'true' || lower == 'yes') return true;
      if (lower == '0' || lower == 'false' || lower == 'no') return false;
    }
    return fallback;
  }

  static Map<String, dynamic> toMap(dynamic val) {
    if (val == null) return <String, dynamic>{};
    if (val is Map<String, dynamic>) return val;
    if (val is Map) {
      return val.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static List<T> toList<T>(
    dynamic val,
    T Function(dynamic item) mapper, {
    void Function(dynamic item, Object error, StackTrace stack)? onError,
  }) {
    if (val == null || val is! List) return <T>[];
    final result = <T>[];
    for (final item in val) {
      try {
        result.add(mapper(item));
      } catch (e, stack) {
        if (onError != null) {
          onError(item, e, stack);
        } else {
          debugPrint('[JsonSafe.toList] Ошибка парсинга элемента: $e');
        }
      }
    }
    return result;
  }

  static List<String> toStringList(dynamic val) {
    return toList<String>(val, (item) => toStr(item));
  }

  static List<int> toIntList(dynamic val) {
    return toList<int>(val, (item) => toInt(item));
  }
}
