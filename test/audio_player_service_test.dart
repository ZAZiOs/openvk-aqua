import 'package:flutter_test/flutter_test.dart';
import 'package:openvk_aqua/core/models/attachment.dart';
import 'package:openvk_aqua/core/models/media_response.dart';
import 'package:openvk_aqua/core/services/audio_player_service.dart';

void main() {
  group('MediaListResponse tests', () {
    test('parses v5.x format photos and audios', () {
      final jsonPhotos = {
        'count': 2,
        'items': [
          {'id': 1, 'owner_id': 10, 'photo_604': 'https://example.com/p1.jpg'},
          {'id': 2, 'owner_id': 10, 'photo_604': 'https://example.com/p2.jpg'},
        ],
      };

      final res = MediaListResponse<PhotoAttachment>.fromPhotos(jsonPhotos);
      expect(res.count, 2);
      expect(res.items.length, 2);
      expect(res.items[0].url, 'https://example.com/p1.jpg');
    });

    test('parses audio with cover art correctly', () {
      final jsonAudios = {
        'count': 1,
        'items': [
          {
            'id': 100,
            'owner_id': 20,
            'artist': 'DECO*27',
            'title': 'Monitoring',
            'duration': 181,
            'url': 'https://example.com/audio.mp3',
            'album': {
              'thumb': {
                'photo_300': 'https://example.com/cover300.jpg',
              },
            },
          },
        ],
      };

      final res = MediaListResponse<AudioAttachment>.fromAudios(jsonAudios);
      expect(res.count, 1);
      expect(res.items.length, 1);
      expect(res.items[0].coverUrl, 'https://example.com/cover300.jpg');
      expect(res.items[0].artist, 'DECO*27');
    });
  });

  group('RetroAudioPlayerService tests', () {
    test('initial state and repeat/shuffle toggles', () {
      final service = RetroAudioPlayerService.instance;
      expect(service.hasTrack, false);
      expect(service.isPlaying, false);
      expect(service.repeatMode, AudioRepeatMode.off);

      service.toggleRepeat();
      expect(service.repeatMode, AudioRepeatMode.all);

      service.toggleRepeat();
      expect(service.repeatMode, AudioRepeatMode.one);

      service.toggleRepeat();
      expect(service.repeatMode, AudioRepeatMode.off);

      expect(service.isShuffle, false);
      service.toggleShuffle();
      expect(service.isShuffle, true);
      service.toggleShuffle();
      expect(service.isShuffle, false);
    });
  });
}
