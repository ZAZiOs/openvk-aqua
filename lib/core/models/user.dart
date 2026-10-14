import '../utils/json_safe.dart';

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String photo50;
  final String photo100;
  final bool isOnline;
  final bool isGroup;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.photo50,
    required this.photo100,
    required this.isOnline,
    this.isGroup = false,
  });

  String get fullName => '$firstName $lastName'.trim();

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
      );
    }

    return User(
      id: id,
      firstName: JsonSafe.toStr(json['first_name'], 'Пользователь'),
      lastName: JsonSafe.toStr(json['last_name']),
      photo50: JsonSafe.toStr(
        json['photo_50'] ?? json['photo_rec'] ?? json['photo'],
      ),
      photo100: JsonSafe.toStr(
        json['photo_100'] ?? json['photo_medium_rec'] ?? json['photo_medium'],
      ),
      isOnline: JsonSafe.toBool(json['online']),
      isGroup: false,
    );
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
