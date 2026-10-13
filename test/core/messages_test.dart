import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvk_flutter/core/api/messages_handler.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/cache/cache_policy.dart';

void main() {
  group('MessagesHandler', () {
    test('parses messages.getConversations extended response', () async {
      final mockJson = '''
      {
        "response": {
          "count": 1,
          "unread_count": 1,
          "items": [
            {
              "conversation": {
                "peer": {"id": 1, "type": "user", "local_id": 1},
                "in_read": 10,
                "out_read": 10,
                "unread_count": 1
              },
              "last_message": {
                "id": 15,
                "date": 1600000000,
                "peer_id": 1,
                "from_id": 1,
                "text": "Привет из OpenVK!",
                "out": 0,
                "conversation_message_id": 5
              }
            }
          ],
          "profiles": [
            {
              "id": 1,
              "first_name": "Павел",
              "last_name": "Дуров",
              "photo_50": "https://openvk.su/photo50.png",
              "photo_100": "https://openvk.su/photo100.png"
            }
          ]
        }
      }
      ''';

      final mockClient = MockClient((request) async {
        return http.Response(
          mockJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        httpClient: mockClient,
        enableLogging: false,
      );

      final handler = MessagesHandler(client);
      final response = await handler.getConversations(
        cachePolicy: CachePolicy.networkOnly,
      );

      expect(response.isSuccess, true);
      final data = response.dataOrNull!;
      expect(data.count, 1);
      expect(data.unreadCount, 1);
      expect(data.items.length, 1);

      final item = data.items.first;
      expect(item.lastMessage.text, 'Привет из OpenVK!');
      expect(data.getTitle(item), 'Павел Дуров');
      expect(data.getAvatarUrl(item), 'https://openvk.su/photo100.png');
    });

    test('parses messages.getHistory with attachments and reply', () async {
      final mockJson = '''
      {
        "response": {
          "count": 2,
          "items": [
            {
              "id": 100,
              "date": 1610000000,
              "peer_id": 1,
              "from_id": 2,
              "text": "Держи трек",
              "out": 1,
              "attachments": [
                {
                  "type": "audio",
                  "audio": {
                    "id": 456,
                    "owner_id": 2,
                    "artist": "Linkin Park",
                    "title": "Numb",
                    "duration": 185
                  }
                }
              ]
            }
          ]
        }
      }
      ''';

      final mockClient = MockClient((request) async {
        return http.Response(
          mockJson,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        httpClient: mockClient,
        enableLogging: false,
      );

      final handler = MessagesHandler(client);
      final response = await handler.getHistory(
        peerId: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      expect(response.isSuccess, true);
      final data = response.dataOrNull!;
      expect(data.items.length, 1);

      final msg = data.items.first;
      expect(msg.isOut, true);
      expect(msg.attachments.length, 1);
      expect(msg.attachments.first.audio?.artist, 'Linkin Park');
      expect(msg.previewText, 'Держи трек');
    });
  });
}
