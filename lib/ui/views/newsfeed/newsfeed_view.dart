import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import '../wall/wall_view.dart';
import '../wall/widgets/wall_post_card.dart';

class NewsfeedView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final String filter; // 'my' or 'global'
  final ValueChanged<String>? onFilterChanged;

  const NewsfeedView({
    super.key,
    required this.client,
    required this.account,
    this.filter = 'my',
    this.onFilterChanged,
  });

  @override
  State<NewsfeedView> createState() => _NewsfeedViewState();
}

class _NewsfeedViewState extends State<NewsfeedView> {
  late final NewsfeedHandler _newsfeedHandler;
  late final WallHandler _wallHandler;
  final ScrollController _scrollController = ScrollController();

  late String _currentFilter;

  List<Post> _myPosts = [];
  List<Post> _globalPosts = [];

  String? _myNextFrom;
  String? _globalNextFrom;

  int _myOffset = 0;
  int _globalOffset = 0;

  bool _hasMoreMy = true;
  bool _hasMoreGlobal = true;

  bool _isLoadingMy = false;
  bool _isLoadingGlobal = false;
  bool _isLoadingMore = false;

  String? _errorMy;
  String? _errorGlobal;

  List<Post> get _currentPosts => _currentFilter == 'my' ? _myPosts : _globalPosts;
  bool get _isCurrentLoading => _currentFilter == 'my' ? _isLoadingMy : _isLoadingGlobal;
  String? get _currentError => _currentFilter == 'my' ? _errorMy : _errorGlobal;
  bool get _currentHasMore => _currentFilter == 'my' ? _hasMoreMy : _hasMoreGlobal;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _newsfeedHandler = NewsfeedHandler(widget.client);
    _wallHandler = WallHandler(widget.client);
    _scrollController.addListener(_onScroll);

    _loadNews(filter: _currentFilter, refresh: false);
  }

  @override
  void didUpdateWidget(covariant NewsfeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _currentFilter = widget.filter;
      final currentList = _currentPosts;
      if (currentList.isEmpty && !_isCurrentLoading) {
        _loadNews(filter: _currentFilter, refresh: false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= maxScroll - 350 && !_isCurrentLoading && !_isLoadingMore && _currentHasMore) {
      _loadMore();
    }
  }

  Future<void> _loadNews({
    required String filter,
    bool refresh = false,
    bool forceRefresh = false,
  }) async {
    final isMy = filter == 'my';
    if (isMy) {
      if (_isLoadingMy) return;
      setState(() {
        _isLoadingMy = true;
        _errorMy = null;
        if (refresh) {
          _myOffset = 0;
          _myNextFrom = null;
          _hasMoreMy = true;
        }
      });
    } else {
      if (_isLoadingGlobal) return;
      setState(() {
        _isLoadingGlobal = true;
        _errorGlobal = null;
        if (refresh) {
          _globalOffset = 0;
          _globalNextFrom = null;
          _hasMoreGlobal = true;
        }
      });
    }

    try {
      final res = isMy
          ? await _newsfeedHandler.getNewsfeed(
              count: 25,
              offset: 0,
              startFrom: null,
              forceRefresh: forceRefresh,
            )
          : await _newsfeedHandler.getGlobalNewsfeed(
              count: 25,
              offset: 0,
              startFrom: null,
              forceRefresh: forceRefresh,
            );

      if (!mounted) return;

      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull!;
        setState(() {
          if (isMy) {
            _myPosts = data.items;
            _myOffset = data.items.length;
            _myNextFrom = data.nextFrom;
            _hasMoreMy = data.items.length >= 25;
            _isLoadingMy = false;
          } else {
            _globalPosts = data.items;
            _globalOffset = data.items.length;
            _globalNextFrom = data.nextFrom;
            _hasMoreGlobal = data.items.length >= 25;
            _isLoadingGlobal = false;
          }
        });
      } else {
        setState(() {
          final err = res.errorOrNull?.message ?? 'Не удалось загрузить новости';
          if (isMy) {
            _errorMy = err;
            _isLoadingMy = false;
          } else {
            _errorGlobal = err;
            _isLoadingGlobal = false;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final err = 'Ошибка сети: $e';
        if (isMy) {
          _errorMy = err;
          _isLoadingMy = false;
        } else {
          _errorGlobal = err;
          _isLoadingGlobal = false;
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_currentHasMore) return;
    final isMy = _currentFilter == 'my';

    setState(() => _isLoadingMore = true);

    try {
      final offset = isMy ? _myOffset : _globalOffset;
      final startFrom = isMy ? _myNextFrom : _globalNextFrom;

      final res = isMy
          ? await _newsfeedHandler.getNewsfeed(
              count: 25,
              offset: offset,
              startFrom: startFrom,
              forceRefresh: true,
            )
          : await _newsfeedHandler.getGlobalNewsfeed(
              count: 25,
              offset: offset,
              startFrom: startFrom,
              forceRefresh: true,
            );

      if (!mounted) return;

      if (res.isSuccess && res.dataOrNull != null) {
        final data = res.dataOrNull!;
        setState(() {
          if (isMy) {
            _myPosts.addAll(data.items);
            _myOffset += data.items.length;
            _myNextFrom = data.nextFrom;
            _hasMoreMy = data.items.isNotEmpty;
          } else {
            _globalPosts.addAll(data.items);
            _globalOffset += data.items.length;
            _globalNextFrom = data.nextFrom;
            _hasMoreGlobal = data.items.isNotEmpty;
          }
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleToggleLike(Post post) async {
    final isLiked = post.userLikes;
    final newCount = isLiked ? (post.likesCount - 1).clamp(0, 999999) : post.likesCount + 1;

    // Optimistic UI update in whichever list contains this post
    setState(() {
      _updatePostInList(_myPosts, post.id, post.ownerId, (p) {
        return p.copyWith(userLikes: !isLiked, likesCount: newCount);
      });
      _updatePostInList(_globalPosts, post.id, post.ownerId, (p) {
        return p.copyWith(userLikes: !isLiked, likesCount: newCount);
      });
    });

    final res = await _wallHandler.toggleLike(
      ownerId: post.ownerId,
      postId: post.id,
      isCurrentlyLiked: isLiked,
    );

    if (!mounted) return;
    if (res.isSuccess && res.dataOrNull != null) {
      setState(() {
        _updatePostInList(_myPosts, post.id, post.ownerId, (p) {
          return p.copyWith(likesCount: res.dataOrNull);
        });
        _updatePostInList(_globalPosts, post.id, post.ownerId, (p) {
          return p.copyWith(likesCount: res.dataOrNull);
        });
      });
    }
  }

  void _updatePostInList(
    List<Post> list,
    int postId,
    int ownerId,
    Post Function(Post) updater,
  ) {
    final idx = list.indexWhere((p) => p.id == postId && p.ownerId == ownerId);
    if (idx != -1) {
      list[idx] = updater(list[idx]);
    }
  }

  Future<void> _handleDeletePost(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление записи'),
        content: const Text('Вы действительно хотите удалить эту запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
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
        _myPosts.removeWhere((p) => p.id == post.id && p.ownerId == post.ownerId);
        _globalPosts.removeWhere((p) => p.id == post.id && p.ownerId == post.ownerId);
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

  void _openUserProfile(int userId) {
    if (userId == 0) return;

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
    if (_isCurrentLoading && _currentPosts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RetroLoadingIndicator(size: 28),
            SizedBox(height: 12),
            Text(
              'Загрузка новостей...',
              style: TextStyle(
                fontSize: 13,
                color: RetroTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentError != null && _currentPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFF8B98A7)),
              const SizedBox(height: 12),
              Text(
                _currentError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RetroTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              RetroButton(
                text: 'Повторить',
                onPressed: () => _loadNews(
                  filter: _currentFilter,
                  refresh: true,
                  forceRefresh: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final posts = _currentPosts;

    if (posts.isEmpty) {
      return RetroPullToRefresh(
        onRefresh: () => _loadNews(
          filter: _currentFilter,
          refresh: true,
          forceRefresh: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.newspaper_outlined,
                      size: 54,
                      color: Color(0xFFBAC5D4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentFilter == 'my'
                          ? 'У вас пока нет новостей'
                          : 'В глобальной ленте пока нет записей',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: RetroTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Потяните вниз для обновления',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9EABB8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RetroPullToRefresh(
      onRefresh: () => _loadNews(
        filter: _currentFilter,
        refresh: true,
        forceRefresh: true,
      ),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: posts.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: RetroLoadingIndicator(size: 20)),
            );
          }

          final post = posts[index];
          return WallPostCard(
            key: ValueKey('news_${post.ownerId}_${post.id}'),
            post: post,
            onLikeToggle: () => _handleToggleLike(post),
            onDeleteTap: post.fromId == widget.account.userId
                ? () => _handleDeletePost(post)
                : null,
            onAuthorTap: _openUserProfile,
          );
        },
      ),
    );
  }
}
