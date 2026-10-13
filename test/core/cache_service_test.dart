import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvk_flutter/core/api/openvk_client.dart';
import 'package:openvk_flutter/core/cache/cache_policy.dart';
import 'package:openvk_flutter/core/cache/cache_service.dart';
import 'package:openvk_flutter/core/db/app_database.dart';
import 'package:openvk_flutter/core/utils/json_safe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late CacheService cache;

  setUp(() async {
    db = AppDatabase.instance;
    await db.init(inMemory: true);
    cache = CacheService(dbManager: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CacheService', () {
    test('put and get saves and retrieves JSON data', () async {
      await cache.put(
        key: 'profile_1',
        data: {'id': 1, 'first_name': 'Pavel', 'last_name': 'Durov'},
        instanceId: 'openvk.su',
      );

      final data = await cache.get(key: 'profile_1', instanceId: 'openvk.su');

      expect(data, isNotNull);
      expect(data['first_name'], 'Pavel');
      expect(data['id'], 1);
    });

    test('separates cache by instanceId (scoping)', () async {
      await cache.put(
        key: 'user_1',
        data: {'name': 'Instance One User'},
        instanceId: 'instance1.su',
      );

      await cache.put(
        key: 'user_1',
        data: {'name': 'Instance Two User'},
        instanceId: 'instance2.su',
      );

      final data1 = await cache.get(key: 'user_1', instanceId: 'instance1.su');
      final data2 = await cache.get(key: 'user_1', instanceId: 'instance2.su');

      expect(data1['name'], 'Instance One User');
      expect(data2['name'], 'Instance Two User');
    });

    test('respects TTL and expires old cache', () async {
      await cache.put(
        key: 'short_lived',
        data: {'temp': 'value'},
        instanceId: 'openvk.su',
        ttl: const Duration(milliseconds: -10),
      );

      final data = await cache.get(
        key: 'short_lived',
        instanceId: 'openvk.su',
        ignoreTtl: false,
      );

      expect(data, isNull);

      await cache.put(
        key: 'short_lived_2',
        data: {'temp': 'offline_value'},
        instanceId: 'openvk.su',
        ttl: const Duration(milliseconds: -10),
      );

      final offlineData = await cache.get(
        key: 'short_lived_2',
        instanceId: 'openvk.su',
        ignoreTtl: true,
      );

      expect(offlineData, isNotNull);
      expect(offlineData['temp'], 'offline_value');
    });

    test('invalidateByTag removes tagged entries', () async {
      await cache.put(
        key: 'feed_page_1',
        data: {
          'items': [1, 2],
        },
        instanceId: 'openvk.su',
        tag: 'newsfeed',
      );

      await cache.put(
        key: 'feed_page_2',
        data: {
          'items': [3, 4],
        },
        instanceId: 'openvk.su',
        tag: 'newsfeed',
      );

      await cache.put(
        key: 'settings',
        data: {'dark_mode': true},
        instanceId: 'openvk.su',
        tag: 'settings',
      );

      await cache.invalidateByTag(tag: 'newsfeed', instanceId: 'openvk.su');

      expect(
        await cache.get(key: 'feed_page_1', instanceId: 'openvk.su'),
        isNull,
      );
      expect(
        await cache.get(key: 'feed_page_2', instanceId: 'openvk.su'),
        isNull,
      );
      expect(
        await cache.get(key: 'settings', instanceId: 'openvk.su'),
        isNotNull,
      );
    });
  });

  group('OpenVkClient + CacheService integration', () {
    test(
      'networkFirst falls back to SQLite cache when network fails',
      () async {
        var shouldFail = false;

        final mockClient = MockClient((request) async {
          if (shouldFail) {
            return http.Response('Internal Error', 500);
          }
          return http.Response(
            '{"response": {"items": [{"id": 100, "text": "Cached post"}]}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = OpenVkClient(
          baseUrl: 'https://openvk.su',
          cacheService: cache,
          httpClient: mockClient,
          enableLogging: false,
        );

        final initialResponse = await client.callCached<String>(
          'wall.get',
          cachePolicy: CachePolicy.networkFirst,
          parser: (json) {
            final items = JsonSafe.toList(
              json['items'],
              (i) => JsonSafe.toStr(i['text']),
            );
            return items.first;
          },
        );

        expect(initialResponse.isSuccess, true);
        expect(initialResponse.dataOrNull, 'Cached post');

        shouldFail = true;

        final offlineResponse = await client.callCached<String>(
          'wall.get',
          cachePolicy: CachePolicy.networkFirst,
          parser: (json) {
            final items = JsonSafe.toList(
              json['items'],
              (i) => JsonSafe.toStr(i['text']),
            );
            return items.first;
          },
        );

        expect(offlineResponse.isSuccess, true);
        expect(offlineResponse.dataOrNull, 'Cached post');

        final success = offlineResponse.asSuccess;
        expect(success.isFromCache, true);
      },
    );
  });
}

extension on dynamic {
  dynamic get asSuccess => this;
}
