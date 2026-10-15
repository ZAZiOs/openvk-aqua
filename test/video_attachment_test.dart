import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/models/attachment.dart';

void main() {
  group('VideoAttachment.fromJson thumbnail parsing tests', () {
    test('Parses modern VK/OpenVK image array of sizes', () {
      final json = {
        'id': 1234,
        'owner_id': 5,
        'title': 'хл2 дисковый билд',
        'duration': 43,
        'image': [
          {'url': 'https://ovk.to/thumb_130.jpg', 'width': 130, 'height': 96},
          {'url': 'https://ovk.to/thumb_320.jpg', 'width': 320, 'height': 240},
          {'url': 'https://ovk.to/thumb_800.jpg', 'width': 800, 'height': 600},
        ],
      };

      final video = VideoAttachment.fromJson(json);

      expect(video.id, 1234);
      expect(video.title, 'хл2 дисковый билд');
      // Should pick the highest resolution size
      expect(video.photoUrl, 'https://ovk.to/thumb_800.jpg');
    });

    test('Parses first_frame array of sizes', () {
      final json = {
        'id': 5678,
        'owner_id': 1,
        'title': 'Видео без image, но с first_frame',
        'duration': 60,
        'first_frame': [
          {'url': 'https://ovk.to/frame_130.jpg', 'width': 130, 'height': 96},
          {'url': 'https://ovk.to/frame_640.jpg', 'width': 640, 'height': 480},
        ],
      };

      final video = VideoAttachment.fromJson(json);

      expect(video.photoUrl, 'https://ovk.to/frame_640.jpg');
    });

    test('Parses photo_800 / photo_1280 and cleans escaped slashes', () {
      final json = {
        'id': 9999,
        'owner_id': 10,
        'title': 'Видео с экранированными слэшами',
        'duration': 120,
        'photo_800': r'https:\/\/ovk.za.net\/upload\/video_thumb.jpg',
      };

      final video = VideoAttachment.fromJson(json);

      expect(video.photoUrl, 'https://ovk.za.net/upload/video_thumb.jpg');
    });

    test('Parses thumb or thumb_src when present', () {
      final json = {
        'id': 8888,
        'owner_id': 20,
        'title': 'Видео с thumb',
        'duration': 30,
        'thumb': 'https://ovk.to/preview.png',
      };

      final video = VideoAttachment.fromJson(json);

      expect(video.photoUrl, 'https://ovk.to/preview.png');
    });

    test('Parses protocol-relative URL', () {
      final json = {
        'id': 7777,
        'owner_id': 30,
        'title': 'Видео с protocol-relative url',
        'duration': 15,
        'image': '//cdn.ovk.to/preview.jpg',
      };

      final video = VideoAttachment.fromJson(json);

      expect(video.photoUrl, 'https://cdn.ovk.to/preview.jpg');
    });
  });
}
