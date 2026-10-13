import '../utils/json_safe.dart';

class Group {
  final int id;
  final String name;
  final String screenName;
  final String photo50;
  final String photo100;
  final bool isClosed;

  const Group({
    required this.id,
    required this.name,
    required this.screenName,
    required this.photo50,
    required this.photo100,
    required this.isClosed,
  });

  String get avatarUrl => photo100.isNotEmpty ? photo100 : photo50;

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: JsonSafe.toInt(json['id']),
      name: JsonSafe.toStr(json['name'], 'Сообщество'),
      screenName: JsonSafe.toStr(json['screen_name']),
      photo50: JsonSafe.toStr(json['photo_50']),
      photo100: JsonSafe.toStr(json['photo_100']),
      isClosed: JsonSafe.toInt(json['is_closed']) != 0,
    );
  }

  factory Group.empty([int id = 0]) => Group(
    id: id,
    name: 'Сообщество',
    screenName: '',
    photo50: '',
    photo100: '',
    isClosed: false,
  );
}
