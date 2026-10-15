import '../utils/json_safe.dart';

class UserCounters {
  final int friends;
  final int groups;
  final int followers;
  final int photos;
  final int videos;
  final int audios;

  const UserCounters({
    this.friends = 0,
    this.groups = 0,
    this.followers = 0,
    this.photos = 0,
    this.videos = 0,
    this.audios = 0,
  });

  factory UserCounters.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserCounters();
    return UserCounters(
      friends: JsonSafe.toInt(json['friends']),
      groups: JsonSafe.toInt(json['groups'] ?? json['pages']),
      followers: JsonSafe.toInt(json['followers'] ?? json['subscriptions']),
      photos: JsonSafe.toInt(json['photos']),
      videos: JsonSafe.toInt(json['videos']),
      audios: JsonSafe.toInt(json['audios']),
    );
  }
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String photo50;
  final String photo100;
  final bool isOnline;
  final bool isGroup;
  final int sex;
  final int? customGenderType;

  // Extended profile fields
  final String nickname;
  final String screenName;
  final String status;
  final String bdate;
  final String city;
  final String homeTown;
  final String relation;
  final String registrationDate;
  final String political;
  final String pronouns;
  final String telegram;
  final String site;
  final String interests;
  final String music;
  final String tv;
  final String quotes;
  final String about;
  final UserCounters counters;
  final int? friendStatus;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.photo50,
    required this.photo100,
    required this.isOnline,
    this.isGroup = false,
    this.sex = 0,
    this.customGenderType,
    this.nickname = '',
    this.screenName = '',
    this.status = '',
    this.bdate = '',
    this.city = '',
    this.homeTown = '',
    this.relation = '',
    this.registrationDate = '',
    this.political = '',
    this.pronouns = '',
    this.telegram = '',
    this.site = '',
    this.interests = '',
    this.music = '',
    this.tv = '',
    this.quotes = '',
    this.about = '',
    this.counters = const UserCounters(),
    this.friendStatus,
  });

  int get genderType {
    if (customGenderType != null) return customGenderType!;
    return resolveGenderType(sex: sex, pronouns: pronouns);
  }

  static int resolveGenderType({int? sex, String? pronouns}) {
    if (pronouns != null && pronouns.isNotEmpty) {
      final p = pronouns.trim().toLowerCase();
      if (p == '1' || p.contains('она') || p.contains('she')) return 1;
      if (p == '0' || p.contains('они') || p.contains('they')) return 0;
      if (p == '2' || p.contains('он') || p.contains('he')) return 2;
      final parsed = int.tryParse(p);
      if (parsed != null && parsed >= 0 && parsed <= 2) return parsed;
    }

    if (sex != null) {
      if (sex == 2) return 2; // OpenVK / VK API: 2 - мужской
      if (sex == 1) return 1; // OpenVK / VK API: 1 - женский
      if (sex == 0) return 0; // OpenVK / VK API: 0 - неизвестен
    }

    return 0; // Default: 0 - неизвестен
  }

  String get fullName => '$firstName $lastName'.trim();

  String get displayNameWithNickname {
    if (nickname.isNotEmpty) {
      return '$firstName ($nickname) $lastName'.trim();
    }
    return fullName;
  }

  String get avatarUrl => photo100.isNotEmpty ? photo100 : photo50;

  factory User.fromJson(Map<String, dynamic> json) {
    final id = JsonSafe.toInt(json['id'] ?? json['uid']);

    final isGroup = id < 0 || json.containsKey('name');

    if (isGroup) {
      final name = JsonSafe.toStr(json['name'], 'Сообщество');
      return User(
        id: id < 0 ? id : -id,
        firstName: name,
        lastName: '',
        photo50: JsonSafe.toStr(
          json['photo_50'] ?? json['photo_rec'] ?? json['photo'],
        ),
        photo100: JsonSafe.toStr(
          json['photo_100'] ?? json['photo_medium_rec'] ?? json['photo_medium'],
        ),
        isOnline: false,
        isGroup: true,
        status: JsonSafe.toStr(json['status'] ?? json['activity']),
        about: JsonSafe.toStr(json['description'] ?? json['about']),
        site: JsonSafe.toStr(json['site']),
        counters: UserCounters.fromJson(
          json['counters'] is Map<String, dynamic> ? json['counters'] : null,
        ),
      );
    }

    // Parse relation
    String relationStr = '';
    final relRaw = json['relation'];
    if (relRaw != null) {
      final partnerMap = json['relation_partner'] is Map ? json['relation_partner'] : null;
      final partnerName = partnerMap != null
          ? '${partnerMap['first_name'] ?? ''} ${partnerMap['last_name'] ?? ''}'.trim()
          : '';
      final relInt = int.tryParse(relRaw.toString());
      if (relInt != null) {
        relationStr = _parseRelation(relInt, partnerName);
      } else {
        relationStr = relRaw.toString();
      }
    }

    // Parse political
    String politicalStr = '';
    final personal = json['personal'] is Map ? json['personal'] : null;
    final polRaw = personal != null ? personal['political'] : json['political'];
    if (polRaw != null) {
      final polInt = int.tryParse(polRaw.toString());
      politicalStr = polInt != null ? _parsePolitical(polInt) : polRaw.toString();
    }

    // City
    String cityStr = '';
    if (json['city'] is Map) {
      cityStr = JsonSafe.toStr(json['city']['title']);
    } else if (json['city'] != null) {
      cityStr = JsonSafe.toStr(json['city']);
    }

    // Telegram
    String tg = JsonSafe.toStr(
      json['telegram'] ??
      (json['connections'] is Map ? json['connections']['telegram'] : null) ??
      (personal != null ? personal['telegram'] : null),
    );

    // Pronouns & Gender
    final Map<String, dynamic>? personalMap = json['personal'] is Map
        ? Map<String, dynamic>.from(json['personal'] as Map)
        : null;
    final dynamic rawPronouns = json['pronouns'] ??
        json['pronoun'] ??
        json['personal_pronouns'] ??
        (personalMap != null
            ? (personalMap['pronouns'] ?? personalMap['pronoun'] ?? personalMap['personal_pronouns'])
            : null);
    final String pronounsStr = JsonSafe.toStr(rawPronouns);
    final dynamic rawSex = json['sex'] ?? json['gender'] ?? json['gender_type'];
    final int? sexInt = rawSex != null ? JsonSafe.toInt(rawSex, 0) : null;

    int? resolvedGender;
    if (rawPronouns != null && pronounsStr.isNotEmpty) {
      final pStr = pronounsStr.trim().toLowerCase();
      if (pStr == '1' || pStr.contains('она') || pStr.contains('she')) {
        resolvedGender = 1;
      } else if (pStr == '0' || pStr.contains('они') || pStr.contains('they')) {
        resolvedGender = 0;
      } else if (pStr == '2' || pStr.contains('он') || pStr.contains('he')) {
        resolvedGender = 2;
      }
    }
    if (resolvedGender == null && rawSex != null) {
      final s = JsonSafe.toInt(rawSex, 0);
      if (s == 2) {
        resolvedGender = 2;
      } else if (s == 1) {
        resolvedGender = 1;
      } else if (s == 0) {
        resolvedGender = 0;
      }
    }

    // Registration date
    String regDateStr = JsonSafe.toStr(
      json['registration_date'] ?? json['reg_date'] ?? json['created_at'],
    );

    return User(
      id: id,
      firstName: JsonSafe.toStr(json['first_name'], 'Пользователь'),
      lastName: JsonSafe.toStr(json['last_name']),
      photo50: JsonSafe.toStr(
        json['photo_50'] ?? json['photo_rec'] ?? json['photo'],
      ),
      photo100: JsonSafe.toStr(
        json['photo_100'] ?? json['photo_medium_rec'] ?? json['photo_medium'] ?? json['photo_max'],
      ),
      isOnline: JsonSafe.toBool(json['online']),
      isGroup: false,
      sex: sexInt ?? 0,
      customGenderType: resolvedGender,
      nickname: JsonSafe.toStr(json['nickname']),
      screenName: JsonSafe.toStr(json['screen_name'] ?? json['domain']),
      status: JsonSafe.toStr(json['status'] ?? json['activity']),
      bdate: JsonSafe.toStr(json['bdate']),
      city: cityStr,
      homeTown: JsonSafe.toStr(json['home_town']),
      relation: relationStr,
      registrationDate: regDateStr,
      political: politicalStr,
      pronouns: pronounsStr,
      telegram: tg,
      site: JsonSafe.toStr(json['site']),
      interests: JsonSafe.toStr(json['interests']),
      music: JsonSafe.toStr(json['music']),
      tv: JsonSafe.toStr(json['tv']),
      quotes: JsonSafe.toStr(json['quotes']),
      about: JsonSafe.toStr(json['about']),
      counters: UserCounters.fromJson(
        json['counters'] is Map<String, dynamic> ? json['counters'] : null,
      ),
      friendStatus: json.containsKey('friend_status')
          ? JsonSafe.toInt(json['friend_status'])
          : null,
    );
  }

  static String _parseRelation(int code, String partner) {
    switch (code) {
      case 1:
        return 'Не женат / Не замужем';
      case 2:
        return partner.isNotEmpty ? 'Встречается с $partner' : 'Есть друг / подруга';
      case 3:
        return partner.isNotEmpty ? 'Помолвлен(а) с $partner' : 'Помолвлен / Помолвлена';
      case 4:
        return partner.isNotEmpty ? 'В браке с $partner' : 'Женат / Замужем';
      case 5:
        return 'Всё сложно';
      case 6:
        return 'В активном поиске';
      case 7:
        return partner.isNotEmpty ? 'Влюблен(а) в $partner' : 'Влюблен / Влюблена';
      case 8:
        return partner.isNotEmpty ? 'В гражданском браке с $partner' : 'В гражданском браке';
      default:
        return '';
    }
  }

  static String _parsePolitical(int code) {
    switch (code) {
      case 1:
        return 'Коммунистические';
      case 2:
        return 'Социалистические';
      case 3:
        return 'Умеренные';
      case 4:
        return 'Либеральные';
      case 5:
        return 'Консервативные';
      case 6:
        return 'Монархические';
      case 7:
        return 'Ультраконсервативные';
      case 8:
        return 'Индифферентные';
      case 9:
        return 'Либертарианские';
      default:
        return '';
    }
  }

  factory User.empty([int id = 0]) => User(
    id: id,
    firstName: 'Пользователь',
    lastName: '',
    photo50: '',
    photo100: '',
    isOnline: false,
  );
}
