import '../utils/json_safe.dart';

class Attachment {
  final String type;
  final PhotoAttachment? photo;
  final AudioAttachment? audio;
  final VideoAttachment? video;
  final DocAttachment? doc;
  final StickerAttachment? sticker;
  final GiftAttachment? gift;

  const Attachment({
    required this.type,
    this.photo,
    this.audio,
    this.video,
    this.doc,
    this.sticker,
    this.gift,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final type = JsonSafe.toStr(json['type']);
    final map = JsonSafe.toMap(json[type]);

    return Attachment(
      type: type,
      photo: type == 'photo' ? PhotoAttachment.fromJson(map) : null,
      audio: type == 'audio' ? AudioAttachment.fromJson(map) : null,
      video: type == 'video' ? VideoAttachment.fromJson(map) : null,
      doc: type == 'doc' ? DocAttachment.fromJson(map) : null,
      sticker: type == 'sticker' ? StickerAttachment.fromJson(map) : null,
      gift: type == 'gift' ? GiftAttachment.fromJson(map) : null,
    );
  }

  String get summaryText {
    return switch (type) {
      'photo' => '[Фотография]',
      'audio' => '[Аудиозапись]',
      'video' => '[Видеозапись]',
      'doc' => '[Документ]',
      'sticker' => '[Стикер]',
      'gift' => '[Подарок]',
      'wall' => '[Запись на стене]',
      'link' => '[Ссылка]',
      _ => '[Вложение]',
    };
  }
}

class PhotoAttachment {
  final int id;
  final int ownerId;
  final String url;
  final int width;
  final int height;
  final String text;

  const PhotoAttachment({
    required this.id,
    required this.ownerId,
    required this.url,
    required this.width,
    required this.height,
    this.text = '',
  });

  factory PhotoAttachment.fromJson(Map<String, dynamic> json) {
    String bestUrl = '';
    int w = 0;
    int h = 0;

    final sizes = JsonSafe.toList(json['sizes'], (s) => JsonSafe.toMap(s));
    if (sizes.isNotEmpty) {
      for (final s in sizes) {
        final u = JsonSafe.toStr(s['url'] ?? s['src']);
        final sw = JsonSafe.toInt(s['width']);
        final sh = JsonSafe.toInt(s['height']);
        if (u.isNotEmpty && (bestUrl.isEmpty || (sw * sh) >= (w * h))) {
          bestUrl = u;
          w = sw;
          h = sh;
        }
      }
    }

    if (bestUrl.isEmpty) {
      for (final key in [
        'photo_2560',
        'photo_1280',
        'photo_807',
        'photo_604',
        'photo_320',
        'photo_130',
        'photo_75',
      ]) {
        final val = json[key];
        if (val is String && val.trim().isNotEmpty) {
          bestUrl = val.trim();
          break;
        }
      }
      w = JsonSafe.toInt(json['width']);
      h = JsonSafe.toInt(json['height']);
    }

    if (bestUrl.contains(r'\/')) {
      bestUrl = bestUrl.replaceAll(r'\/', '/');
    }
    if (bestUrl.startsWith('//')) {
      bestUrl = 'https:$bestUrl';
    }

    return PhotoAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      url: bestUrl,
      width: w,
      height: h,
      text: JsonSafe.toStr(json['text']),
    );
  }
}

class AudioAttachment {
  final int id;
  final int ownerId;
  final String artist;
  final String title;
  final int duration;
  final String url;

  const AudioAttachment({
    required this.id,
    required this.ownerId,
    required this.artist,
    required this.title,
    required this.duration,
    required this.url,
  });

  factory AudioAttachment.fromJson(Map<String, dynamic> json) {
    return AudioAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      artist: JsonSafe.toStr(json['artist'], 'Неизвестный исполнитель'),
      title: JsonSafe.toStr(json['title'], 'Без названия'),
      duration: JsonSafe.toInt(json['duration']),
      url: JsonSafe.toStr(json['url']),
    );
  }
}

class VideoAttachment {
  final int id;
  final int ownerId;
  final String title;
  final int duration;
  final String photoUrl;
  final String description;
  final String playerUrl;
  final String? directVideoUrl;

  const VideoAttachment({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.duration,
    required this.photoUrl,
    this.description = '',
    this.playerUrl = '',
    this.directVideoUrl,
  });

  factory VideoAttachment.fromJson(Map<String, dynamic> json) {
    String? direct;
    final files = json['files'];
    if (files is Map) {
      direct = JsonSafe.toStr(
        files['mp4_1080'] ??
            files['mp4_720'] ??
            files['mp4_480'] ??
            files['mp4_360'] ??
            files['mp4_240'] ??
            files['external'],
      );
      if (direct.isEmpty) direct = null;
    }

    final photoUrl = _extractBestVideoThumbnail(json);

    return VideoAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      title: JsonSafe.toStr(json['title'], 'Видеозапись'),
      duration: JsonSafe.toInt(json['duration']),
      photoUrl: photoUrl,
      description: JsonSafe.toStr(json['description']),
      playerUrl: JsonSafe.toStr(json['player']),
      directVideoUrl: direct,
    );
  }

  static String _extractBestVideoThumbnail(Map<String, dynamic> json) {
    // 1. Check array of sizes in 'image' (modern VK / OpenVK standard)
    final imageList = json['image'];
    if (imageList is List && imageList.isNotEmpty) {
      final best = _findBestSizeUrl(imageList);
      if (best.isNotEmpty) return _cleanUrl(best);
    } else if (imageList is String && imageList.trim().isNotEmpty) {
      return _cleanUrl(imageList.trim());
    }

    // 2. Check array of sizes in 'first_frame'
    final firstFrame = json['first_frame'];
    if (firstFrame is List && firstFrame.isNotEmpty) {
      final best = _findBestSizeUrl(firstFrame);
      if (best.isNotEmpty) return _cleanUrl(best);
    } else if (firstFrame is String && firstFrame.trim().isNotEmpty) {
      return _cleanUrl(firstFrame.trim());
    }

    // 3. Check array of sizes in 'sizes'
    final sizesList = json['sizes'];
    if (sizesList is List && sizesList.isNotEmpty) {
      final best = _findBestSizeUrl(sizesList);
      if (best.isNotEmpty) return _cleanUrl(best);
    }

    // 4. Check explicit photo and thumb keys in order of quality
    for (final key in [
      'photo_1280',
      'photo_800',
      'photo_640',
      'photo_320',
      'photo_160',
      'photo_130',
      'photo_75',
      'first_frame_1280',
      'first_frame_800',
      'first_frame_640',
      'first_frame_320',
      'first_frame_160',
      'first_frame_130',
      'thumb',
      'thumb_src',
      'thumb_256',
      'preview',
      'preview_url',
      'image_url',
    ]) {
      final val = json[key];
      if (val is String && val.trim().isNotEmpty) {
        return _cleanUrl(val.trim());
      }
    }

    return '';
  }

  static String _findBestSizeUrl(List list) {
    String candidate = '';
    int maxDimension = 0;

    for (final item in list) {
      if (item is Map) {
        final url = JsonSafe.toStr(item['url'] ?? item['src'] ?? item['link']);
        final w = JsonSafe.toInt(item['width']);
        final h = JsonSafe.toInt(item['height']);
        final dim = (w > h) ? w : h;
        if (url.isNotEmpty) {
          if (candidate.isEmpty || dim >= maxDimension) {
            candidate = url;
            maxDimension = dim;
          }
        }
      } else if (item is String && item.isNotEmpty) {
        candidate = item;
      }
    }

    return candidate;
  }

  static String _cleanUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.contains(r'\/')) {
      url = url.replaceAll(r'\/', '/');
    }
    if (url.startsWith('//')) {
      url = 'https:$url';
    }
    return url;
  }
}

class DocAttachment {
  final int id;
  final int ownerId;
  final String title;
  final int size;
  final String ext;
  final String url;

  const DocAttachment({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.size,
    required this.ext,
    required this.url,
  });

  factory DocAttachment.fromJson(Map<String, dynamic> json) {
    return DocAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      title: JsonSafe.toStr(json['title'], 'Документ'),
      size: JsonSafe.toInt(json['size']),
      ext: JsonSafe.toStr(json['ext']),
      url: JsonSafe.toStr(json['url']),
    );
  }
}

class StickerAttachment {
  final int stickerId;
  final int productId;
  final String animationUrl;
  final List<String> images;

  const StickerAttachment({
    required this.stickerId,
    required this.productId,
    required this.animationUrl,
    required this.images,
  });

  String get bestImage {
    if (images.isNotEmpty) return images.last;
    if (stickerId > 0) {
      return 'https://vk.com/sticker/1-$stickerId-256b.png';
    }
    return '';
  }

  factory StickerAttachment.fromJson(Map<String, dynamic> json) {
    final images = JsonSafe.toList(
      json['images'] ?? json['images_with_background'],
      (img) => JsonSafe.toStr(JsonSafe.toMap(img)['url']),
    );

    if (images.isEmpty) {
      for (final key in [
        'photo_512',
        'photo_352',
        'photo_256',
        'photo_128',
        'photo_64',
        'url'
      ]) {
        if (json.containsKey(key)) {
          final url = JsonSafe.toStr(json[key]);
          if (url.isNotEmpty) {
            images.add(url);
          }
        }
      }
    }

    final id = JsonSafe.toInt(json['sticker_id'] ?? json['id']);

    return StickerAttachment(
      stickerId: id,
      productId: JsonSafe.toInt(json['product_id']),
      animationUrl: JsonSafe.toStr(json['animation_url']),
      images: images,
    );
  }
}

class GiftAttachment {
  final int id;
  final String message;
  final int date;
  final int privacy;
  final int giftId;
  final int? stickersProductId;
  final String thumb256;
  final String thumb96;
  final String thumb48;

  const GiftAttachment({
    required this.id,
    this.message = '',
    this.date = 0,
    this.privacy = 0,
    required this.giftId,
    this.stickersProductId,
    required this.thumb256,
    required this.thumb96,
    required this.thumb48,
  });

  String get bestThumb {
    if (thumb256.isNotEmpty) return thumb256;
    if (thumb96.isNotEmpty) return thumb96;
    if (thumb48.isNotEmpty) return thumb48;
    return '';
  }

  factory GiftAttachment.fromJson(Map<String, dynamic> json) {
    final inner = json['gift'] is Map ? JsonSafe.toMap(json['gift']) : json;
    return GiftAttachment(
      id: JsonSafe.toInt(json['id']),
      message: JsonSafe.toStr(json['message']),
      date: JsonSafe.toInt(json['date']),
      privacy: JsonSafe.toInt(json['privacy']),
      giftId: JsonSafe.toInt(inner['id']),
      stickersProductId: inner['stickers_product_id'] != null
          ? JsonSafe.toInt(inner['stickers_product_id'])
          : null,
      thumb256: JsonSafe.toStr(inner['thumb_256'] ?? inner['thumb_512'] ?? inner['photo_256'] ?? inner['url']),
      thumb96: JsonSafe.toStr(inner['thumb_96'] ?? inner['photo_96']),
      thumb48: JsonSafe.toStr(inner['thumb_48'] ?? inner['photo_48']),
    );
  }
}
