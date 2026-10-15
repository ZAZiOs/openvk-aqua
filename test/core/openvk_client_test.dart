import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvk_aqua/core/api/api_response.dart';
import 'package:openvk_aqua/core/api/openvk_client.dart';
import 'package:openvk_aqua/core/utils/json_safe.dart';

void main() {
  group('OpenVkClient', () {
    test('successfully parses valid response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"response": {"count": 10, "items": [{"id": 1}]}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        httpClient: mockClient,
        enableLogging: false,
      );

      final response = await client.call(
        'wall.get',
        parser: (json) {
          final map = JsonSafe.toMap(json);
          return JsonSafe.toInt(map['count']);
        },
      );

      expect(response.isSuccess, true);
      expect(response.dataOrNull, 10);
    });

    test('handles OpenVK API error (e.g. code 5: unauthorized)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"error": {"error_code": 5, "error_msg": "User authorization failed: invalid access_token"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenVkClient(
        baseUrl: 'https://openvk.su',
        httpClient: mockClient,
        enableLogging: false,
      );

      final response = await client.call<int>(
        'wall.get',
        parser: (json) => 42,
        fallback: () => 0,
      );

      expect(response.isFailure, true);
      expect(response.errorOrNull?.kind, ApiErrorKind.unauthorized);
      expect(response.errorOrNull?.code, 5);

      expect(response.getOrElse(-1), 0);
    });

    test(
      'handles HTML error page gracefully without throwing format exception',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '<html><body>502 Bad Gateway</body></html>',
            502,
            headers: {'content-type': 'text/html'},
          );
        });

        final client = OpenVkClient(
          baseUrl: 'https://openvk.su',
          httpClient: mockClient,
          enableLogging: false,
        );

        final response = await client.call<String>(
          'newsfeed.get',
          parser: (json) => 'data',
          fallback: () => 'fallback',
        );

        expect(response.isFailure, true);
        expect(response.errorOrNull?.kind, ApiErrorKind.server);
        expect(response.getOrElse('default'), 'fallback');
      },
    );
  });
}
