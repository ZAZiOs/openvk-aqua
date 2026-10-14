import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/api/wall_handler.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_avatar.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import 'widgets/dotted_leader_row.dart';
import 'widgets/wall_counters_grid.dart';
import 'widgets/wall_post_card.dart';

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

  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;

  // Filter: 'all' (Все записи), 'owner' (Мои записи)
  String _currentFilter = 'all';
  bool _isInfoExpanded = false;
  bool _isSendingPost = false;

  int get _targetId => widget.ownerId ?? widget.account.userId;
  bool get _isMyWall => _targetId == widget.account.userId;

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

    // Initial check in local cache
    final cached = widget.client.userCache.getUser(_targetId);
    if (cached != null) {
      _user = cached;
    }

    _loadUserProfile();
    _loadPosts(refresh: true);
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

  Future<void> _loadUserProfile() async {
    final res = await _wallHandler.getProfile(_targetId);
    if (!mounted) return;
    if (res.isSuccess && res.dataOrNull != null) {
      setState(() {
        _user = res.dataOrNull;
      });
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
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
      _loadUserProfile(),
      _loadPosts(refresh: true),
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
      await _loadPosts(refresh: true);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление записи'),
        content: const Text('Вы действительно хотите удалить эту запись со стены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
    setState(() => _currentFilter = filter);
    _loadPosts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD3DBE3),
      body: RetroPullToRefresh(
        onRefresh: _handleRefresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // Dark Profile Card Container
            _buildProfileHeaderCard(),

            // Full-width "Информация" Section
            _buildInfoSection(_user),

            // Metallic Composer Bar with Filter Pills
            _buildComposerAndFilters(),

            // Posts Feed Container
            Container(
              color: const Color(0xFFD3DBE3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isLoadingPosts)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: RetroLoadingIndicator(size: 28)),
                    )
                  else if (_posts.isEmpty)
                    _buildEmptyState()
                  else ...[
                    for (final post in _posts)
                      WallPostCard(
                        key: ValueKey('post_${post.id}'),
                        post: post,
                        onLikeToggle: () => _handleToggleLike(post),
                        onDeleteTap: (_isMyWall || post.fromId == widget.account.userId)
                            ? () => _handleDeletePost(post)
                            : null,
                      ),
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: RetroLoadingIndicator(size: 20)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
      color: const Color(0xFF344454),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row: Avatar + Name + Status + Online
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with dark retro frame
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF192533),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: RetroAvatar(
                    url: avatarUrl,
                    size: 84,
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
                              color: Color(0x99000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
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
                              color: Color(0x99000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
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
                              color: Color(0x99000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
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
                          color: Color(0xFF8BA2B8),
                          fontSize: 13.5,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Online indicator
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? const Color(0xFF4CD964) : const Color(0xFF6B8096),
                            boxShadow: isOnline
                                ? const [
                                    BoxShadow(
                                      color: Color(0x804CD964),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isOnline ? 'Онлайн' : 'Не в сети',
                          style: TextStyle(
                            color: isOnline ? const Color(0xFF7E97AF) : const Color(0xFF6E849A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2x3 Counters Grid
          WallCountersGrid(
            counters: user?.counters ?? const UserCounters(),
            onCounterTap: (key) {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(User? user) {
    final hasBasicInfo = user != null &&
        (user.pronouns.isNotEmpty ||
            user.relation.isNotEmpty ||
            user.registrationDate.isNotEmpty ||
            user.homeTown.isNotEmpty ||
            user.political.isNotEmpty ||
            user.bdate.isNotEmpty);

    final hasContacts = user != null &&
        (user.telegram.isNotEmpty ||
            user.site.isNotEmpty ||
            user.city.isNotEmpty);

    final hasInterests = user != null &&
        (user.interests.isNotEmpty ||
            user.music.isNotEmpty ||
            user.tv.isNotEmpty ||
            user.quotes.isNotEmpty ||
            user.about.isNotEmpty);

    return Column(
      children: [
        // Full-width Header Strip
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
              decoration: BoxDecoration(
                color: const Color(0xFF304050),
                border: Border(
                  top: const BorderSide(color: Color(0xFF283644), width: 1),
                  bottom: BorderSide(
                    color: _isInfoExpanded
                        ? const Color(0xFF263544)
                        : const Color(0xFF202C38),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    'Информация',
                    style: TextStyle(
                      color: Color(0xFF8EA4BA),
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Color(0x60000000),
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
                      color: Color(0xFF8EA4BA),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Animated expandable container stretching downward
        ClipRect(
          child: SizeTransition(
            sizeFactor: _infoHeightFactor,
            alignment: Alignment.topCenter,
            child: (user != null)
                ? Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF304050),
                          Color(0xFF475B73),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF223040), width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasBasicInfo)
                          _buildInfoCard(
                            children: [
                              DottedLeaderRow(label: 'Местоимения', value: user.pronouns),
                              DottedLeaderRow(label: 'Семейное положение', value: user.relation, isLink: true),
                              DottedLeaderRow(label: 'Дата регистрации', value: user.registrationDate),
                              DottedLeaderRow(label: 'Родной город', value: user.homeTown, isLink: true),
                              DottedLeaderRow(label: 'Полит. взгляды', value: user.political),
                              DottedLeaderRow(label: 'День рождения', value: user.bdate),
                            ],
                          ),
                        if (hasContacts) ...[
                          if (hasBasicInfo) const SizedBox(height: 10),
                          _buildInfoCard(
                            children: [
                              DottedLeaderRow(label: 'Telegram', value: user.telegram),
                              DottedLeaderRow(label: 'Личный сайт', value: user.site, isLink: true),
                              DottedLeaderRow(label: 'Город', value: user.city),
                            ],
                          ),
                        ],
                        if (hasInterests) ...[
                          if (hasBasicInfo || hasContacts) const SizedBox(height: 10),
                          _buildInfoCard(
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
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B3946),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF1E2833),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
            // Light inner top shadow
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Light inner bottom bevel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ],
        ),
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
                fontWeight: FontWeight.w500,
                height: 1.3,
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
          stops: [0.0, 0.05, 0.5, 1.0],
          colors: [
            Color(0xFFF7FAFD),
            Color(0xFFE4E9EF),
            Color(0xFFD4DCE4),
            Color(0xFFC5CED8),
          ],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFB0BDCA), width: 1),
          bottom: BorderSide(color: Color(0xFF98A6B4), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Pills: "Все записи" / "Мои записи"
          Row(
            children: [
              _buildFilterPill('all', 'Все записи'),
              const SizedBox(width: 8),
              _buildFilterPill('owner', 'Мои записи'),
            ],
          ),

          const SizedBox(height: 10),

          // Post Input Bar: [+] [Что нового?  ] [->]
          Row(
            children: [
              // (+) attachment button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Attachment picker
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFBCC7D4),
                          Color(0xFF95A5B6),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF768797), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 1,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                            shadows: [
                              Shadow(
                                color: Color(0x66000000),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Input field
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFA2B0BF), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x28000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        spreadRadius: -0.5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _postTextController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitPost(),
                    style: const TextStyle(fontSize: 13.5, color: RetroTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Что нового?',
                      hintStyle: TextStyle(
                        color: Color(0xFF8899AA),
                        fontSize: 13.5,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // (->) Send button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSendingPost ? null : _submitPost,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF5591E2),
                          Color(0xFF2663BD),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF1B4E99), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 1,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        Center(
                          child: _isSendingPost
                              ? const RetroLoadingIndicator(size: 16)
                              : const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                        ),
                      ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onFilterChanged(filterKey),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF9CAEC0),
                      Color(0xFF8697A9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF6F8092), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 1),
                      blurRadius: 1,
                    ),
                  ],
                )
              : BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE6EBF1),
                      Color(0xFFD2D9E2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFA5B3C1), width: 1),
                ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF283747) : const Color(0xFF566779),
              shadows: isSelected
                  ? const [
                      Shadow(
                        color: Color(0x40FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
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
          Icon(
            Icons.article_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            _currentFilter == 'owner'
                ? 'На стене пока нет записей автора'
                : 'На стене пока нет записей',
            style: const TextStyle(
              color: Color(0xFF7A8B9C),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
