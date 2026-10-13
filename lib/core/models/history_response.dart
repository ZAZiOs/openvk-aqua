import '../utils/json_safe.dart';
import 'group.dart';
import 'message.dart';
import 'user.dart';

class HistoryResponse {
  final int count;
  final List<Message> items;
  final Map<int, User> profiles;
  final Map<int, Group> groups;

  const HistoryResponse({
    required this.count,
    required this.items,
    required this.profiles,
    required this.groups,
  });

  User? getUser(int id) => profiles[id];
  Group? getGroup(int id) => groups[id.abs()];

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawProfiles = JsonSafe.toList(
      json['profiles'],
      (p) => User.fromJson(JsonSafe.toMap(p)),
    );
    final profilesMap = {for (var u in rawProfiles) u.id: u};

    final rawGroups = JsonSafe.toList(
      json['groups'],
      (g) => Group.fromJson(JsonSafe.toMap(g)),
    );
    final groupsMap = {for (var g in rawGroups) g.id: g};

    final items = JsonSafe.toList(
      json['items'],
      (i) => Message.fromJson(JsonSafe.toMap(i)),
    );

    return HistoryResponse(
      count: JsonSafe.toInt(json['count']),
      items: items,
      profiles: profilesMap,
      groups: groupsMap,
    );
  }

  factory HistoryResponse.empty() =>
      const HistoryResponse(count: 0, items: [], profiles: {}, groups: {});
}
