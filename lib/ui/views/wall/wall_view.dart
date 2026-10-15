import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/api/wall_handler.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user.dart';
import '../../../core/utils/json_safe.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_avatar.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_ios6_dialog.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import '../messages/chat_conversation_view.dart';
import 'widgets/dotted_leader_row.dart';
import 'widgets/wall_counters_grid.dart';
import 'widgets/wall_post_card.dart';
import '../media/media_view.dart';

class WallView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final int? ownerId;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenEditProfile;

  const WallView({
    super.key,
    required this.client,
    required this.account,
    this.ownerId,
    this.onOpenSettings,
    this.onOpenEditProfile,
  });

  @override
  State<WallView> createState() => _WallViewState();
}

class _WallViewState extends State<WallView>
    with SingleTickerProviderStateMixin {
  late final WallHandler _wallHandler;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _postTextController = TextEditingController();
  late final AnimationController _infoAnimController;
  late final Animation<double> _infoHeightFactor;

  User? _user;
  bool _isLoadingProfile = true;
  String? _profileErrorMessage;

  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  // Filter: 'all' (Все записи), 'owner' (Мои записи)
  String _currentFilter = 'all';
  bool _isInfoExpanded = false;
  bool _isSendingPost = false;
  int? _friendStatus; // 0: not friend, 1: request sent, 2: incoming request, 3: friends
  bool _isFriendActionLoading = false;
  bool? _isGroupMember;
  bool _isGroupActionLoading = false;

  int get _targetId => widget.ownerId ?? widget.account.userId;
  bool get _isMyWall => _targetId == widget.account.userId;
  bool get _isGroupWall => _targetId < 0 || (_user?.isGroup == true);

  bool _hasProfileData(User u) {
    if (u.isGroup || u.id < 0) return true;
    return u.counters.friends > 0 ||
        u.counters.followers > 0 ||
        u.counters.groups > 0 ||
        u.counters.photos > 0 ||
        u.counters.audios > 0 ||
        u.counters.videos > 0 ||
        u.status.isNotEmpty ||
        u.city.isNotEmpty ||
        u.homeTown.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _wallHandler = WallHandler(widget.client);
    _scrollController.addListener(_onScroll);

    _infoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _infoHeightFactor = CurvedAnimation(
      parent: _infoAnimController,
      curve: Curves.fastOutSlowIn,
    );

    // Initial check in local memory cache: only use if counters or extended profile is present
    final cached = widget.client.userCache.getUser(_targetId, autoFetch: false);
    if (cached != null && _hasProfileData(cached)) {
      _user = cached;
      _isLoadingProfile = false;
      if (cached.friendStatus != null) {
        _friendStatus = cached.friendStatus;
      }
      if (cached.isGroup) {
        _isGroupMember = cached.isMember;
      }
    }

    _loadUserProfile();
    _loadPosts(refresh: true);
    if (_targetId < 0) {
      _checkGroupMembership();
    } else if (!_isMyWall && _targetId > 0) {
      _checkFriendStatus();
    }
  }

  @override
  void dispose() {
    _infoAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _postTextController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 300) {
      _loadMorePosts();
    }
  }

  Future<void> _loadUserProfile({bool forceRefresh = false}) async {
    final res = await _wallHandler.getProfile(_targetId, forceRefresh: forceRefresh);
    if (!mounted) return;
    if (res.isSuccess && res.dataOrNull != null) {
      setState(() {
        _user = res.dataOrNull;
        _isLoadingProfile = false;
        _profileErrorMessage = null;
        if (_user?.friendStatus != null) {
          _friendStatus = _user!.friendStatus;
        }
        if (_user?.isGroup == true) {
          _isGroupMember = _user!.isMember;
        }
      });
      if (_isGroupWall) {
        if (_isGroupMember == null) _checkGroupMembership();
      } else if (!_isMyWall && _targetId > 0 && _friendStatus == null) {
        _checkFriendStatus();
      }
      // If profile was loaded from cache, silently fetch fresh data from network in background
      if (res.isFromCache && !forceRefresh) {
        unawaited(_wallHandler.getProfile(_targetId, forceRefresh: true).then((netRes) {
          if (mounted && netRes.isSuccess && netRes.dataOrNull != null) {
            setState(() {
              _user = netRes.dataOrNull;
              if (_user?.friendStatus != null) {
                _friendStatus = _user!.friendStatus;
              }
              if (_user?.isGroup == true) {
                _isGroupMember = _user!.isMember;
              }
            });
            if (_isGroupWall) {
              if (_isGroupMember == null) _checkGroupMembership();
            } else if (!_isMyWall && _targetId > 0 && _friendStatus == null) {
              _checkFriendStatus();
            }
          }
        }));
      }
    } else {
      if (_user == null) {
        setState(() {
          _isLoadingProfile = false;
          _profileErrorMessage = res.errorOrNull?.message ?? 'Не удалось загрузить данные страницы';
        });
      }
    }
  }

  Future<void> _loadPosts({bool refresh = false, bool forceRefresh = false}) async {
    if (refresh && _posts.isEmpty) {
      setState(() {
        _isLoadingPosts = true;
        _hasMore = true;
      });
    }

    final offset = refresh ? 0 : _posts.length;
    final res = await _wallHandler.getWall(
      ownerId: _targetId,
      offset: offset,
      count: 20,
      filter: _currentFilter,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final wallData = res.dataOrNull!;
      setState(() {
        if (refresh) {
          _posts = wallData.items;
        } else {
          _posts.addAll(wallData.items);
        }
        _totalCount = wallData.count;
        _hasMore = _posts.length < _totalCount;
        _isLoadingPosts = false;
        _isLoadingMore = false;
      });

      // If first page came from cache, silently fetch fresh data from network in background
      if (refresh && res.isFromCache && !forceRefresh) {
        unawaited(_wallHandler.getWall(
          ownerId: _targetId,
          offset: 0,
          count: 20,
          filter: _currentFilter,
          forceRefresh: true,
        ).then((netRes) {
          if (mounted && netRes.isSuccess && netRes.dataOrNull != null) {
            final freshData = netRes.dataOrNull!;
            setState(() {
              _posts = freshData.items;
              _totalCount = freshData.count;
              _hasMore = _posts.length < _totalCount;
            });
          }
        }));
      }
    } else {
      setState(() {
        _isLoadingPosts = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _isLoadingPosts) return;
    setState(() => _isLoadingMore = true);
    await _loadPosts(refresh: false);
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadUserProfile(forceRefresh: true),
      _loadPosts(refresh: true, forceRefresh: true),
      if (_isGroupWall)
        _checkGroupMembership()
      else if (!_isMyWall && _targetId > 0)
        _checkFriendStatus(),
    ]);
  }

  Future<void> _submitPost() async {
    final text = _postTextController.text.trim();
    if (text.isEmpty || _isSendingPost) return;

    setState(() => _isSendingPost = true);

    final res = await _wallHandler.postToWall(
      ownerId: _targetId,
      message: text,
    );

    if (!mounted) return;
    setState(() => _isSendingPost = false);

    if (res.isSuccess) {
      _postTextController.clear();
      FocusScope.of(context).unfocus();
      // Reload posts to fetch the newly created post
      await _loadPosts(refresh: true, forceRefresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorOrNull?.message ?? 'Ошибка публикации записи'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _handleToggleLike(Post post) async {
    final isLiked = post.userLikes;
    final newCount = isLiked ? (post.likesCount - 1).clamp(0, 999999) : post.likesCount + 1;

    // Optimistic UI update
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _posts[idx] = post.copyWith(
          userLikes: !isLiked,
          likesCount: newCount,
        );
      }
    });

    final res = await _wallHandler.toggleLike(
      ownerId: post.ownerId,
      postId: post.id,
      isCurrentlyLiked: isLiked,
    );

    if (!mounted) return;
    if (res.isSuccess && res.dataOrNull != null) {
      setState(() {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = _posts[idx].copyWith(likesCount: res.dataOrNull);
        }
      });
    }
  }

  Future<void> _handleDeletePost(Post post) async {
    final confirm = await showIos6ConfirmDialog(
      context: context,
      title: 'Удаление записи',
      message: 'Вы действительно хотите удалить эту запись со стены?',
      cancelText: 'Отмена',
      confirmText: 'Удалить',
      isDestructive: true,
    );

    if (confirm != true) return;

    final res = await _wallHandler.deletePost(
      ownerId: post.ownerId,
      postId: post.id,
    );

    if (!mounted) return;
    if (res.isSuccess) {
      setState(() {
        _posts.removeWhere((p) => p.id == post.id);
        _totalCount = (_totalCount - 1).clamp(0, 999999);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorOrNull?.message ?? 'Не удалось удалить запись'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _onFilterChanged(String filter) {
    if (_currentFilter == filter) return;
    setState(() {
      _currentFilter = filter;
      _posts = [];
    });
    _loadPosts(refresh: true);
  }

  Future<void> _checkGroupMembership() async {
    if (!_isGroupWall) return;
    try {
      final res = await widget.client.call<dynamic>(
        'groups.isMember',
        params: {
          'group_id': _targetId.abs().toString(),
          'user_id': widget.account.userId.toString(),
        },
        parser: (json) => json,
      );
      if (!mounted) return;
      if (res.isSuccess && res.dataOrNull != null) {
        final val = JsonSafe.toInt(res.dataOrNull);
        setState(() => _isGroupMember = val == 1);
      }
    } catch (e) {
      debugPrint('[WallView] groups.isMember error: $e');
    }
  }

  Future<void> _handleGroupMembershipPressed() async {
    if (_isGroupActionLoading) return;

    final isMember = _isGroupMember ?? false;

    // If currently member: confirmation dialog to leave
    if (isMember) {
      final isPage = _user?.groupType == 'page';
      final groupName = _user?.firstName.isNotEmpty == true ? _user!.firstName : 'сообщество';
      final confirmed = await showIos6ConfirmDialog(
        context: context,
        title: isPage ? 'Отписка от страницы' : 'Выход из группы',
        message: isPage
            ? 'Вы действительно хотите отписаться от сообщества «$groupName»?'
            : 'Вы действительно хотите покинуть сообщество «$groupName»?',
        cancelText: 'Отмена',
        confirmText: isPage ? 'Отписаться' : 'Покинуть',
        isDestructive: true,
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isGroupActionLoading = true);
      try {
        final res = await widget.client.call<dynamic>(
          'groups.leave',
          params: {'group_id': _targetId.abs().toString()},
          parser: (json) => json,
        );
        if (!mounted) return;
        if (res.isSuccess) {
          setState(() {
            _isGroupMember = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы покинули сообщество'),
              backgroundColor: Color(0xFF2E3E50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorOrNull?.message ?? 'Не удалось покинуть сообщество'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isGroupActionLoading = false);
        }
      }
      return;
    }

    // If not member: join group
    setState(() => _isGroupActionLoading = true);
    try {
      final res = await widget.client.call<dynamic>(
        'groups.join',
        params: {'group_id': _targetId.abs().toString()},
        parser: (json) => json,
      );
      if (!mounted) return;
      if (res.isSuccess) {
        setState(() {
          _isGroupMember = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Вы вступили в сообщество'),
            backgroundColor: Color(0xFF2E3E50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorOrNull?.message ?? 'Не удалось вступить в сообщество'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGroupActionLoading = false);
      }
    }
  }

  Future<void> _checkFriendStatus() async {
    if (_isMyWall || _targetId <= 0) return;
    try {
      final res = await widget.client.call<dynamic>(
        'friends.areFriends',
        params: {'user_ids': _targetId.toString()},
        parser: (json) => json,
      );
      if (!mounted) return;
      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull;
        int? status;
        if (data is List && data.isNotEmpty) {
          final item = data.first;
          if (item is Map) {
            status = JsonSafe.toInt(item['friend_status']);
          }
        } else if (data is Map) {
          status = JsonSafe.toInt(data['friend_status']);
        }
        if (status != null) {
          setState(() => _friendStatus = status);
          return;
        }
      }
    } catch (e) {
      debugPrint('[WallView] friends.areFriends error: $e');
    }

    // Fallback: check if _targetId is in current account's friends list
    try {
      final res = await widget.client.call<dynamic>(
        'friends.get',
        params: {
          'user_id': widget.account.userId.toString(),
          'count': '5000',
        },
        parser: (json) => json,
      );
      if (!mounted) return;
      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull;
        List items = [];
        if (data is List) {
          items = data;
        } else if (data is Map && data['items'] is List) {
          items = data['items'] as List;
        }
        final isFriend = items.any((id) {
          if (id is int) return id == _targetId;
          if (id is Map) return JsonSafe.toInt(id['id'] ?? id['user_id'] ?? id['uid']) == _targetId;
          return int.tryParse(id.toString()) == _targetId;
        });
        if (isFriend) {
          setState(() => _friendStatus = 3);
        }
      }
    } catch (e) {
      debugPrint('[WallView] friends.get fallback error: $e');
    }
  }

  String _getFriendButtonText() {
    switch (_friendStatus) {
      case 3:
        return 'В друзьях';
      case 1:
        return 'Заявка отправлена';
      case 2:
        return 'Принять заявку';
      default:
        return 'Добавить в друзья';
    }
  }

  Future<void> _handleFriendButtonPressed() async {
    if (_isFriendActionLoading) return;

    final status = _friendStatus ?? 0;

    // Already friends (status == 3): show modal confirm dialog to delete friend
    if (status == 3) {
      final userName = _user?.fullName.isNotEmpty == true ? _user!.fullName : 'пользователя';
      final confirmed = await showIos6ConfirmDialog(
        context: context,
        title: 'Удаление из друзей',
        message: 'Вы действительно хотите удалить $userName из списка друзей?',
        cancelText: 'Отмена',
        confirmText: 'Удалить',
        isDestructive: true,
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isFriendActionLoading = true);
      try {
        final res = await widget.client.call<dynamic>(
          'friends.delete',
          params: {'user_id': _targetId.toString()},
          parser: (json) => json,
        );
        if (!mounted) return;
        if (res.isSuccess) {
          setState(() => _friendStatus = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь удален из друзей'),
              backgroundColor: Color(0xFF2E3E50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorOrNull?.message ?? 'Не удалось удалить из друзей'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isFriendActionLoading = false);
        }
      }
      return;
    }

    // Friend request already sent (status == 1): confirmation dialog to cancel request
    if (status == 1) {
      final confirmed = await showIos6ConfirmDialog(
        context: context,
        title: 'Отмена заявки',
        message: 'Вы действительно хотите отменить заявку в друзья?',
        cancelText: 'Назад',
        confirmText: 'Отменить заявку',
        isDestructive: true,
      );

      if (confirmed != true || !mounted) return;

      setState(() => _isFriendActionLoading = true);
      try {
        final res = await widget.client.call<dynamic>(
          'friends.delete',
          params: {'user_id': _targetId.toString()},
          parser: (json) => json,
        );
        if (!mounted) return;
        if (res.isSuccess) {
          setState(() => _friendStatus = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Заявка в друзья отменена'),
              backgroundColor: Color(0xFF2E3E50),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorOrNull?.message ?? 'Не удалось отменить заявку'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isFriendActionLoading = false);
        }
      }
      return;
    }

    // Not friends (status == 0) or incoming request (status == 2): send/accept friend request
    setState(() => _isFriendActionLoading = true);
    try {
      final res = await widget.client.call<dynamic>(
        'friends.add',
        params: {
          'user_id': _targetId.toString(),
        },
        parser: (json) => json,
      );
      if (!mounted) return;
      if (res.isSuccess) {
        final code = JsonSafe.toInt(res.dataOrNull);
        final newStatus = (code == 2) ? 3 : 1;
        setState(() => _friendStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 3
                  ? 'Пользователь добавлен в друзья'
                  : 'Заявка в друзья отправлена',
            ),
            backgroundColor: const Color(0xFF2E3E50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorOrNull?.message ?? 'Не удалось отправить заявку в друзья'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFriendActionLoading = false);
      }
    }
  }

  void _openChatWithUser() {
    final title = _user?.fullName.isNotEmpty == true
        ? _user!.fullName
        : 'Пользователь';
    final avatarUrl = _user?.avatarUrl;
    final item = ConversationItem(
      peerId: _targetId,
      peerType: _targetId < 0 ? 'group' : 'user',
      inRead: 0,
      outRead: 0,
      unreadCount: 0,
      isImportant: false,
      isUnanswered: false,
      lastMessage: Message(
        id: 0,
        date: 0,
        peerId: _targetId,
        fromId: widget.account.userId,
        text: '',
        isOut: false,
        isImportant: false,
        attachments: const [],
        fwdMessages: const [],
        conversationMessageId: 0,
        updateTime: 0,
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatConversationView(
          client: widget.client,
          account: widget.account,
          conversation: item,
          title: title,
          avatarUrl: avatarUrl,
          currentUserId: widget.account.userId,
        ),
      ),
    );
  }

  void _openUserProfile(int userId) {
    if (userId == 0) return;
    if (userId == _targetId) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WallView(
          client: widget.client,
          account: widget.account,
          ownerId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF243242),
        appBar: canPop
            ? RetroAppBar(
                showBackButton: true,
                title: _isGroupWall ? 'Сообщество' : 'Страница пользователя',
              )
            : null,
        body: Center(
          child: _isLoadingProfile
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RetroLoadingIndicator(size: 32),
                    SizedBox(height: 14),
                    Text(
                      'Загрузка страницы...',
                      style: TextStyle(
                        color: Color(0xFFCAD8E6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _profileErrorMessage ?? 'Не удалось загрузить страницу',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCAD8E6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, -1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      RetroButton(
                        text: 'Повторить',
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        fontSize: 14,
                        onPressed: () {
                          setState(() {
                            _isLoadingProfile = true;
                            _profileErrorMessage = null;
                          });
                          _loadUserProfile(forceRefresh: true);
                          _loadPosts(refresh: true, forceRefresh: true);
                        },
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final Widget scrollContent = RetroPullToRefresh(
      onRefresh: _handleRefresh,
      backgroundColor: const Color(0xFF283647),
      contentColor: const Color(0xFFCAD8E6),
      arrowColor: const Color(0xFF8BA5BE),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Dark Denim Profile Card Container
          SliverToBoxAdapter(
            child: _buildProfileHeaderCard(),
          ),

          // Denim "Информация" Section
          SliverToBoxAdapter(
            child: _buildInfoSection(_user),
          ),

          // Denim Composer Bar with Segmented Pills
          SliverToBoxAdapter(
            child: _buildComposerAndFilters(),
          ),

          // Posts Feed Slivers
          if (_isLoadingPosts)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: RetroLoadingIndicator(size: 28)),
              ),
            )
          else if (_posts.isEmpty)
            SliverToBoxAdapter(
              child: _buildEmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              sliver: SliverList.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return WallPostCard(
                    key: ValueKey('post_${post.id}'),
                    post: post,
                    onLikeToggle: () => _handleToggleLike(post),
                    onDeleteTap: (_isMyWall || post.fromId == widget.account.userId)
                        ? () => _handleDeletePost(post)
                        : null,
                    onAuthorTap: _openUserProfile,
                  );
                },
              ),
            ),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: RetroLoadingIndicator(size: 20)),
                ),
              ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFCAD4DF),
      appBar: canPop
          ? RetroAppBar(
              showBackButton: true,
              title: _user!.fullName.isNotEmpty
                  ? _user!.fullName
                  : (_isGroupWall ? 'Сообщество' : 'Страница пользователя'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isConstrained = constraints.maxWidth > 850;

          if (!isConstrained) {
            return scrollContent;
          }

          return Container(
            color: const Color(0xFFCAD4DF),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                constraints: const BoxConstraints(maxWidth: 850),
                decoration: const BoxDecoration(
                  color: Color(0xFFCBD2D8),
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: Color(0xFFB8C5D3),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: scrollContent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    final user = _user;
    final avatarUrl = user?.avatarUrl ?? widget.account.avatarUrl;
    final name = user?.fullName ?? widget.account.name;
    final nickname = user?.nickname ?? '';
    final status = user?.status.trim() ?? '';
    final isOnline = user?.isOnline ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF35465A),
            Color(0xFF283647),
          ],
        ),
        border: Border(
          top: BorderSide(color: Color(0x30FFFFFF), width: 1),
          bottom: BorderSide(color: Color(0xFF1B2430), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x35000000),
            offset: Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row: Avatar + Name + Status + Online
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with iOS 6 squircle photo frame
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x60000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: RetroAvatar(
                    url: avatarUrl,
                    size: 80,
                    fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name, Status, Online
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Nickname
                    if (nickname.isNotEmpty && user != null) ...[
                      Text(
                        '${user.firstName} ($nickname)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        user.lastName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 5),

                    // Status quote
                    if (status.isNotEmpty) ...[
                      Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF90A8C0),
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Online indicator or community type pill
                    if (_isGroupWall) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.public,
                            size: 14,
                            color: Color(0xFF869DB3),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            user?.groupTypeName ?? 'Сообщество',
                            style: const TextStyle(
                              color: Color(0xFF869DB3),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: isOnline
                                    ? const [Color(0xFF6DE86D), Color(0xFF299929)]
                                    : const [Color(0xFF8B9BAE), Color(0xFF556475)],
                              ),
                              border: Border.all(
                                color: isOnline ? const Color(0xFF1B6B1B) : const Color(0xFF3D4956),
                                width: 0.8,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Онлайн' : 'Не в сети',
                            style: TextStyle(
                              color: isOnline ? const Color(0xFF7EBF88) : const Color(0xFF869DB3),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2x3 Counters Grid (with inner shadow wells!)
          WallCountersGrid(
            counters: user?.counters ?? const UserCounters(),
            isGroup: _isGroupWall,
            onCounterTap: (key) {
              if (key == 'photos') {
                MediaView.open(
                  context,
                  client: widget.client,
                  account: widget.account,
                  ownerId: _targetId,
                  initialTab: MediaTab.photos,
                );
              } else if (key == 'videos') {
                MediaView.open(
                  context,
                  client: widget.client,
                  account: widget.account,
                  ownerId: _targetId,
                  initialTab: MediaTab.videos,
                );
              } else if (key == 'audios') {
                MediaView.open(
                  context,
                  client: widget.client,
                  account: widget.account,
                  ownerId: _targetId,
                  initialTab: MediaTab.audio,
                );
              }
            },
          ),

          if (_isGroupWall) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Ios6ProfileActionButton(
                    text: _isGroupMember == true ? 'Вы подписаны' : 'Подписаться',
                    isBlue: true,
                    isDark: _isGroupMember == true,
                    isLoading: _isGroupActionLoading,
                    onPressed: _handleGroupMembershipPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Ios6ProfileActionButton(
                    text: 'Сообщение',
                    isBlue: false,
                    onPressed: _openChatWithUser,
                  ),
                ),
              ],
            ),
          ] else if (!_isMyWall && _targetId > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Ios6ProfileActionButton(
                    text: _getFriendButtonText(),
                    isBlue: true,
                    isDark: _friendStatus == 3 || _friendStatus == 1,
                    isLoading: _isFriendActionLoading,
                    onPressed: _handleFriendButtonPressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Ios6ProfileActionButton(
                    text: 'Сообщение',
                    isBlue: false,
                    onPressed: _openChatWithUser,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(User? user) {
    final isGroup = _isGroupWall;

    final hasGroupInfo = isGroup && user != null &&
        (user.about.isNotEmpty ||
            user.site.isNotEmpty ||
            user.city.isNotEmpty ||
            user.registrationDate.isNotEmpty);

    final hasBasicInfo = !isGroup && user != null &&
        (user.pronouns.isNotEmpty ||
            user.relation.isNotEmpty ||
            user.registrationDate.isNotEmpty ||
            user.homeTown.isNotEmpty ||
            user.political.isNotEmpty ||
            user.bdate.isNotEmpty);

    final hasContacts = !isGroup && user != null &&
        (user.telegram.isNotEmpty ||
            user.site.isNotEmpty ||
            user.city.isNotEmpty);

    final hasInterests = !isGroup && user != null &&
        (user.interests.isNotEmpty ||
            user.music.isNotEmpty ||
            user.tv.isNotEmpty ||
            user.quotes.isNotEmpty ||
            user.about.isNotEmpty);

    final hasAnyInfo = isGroup ? hasGroupInfo : (hasBasicInfo || hasContacts || hasInterests);
    if (!hasAnyInfo) return const SizedBox.shrink();

    return Column(
      children: [
        // Denim Grouped Bar Strip Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isInfoExpanded = !_isInfoExpanded;
                if (_isInfoExpanded) {
                  _infoAnimController.forward();
                } else {
                  _infoAnimController.reverse();
                }
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2E3E50),
                    Color(0xFF243140),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: Color(0x28FFFFFF), width: 1),
                  bottom: BorderSide(color: Color(0xFF19222C), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    'Информация',
                    style: TextStyle(
                      color: Color(0xFF9CB2C7),
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isInfoExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.fastOutSlowIn,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF869EB5),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Animated expandable container
        ClipRect(
          child: SizeTransition(
            sizeFactor: _infoHeightFactor,
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1F2A37),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF161E28), width: 1),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Builder(
                builder: (context) {
                  final Widget? leftWidget;
                  final Widget? rightWidget;

                  if (isGroup) {
                    final hasGroupMeta = user.site.isNotEmpty ||
                        user.city.isNotEmpty ||
                        user.groupTypeName.isNotEmpty ||
                        user.registrationDate.isNotEmpty;
                    final hasGroupAbout = user.about.isNotEmpty;

                    leftWidget = hasGroupMeta
                        ? _buildInfoCard(
                            children: [
                              if (user.site.isNotEmpty)
                                DottedLeaderRow(label: 'Веб-сайт', value: user.site, isLink: true),
                              if (user.city.isNotEmpty)
                                DottedLeaderRow(label: 'Город', value: user.city),
                              if (user.groupTypeName.isNotEmpty)
                                DottedLeaderRow(label: 'Тип', value: user.groupTypeName),
                              if (user.registrationDate.isNotEmpty)
                                DottedLeaderRow(label: 'Создано', value: User.formatRegistrationDate(user.registrationDate)),
                            ],
                          )
                        : null;

                    rightWidget = hasGroupAbout
                        ? _buildInfoCard(
                            children: [
                              _buildBlockInfo('Описание', user.about),
                            ],
                          )
                        : null;
                  } else {
                    if (hasBasicInfo || hasContacts) {
                      leftWidget = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasBasicInfo)
                            _buildInfoCard(
                              children: [
                                DottedLeaderRow(label: 'Местоимения', value: user.pronouns),
                                DottedLeaderRow(label: 'Семейное положение', value: user.relation, isLink: true),
                                DottedLeaderRow(label: 'Дата регистрации', value: User.formatRegistrationDate(user.registrationDate)),
                                DottedLeaderRow(label: 'Родной город', value: user.homeTown, isLink: true),
                                DottedLeaderRow(label: 'Полит. взгляды', value: user.political),
                                DottedLeaderRow(label: 'День рождения', value: user.bdate),
                              ],
                            ),
                          if (hasBasicInfo && hasContacts) const SizedBox(height: 10),
                          if (hasContacts)
                            _buildInfoCard(
                              children: [
                                DottedLeaderRow(label: 'Telegram', value: user.telegram),
                                DottedLeaderRow(label: 'Личный сайт', value: user.site, isLink: true),
                                DottedLeaderRow(label: 'Город', value: user.city),
                              ],
                            ),
                        ],
                      );
                    } else {
                      leftWidget = null;
                    }

                    rightWidget = hasInterests
                        ? _buildInfoCard(
                            children: [
                              if (user.interests.isNotEmpty)
                                _buildBlockInfo('Интересы', user.interests),
                              if (user.music.isNotEmpty)
                                _buildBlockInfo('Любимая музыка', user.music),
                              if (user.tv.isNotEmpty)
                                _buildBlockInfo('Любимые ТВ-шоу', user.tv),
                              if (user.quotes.isNotEmpty)
                                _buildBlockInfo('Любимые цитаты', user.quotes),
                              if (user.about.isNotEmpty)
                                _buildBlockInfo('О себе', user.about),
                            ],
                          )
                        : null;
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isWide = constraints.maxWidth >= 520;

                      if (leftWidget != null && rightWidget != null) {
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: leftWidget),
                              const SizedBox(width: 10),
                              Expanded(child: rightWidget),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              leftWidget,
                              const SizedBox(height: 10),
                              rightWidget,
                            ],
                          );
                        }
                      }

                      return leftWidget ?? rightWidget ?? const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18222D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF121922),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24FFFFFF),
            offset: Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildBlockInfo(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF869EB5),
                fontWeight: FontWeight.w600,
                height: 1.3,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFCAD7E5),
                height: 1.3,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerAndFilters() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF7F8FA),
            Color(0xFFD6DBE2),
          ],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF19232F), width: 1),
          bottom: BorderSide(color: Color(0xFFA5B0BE), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 1.5),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Pills: "Все записи" / "Мои записи"
          Row(
            children: [
              _buildFilterPill('all', 'Все записи'),
              const SizedBox(width: 8),
              _buildFilterPill(
                'owner',
                _isMyWall
                    ? 'Мои записи'
                    : (_isGroupWall
                        ? 'Записи сообщества'
                        : 'Записи ${_user?.firstName ?? 'автора'}'),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Post Input Bar: [+] [Что нового? / Написать на стене... ] [->]
          Row(
            children: [
              // (+) attachment button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Attachment picker
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFAFBFC),
                          Color(0xFFD3D8E0),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF9AA4B0), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Color(0xFF455566),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Input field (search/text bar capsule)
              Expanded(
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA5B0BD), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x15000000),
                        offset: Offset(0, 1),
                        blurRadius: 1.5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _postTextController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitPost(),
                    style: const TextStyle(fontSize: 13.5, color: RetroTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: _isMyWall ? 'Что нового?' : 'Написать на стене...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF8696A8),
                        fontSize: 13,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // (->) Send button (glossy iOS 6 blue button)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSendingPost ? null : _submitPost,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF4A8BE2),
                          Color(0xFF1B599E),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF144073), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x28000000),
                          offset: Offset(0, 1),
                          blurRadius: 1.5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSendingPost
                          ? const RetroLoadingIndicator(size: 15)
                          : const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 17,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label) {
    final isSelected = _currentFilter == filterKey;

    final gradientColors = isSelected
        ? const [Color(0xFF4C8CD6), Color(0xFF1E5899)]
        : const [Color(0xFFFFFFFF), Color(0xFFE5E9EE)];

    final borderColor = isSelected
        ? const Color(0xFF163E6D)
        : const Color(0xFFB5BDC8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onFilterChanged(filterKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF384656),
              shadows: [
                Shadow(
                  color: isSelected ? const Color(0x99000000) : Colors.white,
                  offset: isSelected ? const Offset(0, -1) : const Offset(0, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.article_outlined,
            size: 48,
            color: Color(0xFF8E9BA8),
          ),
          const SizedBox(height: 12),
          Text(
            _currentFilter == 'owner'
                ? 'На стене пока нет записей автора'
                : 'На стене пока нет записей',
            style: const TextStyle(
              color: Color(0xFF5D6B7A),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.white,
                  offset: Offset(0, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ios6ProfileActionButton extends StatefulWidget {
  final String text;
  final bool isBlue;
  final bool isDark;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _Ios6ProfileActionButton({
    required this.text,
    required this.isBlue,
    this.isDark = false,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<_Ios6ProfileActionButton> createState() => _Ios6ProfileActionButtonState();
}

class _Ios6ProfileActionButtonState extends State<_Ios6ProfileActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isBlue = widget.isBlue;
    final isDark = widget.isDark;
    final isPressed = _isPressed && !widget.isLoading && widget.onPressed != null;

    final List<Color> gradientColors;
    final Color borderColor;
    final Color textColor;
    final List<Shadow> textShadows;

    if (isBlue) {
      if (isDark) {
        if (isPressed) {
          gradientColors = const [
            Color(0xFF162331),
            Color(0xFF1E2E40),
            Color(0xFF15222E),
            Color(0xFF0D1720),
          ];
        } else {
          gradientColors = const [
            Color(0xFF384F69),
            Color(0xFF26384C),
            Color(0xFF1C2B3B),
            Color(0xFF131E29),
          ];
        }
        borderColor = const Color(0xFF0E1620);
        textColor = const Color(0xFFE4EDF7);
        textShadows = const [
          Shadow(
            color: Color(0xDD000000),
            offset: Offset(0, -1),
            blurRadius: 0.5,
          ),
        ];
      } else {
        if (isPressed) {
          gradientColors = const [
            Color(0xFF245082),
            Color(0xFF336CA7),
            Color(0xFF24558B),
            Color(0xFF1B416D),
          ];
        } else {
          gradientColors = const [
            Color(0xFF7CAAE4),
            Color(0xFF4C8CD6),
            Color(0xFF2F76C4),
            Color(0xFF205B9E),
          ];
        }
        borderColor = const Color(0xFF143B66);
        textColor = Colors.white;
        textShadows = const [
          Shadow(
            color: Color(0x99000000),
            offset: Offset(0, -1),
            blurRadius: 0.5,
          ),
        ];
      }
    } else {
      if (isPressed) {
        gradientColors = const [
          Color(0xFFBFC6CF),
          Color(0xFFCDD4DE),
          Color(0xFFC2C9D3),
          Color(0xFFB0B7C2),
        ];
      } else {
        gradientColors = const [
          Color(0xFFFFFFFF),
          Color(0xFFEEF1F5),
          Color(0xFFDFE4EB),
          Color(0xFFCED4DC),
        ];
      }
      borderColor = const Color(0xFF627182);
      textColor = const Color(0xFF202A35);
      textShadows = const [
        Shadow(
          color: Colors.white,
          offset: Offset(0, 1),
          blurRadius: 0,
        ),
      ];
    }

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          widget.onPressed?.call();
        }
      },
      onTapCancel: () {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.49, 0.50, 1.0],
            colors: gradientColors,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x35FFFFFF),
              offset: Offset(0, 1),
              blurRadius: 0,
            ),
            BoxShadow(
              color: const Color(0x30000000),
              offset: isPressed ? const Offset(0, 0.5) : const Offset(0, 1.5),
              blurRadius: isPressed ? 1 : 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(
                  color: isBlue
                      ? (isDark ? const Color(0x35FFFFFF) : const Color(0x70FFFFFF))
                      : const Color(0xAAFFFFFF),
                ),
              ),
              Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isBlue ? Colors.white : const Color(0xFF202A35),
                          ),
                        ),
                      )
                    : Text(
                        widget.text,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          shadows: textShadows,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
