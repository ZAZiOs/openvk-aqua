import '../utils/json_safe.dart';

class Attachment {
  final String type;
  final PhotoAttachment? photo;
  final AudioAttachment? audio;
  final VideoAttachment? video;
  final DocAttachment? doc;
  final StickerAttachment? sticker;

  const Attachment({
    required this.type,
    this.photo,
    this.audio,
    this.video,
    this.doc,
    this.sticker,
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
    );
  }

  String get summaryText {
    return switch (type) {
      'photo' => '[Фотография]',
      'audio' => '[Аудиозапись]',
      'video' => '[Видеозапись]',
      'doc' => '[Документ]',
      'sticker' => '[Стикер]',
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

  const PhotoAttachment({
    required this.id,
    required this.ownerId,
    required this.url,
    required this.width,
    required this.height,
  });

  factory PhotoAttachment.fromJson(Map<String, dynamic> json) {
    String bestUrl = '';
    int w = 0;
    int h = 0;

    final sizes = JsonSafe.toList(json['sizes'], (s) => JsonSafe.toMap(s));
    if (sizes.isNotEmpty) {
      final bestSize = sizes.last;
      bestUrl = JsonSafe.toStr(bestSize['url']);
      w = JsonSafe.toInt(bestSize['width']);
      h = JsonSafe.toInt(bestSize['height']);
    } else {
      bestUrl = JsonSafe.toStr(
        json['photo_604'] ?? json['photo_130'] ?? json['photo_75'],
      );
      w = JsonSafe.toInt(json['width']);
      h = JsonSafe.toInt(json['height']);
    }

    return PhotoAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      url: bestUrl,
      width: w,
      height: h,
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

  const VideoAttachment({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.duration,
    required this.photoUrl,
  });

  factory VideoAttachment.fromJson(Map<String, dynamic> json) {
    return VideoAttachment(
      id: JsonSafe.toInt(json['id']),
      ownerId: JsonSafe.toInt(json['owner_id']),
      title: JsonSafe.toStr(json['title'], 'Видеозапись'),
      duration: JsonSafe.toInt(json['duration']),
      photoUrl: JsonSafe.toStr(json['photo_320'] ?? json['photo_130']),
    );
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
