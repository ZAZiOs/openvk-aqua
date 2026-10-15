import 'dart:convert';

/// Represents a notification across all platforms (Android, iOS, Windows).
class AppNotification {
  final int id;
  final String title;
  final String body;
  final String? payload;
  final int? peerId;
  final int? messageId;
  final Map<String, dynamic>? extra;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
    this.peerId,
    this.messageId,
    this.extra,
  });

  /// Serializes to a JSON payload string if none provided.
  String get effectivePayload {
    if (payload != null && payload!.isNotEmpty) {
      return payload!;
    }
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      if (peerId != null) 'peer_id': peerId,
      if (messageId != null) 'message_id': messageId,
      ...?extra,
    };
    return jsonEncode(map);
  }

  static AppNotification? fromPayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return AppNotification(
        id: map['id'] is int ? map['id'] as int : 0,
        title: map['title']?.toString() ?? '',
        body: map['body']?.toString() ?? '',
        payload: raw,
        peerId: map['peer_id'] is int ? map['peer_id'] as int : null,
        messageId: map['message_id'] is int ? map['message_id'] as int : null,
        extra: map,
      );
    } catch (_) {
      return null;
    }
  }
}
