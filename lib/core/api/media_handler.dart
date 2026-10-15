import '../cache/cache_policy.dart';
import '../models/attachment.dart';
import '../models/media_response.dart';
import 'api_response.dart';
import 'openvk_client.dart';

class MediaHandler {
  final OpenVkClient _client;

  MediaHandler(this._client);

  /// Fetch photos for user or group via [photos.getAll] (with fallback to [photos.get]).
  Future<ApiResponse<MediaListResponse<PhotoAttachment>>> getPhotos({
    int? ownerId,
    int count = 30,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0;
    final params = <String, dynamic>{
      'owner_id': ?ownerId,
      'count': count,
      'offset': offset,
      'extended': 1,
      'photo_sizes': 1,
    };

    final cacheKey = 'photos_${ownerId ?? 'my'}';

    ApiResponse<MediaListResponse<PhotoAttachment>> res;

    if (isFirstPage) {
      res = await _client.callCached<MediaListResponse<PhotoAttachment>>(
        'photos.getAll',
        cacheKey: cacheKey,
        cacheTag: 'media_photos',
        cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
        cacheTtl: const Duration(hours: 1),
        params: params,
        parser: (json) => MediaListResponse<PhotoAttachment>.fromPhotos(json),
        fallback: () => MediaListResponse<PhotoAttachment>.empty(),
      );
    } else {
      res = await _client.call<MediaListResponse<PhotoAttachment>>(
        'photos.getAll',
        params: params,
        parser: (json) => MediaListResponse<PhotoAttachment>.fromPhotos(json),
        fallback: () => MediaListResponse<PhotoAttachment>.empty(),
      );
    }

    // If photos.getAll failed or is empty on first page, try photos.get as fallback
    if (!res.isSuccess || (isFirstPage && (res.dataOrNull?.items.isEmpty ?? true))) {
      final fallbackRes = await _client.call<MediaListResponse<PhotoAttachment>>(
        'photos.get',
        params: {
          'owner_id': ?ownerId,
          'album_id': 'saved',
          'count': count,
          'offset': offset,
          'extended': 1,
          'photo_sizes': 1,
        },
        parser: (json) => MediaListResponse<PhotoAttachment>.fromPhotos(json),
        fallback: () => MediaListResponse<PhotoAttachment>.empty(),
      );
      if (fallbackRes.isSuccess && (fallbackRes.dataOrNull?.items.isNotEmpty ?? false)) {
        return fallbackRes;
      }
    }

    return res;
  }

  /// Fetch videos for user or group via [video.get].
  Future<ApiResponse<MediaListResponse<VideoAttachment>>> getVideos({
    int? ownerId,
    int count = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0;
    final params = <String, dynamic>{
      'owner_id': ?ownerId,
      'count': count,
      'offset': offset,
      'extended': 1,
    };

    final cacheKey = 'videos_${ownerId ?? 'my'}';

    if (isFirstPage) {
      return _client.callCached<MediaListResponse<VideoAttachment>>(
        'video.get',
        cacheKey: cacheKey,
        cacheTag: 'media_videos',
        cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
        cacheTtl: const Duration(hours: 1),
        params: params,
        parser: (json) => MediaListResponse<VideoAttachment>.fromVideos(json),
        fallback: () => MediaListResponse<VideoAttachment>.empty(),
      );
    }

    return _client.call<MediaListResponse<VideoAttachment>>(
      'video.get',
      params: params,
      parser: (json) => MediaListResponse<VideoAttachment>.fromVideos(json),
      fallback: () => MediaListResponse<VideoAttachment>.empty(),
    );
  }

  /// Fetch audio tracks for user or group via [audio.get].
  Future<ApiResponse<MediaListResponse<AudioAttachment>>> getAudios({
    int? ownerId,
    int count = 30,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = offset == 0;
    final params = <String, dynamic>{
      'owner_id': ?ownerId,
      'count': count,
      'offset': offset,
      'need_user': 1,
    };

    final cacheKey = 'audios_${ownerId ?? 'my'}';

    if (isFirstPage) {
      return _client.callCached<MediaListResponse<AudioAttachment>>(
        'audio.get',
        cacheKey: cacheKey,
        cacheTag: 'media_audios',
        cachePolicy: forceRefresh ? CachePolicy.networkOnly : CachePolicy.cacheFirst,
        cacheTtl: const Duration(hours: 1),
        params: params,
        parser: (json) => MediaListResponse<AudioAttachment>.fromAudios(json),
        fallback: () => MediaListResponse<AudioAttachment>.empty(),
      );
    }

    return _client.call<MediaListResponse<AudioAttachment>>(
      'audio.get',
      params: params,
      parser: (json) => MediaListResponse<AudioAttachment>.fromAudios(json),
      fallback: () => MediaListResponse<AudioAttachment>.empty(),
    );
  }
}
