import '../utils/json_safe.dart';
import 'group.dart';
import 'post.dart';
import 'user.dart';

class NewsfeedResponse {
  final List<Post> items;
  final List<User> profiles;
  final List<Group> groups;
  final String? nextFrom;

  const NewsfeedResponse({
    required this.items,
    this.profiles = const [],
    this.groups = const [],
    this.nextFrom,
  });

  factory NewsfeedResponse.fromJson(Map<String, dynamic> json) {
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

    final nextFrom = json['next_from']?.toString();

    return NewsfeedResponse(
      items: items,
      profiles: profiles,
      groups: groups,
      nextFrom: nextFrom,
    );
  }

  factory NewsfeedResponse.empty() => const NewsfeedResponse(items: []);
}
