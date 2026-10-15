import '../models/attachment.dart';
import '../utils/json_safe.dart';

class MediaListResponse<T> {
  final int count;
  final List<T> items;

  const MediaListResponse({
    required this.count,
    required this.items,
  });

  factory MediaListResponse.empty() => MediaListResponse<T>(count: 0, items: <T>[]);

  static (int, List<dynamic>) _extractListAndCount(dynamic raw) {
    if (raw == null) return (0, <dynamic>[]);

    if (raw is Map) {
      final inner = raw['response'] ?? raw;
      if (inner is Map) {
        final count = JsonSafe.toInt(inner['count']);
        final items = inner['items'] is List ? (inner['items'] as List) : <dynamic>[];
        return (count > 0 ? count : items.length, items);
      } else if (inner is List) {
        raw = inner;
      }
    }

    if (raw is List) {
      if (raw.isNotEmpty && raw.first is num) {
        final count = (raw.first as num).toInt();
        final items = raw.sublist(1);
        return (count, items);
      } else {
        return (raw.length, raw);
      }
    }

    return (0, <dynamic>[]);
  }

  factory MediaListResponse.fromPhotos(dynamic raw) {
    final (count, rawItems) = _extractListAndCount(raw);
    final list = <PhotoAttachment>[];

    for (final item in rawItems) {
      if (item is Map) {
        list.add(PhotoAttachment.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return MediaListResponse<T>(
      count: count > 0 ? count : list.length,
      items: list as List<T>,
    );
  }

  factory MediaListResponse.fromVideos(dynamic raw) {
    final (count, rawItems) = _extractListAndCount(raw);
    final list = <VideoAttachment>[];

    for (final item in rawItems) {
      if (item is Map) {
        list.add(VideoAttachment.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return MediaListResponse<T>(
      count: count > 0 ? count : list.length,
      items: list as List<T>,
    );
  }

  factory MediaListResponse.fromAudios(dynamic raw) {
    final (count, rawItems) = _extractListAndCount(raw);
    final list = <AudioAttachment>[];

    for (final item in rawItems) {
      if (item is Map) {
        list.add(AudioAttachment.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    return MediaListResponse<T>(
      count: count > 0 ? count : list.length,
      items: list as List<T>,
    );
  }
}
