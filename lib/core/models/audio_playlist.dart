import '../utils/json_safe.dart';

class AudioPlaylist {
  final int id;
  final int ownerId;
  final String title;
  final String description;
  final int size;
  final int length;
  final int created;
  final int? modified;
  final bool accessible;
  final bool editable;
  final bool bookmarked;
  final int listens;
  final String? coverUrl;
  final bool searchable;

  const AudioPlaylist({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.size = 0,
    this.length = 0,
    this.created = 0,
    this.modified,
    this.accessible = true,
    this.editable = false,
    this.bookmarked = false,
    this.listens = 0,
    this.coverUrl,
    this.searchable = true,
  });

  factory AudioPlaylist.fromJson(Map<String, dynamic> json) {
    String? cover;
    final rawCover = JsonSafe.toStr(json['cover_url']);
    if (rawCover.isNotEmpty) {
      cover = rawCover;
    } else {
      final thumb = json['thumb'];
      if (thumb is Map) {
        cover = JsonSafe.toStr(
          thumb['photo_600'] ??
              thumb['photo_300'] ??
              thumb['photo_1200'] ??
              thumb['photo_68'] ??
              thumb['url'] ??
              thumb['src'],
        );
      } else if (thumb is String && thumb.isNotEmpty) {
        cover = thumb;
      }
    }

    if (cover != null) {
      if (cover.contains(r'\/')) {
        cover = cover.replaceAll(r'\/', '/');
      }
      if (cover.trim().isEmpty) {
        cover = null;
      }
    }

    return AudioPlaylist(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      title: JsonSafe.toStr(json['title'], 'Без названия'),
      description: JsonSafe.toStr(json['description']),
      size: JsonSafe.toInt(json['size'] ?? json['count']),
      length: JsonSafe.toInt(json['length'] ?? json['duration']),
      created: JsonSafe.toInt(json['created']),
      modified: json['modified'] != null ? JsonSafe.toInt(json['modified']) : null,
      accessible: JsonSafe.toBool(json['accessible'], true),
      editable: JsonSafe.toBool(json['editable'], false),
      bookmarked: JsonSafe.toBool(json['bookmarked'], false),
      listens: JsonSafe.toInt(json['listens'] ?? json['plays']),
      coverUrl: cover,
      searchable: JsonSafe.toBool(json['searchable'], true),
    );
  }

  String? getFullCoverUrl(String baseUrl) {
    if (coverUrl == null || coverUrl!.trim().isEmpty) return null;
    final c = coverUrl!.trim();
    if (c.startsWith('http://') || c.startsWith('https://')) return c;
    if (c.startsWith('//')) return 'https:$c';
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = c.startsWith('/') ? c : '/$c';
    return '$cleanBase$cleanPath';
  }
}
