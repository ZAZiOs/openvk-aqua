import '../utils/json_safe.dart';
import 'group.dart';
import 'post_comment.dart';
import 'user.dart';

class WallCommentsResponse {
  final int count;
  final List<PostComment> items;
  final List<User> profiles;
  final List<Group> groups;
  final bool canPost;

  const WallCommentsResponse({
    required this.count,
    required this.items,
    this.profiles = const [],
    this.groups = const [],
    this.canPost = true,
  });

  factory WallCommentsResponse.fromJson(Map<String, dynamic> json) {
    final count = JsonSafe.toInt(json['count']);
    final canPost = json.containsKey('can_post')
        ? JsonSafe.toBool(json['can_post'], true)
        : true;

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
      (item) => PostComment.fromJson(
        JsonSafe.toMap(item),
        usersMap: usersMap,
        groupsMap: groupsMap,
      ),
    );

    return WallCommentsResponse(
      count: count,
      items: items,
      profiles: profiles,
      groups: groups,
      canPost: canPost,
    );
  }

  factory WallCommentsResponse.empty() =>
      const WallCommentsResponse(count: 0, items: []);
}
