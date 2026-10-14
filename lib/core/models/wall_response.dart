import '../utils/json_safe.dart';
import 'group.dart';
import 'post.dart';
import 'user.dart';

class WallResponse {
  final int count;
  final List<Post> items;
  final List<User> profiles;
  final List<Group> groups;

  const WallResponse({
    required this.count,
    required this.items,
    this.profiles = const [],
    this.groups = const [],
  });

  factory WallResponse.fromJson(Map<String, dynamic> json) {
    // VK / OpenVK wall.get returns:
    // { count: N, items: [...], profiles: [...], groups: [...] }
    final count = JsonSafe.toInt(json['count']);

    final profiles = JsonSafe.toList(
      json['profiles'],
      (p) => User.fromJson(JsonSafe.toMap(p)),
    );

    final groups = JsonSafe.toList(
      json['groups'],
      (g) => Group.fromJson(JsonSafe.toMap(g)),
    );

    final usersMap = {for (final u in profiles) u.id: u};
    final groupsMap = {for (final g in groups) g.id: g};

    final items = JsonSafe.toList(
      json['items'],
      (item) => Post.fromJson(
        JsonSafe.toMap(item),
        usersMap: usersMap,
        groupsMap: groupsMap,
      ),
    );

    return WallResponse(
      count: count,
      items: items,
      profiles: profiles,
      groups: groups,
    );
  }

  factory WallResponse.empty() => const WallResponse(count: 0, items: []);
}
