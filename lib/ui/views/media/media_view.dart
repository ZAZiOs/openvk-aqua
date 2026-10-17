import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/media_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/attachment.dart';
import '../../../core/services/audio_player_service.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/drawer_bound_physics.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_media_viewer.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import '../../widgets/retro_segmented_control.dart';
import '../video/retro_video_player_view.dart';
import 'audio_playlists_view.dart';
import 'retro_audio_mini_player.dart';

enum MediaTab {
  photos('Фото'),
  videos('Видео'),
  audio('Аудио');

  final String label;
  const MediaTab(this.label);
}

class MediaView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final int? ownerId;
  final MediaTab initialTab;
  final MediaTab? tab;
  final ValueChanged<MediaTab>? onTabChanged;
  final bool hideAppBar;
  final String? title;

  const MediaView({
    super.key,
    required this.client,
    required this.account,
    this.ownerId,
    this.initialTab = MediaTab.photos,
    this.tab,
    this.onTabChanged,
    this.hideAppBar = false,
    this.title,
  });

  /// Open MediaView in a full-screen route with its own RetroAppBar.
  static Future<void> open(
    BuildContext context, {
    required OpenVkClient client,
    required SavedAccount account,
    int? ownerId,
    MediaTab initialTab = MediaTab.photos,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaView(
          client: client,
          account: account,
          ownerId: ownerId,
          initialTab: initialTab,
          hideAppBar: false,
          title: title,
        ),
      ),
    );
  }

  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  late final MediaHandler _mediaHandler;
  late final PageController _pageController;
  late MediaTab _activeTab;
  final _audioService = RetroAudioPlayerService.instance;

  // Photos State
  final List<PhotoAttachment> _photos = [];
  int _photosCount = 0;
  bool _photosLoading = false;
  bool _photosError = false;
  bool _photosHasMore = true;
  bool _photosLoadedOnce = false;
  final ScrollController _photosScrollController = ScrollController();

  // Videos State
  final List<VideoAttachment> _videos = [];
  int _videosCount = 0;
  bool _videosLoading = false;
  bool _videosError = false;
  bool _videosHasMore = true;
  bool _videosLoadedOnce = false;
  final ScrollController _videosScrollController = ScrollController();

  // Audio State
  final List<AudioAttachment> _audios = [];
  int _audiosCount = 0;
  bool _audiosLoading = false;
  bool _audiosError = false;
  bool _audiosHasMore = true;
  bool _audiosLoadedOnce = false;
  final ScrollController _audiosScrollController = ScrollController();

  int get _targetId => widget.ownerId ?? widget.account.userId;

  @override
  void initState() {
    super.initState();
    _mediaHandler = MediaHandler(widget.client);
    _activeTab = widget.tab ?? widget.initialTab;
    _pageController = PageController(initialPage: _activeTab.index);

    _photosScrollController.addListener(_onPhotosScroll);
    _videosScrollController.addListener(_onVideosScroll);
    _audiosScrollController.addListener(_onAudiosScroll);

    _loadTabIfNeeded(_activeTab);
  }

  @override
  void didUpdateWidget(covariant MediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != null && widget.tab != _activeTab) {
      _selectTab(widget.tab!, notify: false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _photosScrollController.dispose();
    _videosScrollController.dispose();
    _audiosScrollController.dispose();
    super.dispose();
  }

  void _onPhotosScroll() {
    if (!_photosScrollController.hasClients) return;
    final maxScroll = _photosScrollController.position.maxScrollExtent;
    final currentScroll = _photosScrollController.offset;
    if (currentScroll >= maxScroll - 300 && !_photosLoading && _photosHasMore) {
      _loadPhotos(more: true);
    }
  }

  void _onVideosScroll() {
    if (!_videosScrollController.hasClients) return;
    final maxScroll = _videosScrollController.position.maxScrollExtent;
    final currentScroll = _videosScrollController.offset;
    if (currentScroll >= maxScroll - 300 && !_videosLoading && _videosHasMore) {
      _loadVideos(more: true);
    }
  }

  void _onAudiosScroll() {
    if (!_audiosScrollController.hasClients) return;
    final maxScroll = _audiosScrollController.position.maxScrollExtent;
    final currentScroll = _audiosScrollController.offset;
    if (currentScroll >= maxScroll - 300 && !_audiosLoading && _audiosHasMore) {
      _loadAudios(more: true);
    }
  }

  void _selectTab(
    MediaTab tab, {
    bool animatePage = true,
    bool notify = true,
  }) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
    });
    if (animatePage && _pageController.hasClients) {
      if (_pageController.position.hasContentDimensions) {
        if (_pageController.page?.round() != tab.index) {
          _pageController.animateToPage(
            tab.index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients &&
              _pageController.position.hasContentDimensions &&
              _pageController.page?.round() != tab.index) {
            _pageController.jumpToPage(tab.index);
          }
        });
      }
    }
    if (notify) {
      widget.onTabChanged?.call(tab);
    }
    _loadTabIfNeeded(tab);
  }

  void _loadTabIfNeeded(MediaTab tab) {
    switch (tab) {
      case MediaTab.photos:
        if (!_photosLoadedOnce && !_photosLoading) {
          _loadPhotos();
        }
        break;
      case MediaTab.videos:
        if (!_videosLoadedOnce && !_videosLoading) {
          _loadVideos();
        }
        break;
      case MediaTab.audio:
        if (!_audiosLoadedOnce && !_audiosLoading) {
          _loadAudios();
        }
        break;
    }
  }

  Future<void> _loadPhotos({bool more = false, bool forceRefresh = false}) async {
    if (_photosLoading) return;
    setState(() {
      _photosLoading = true;
      if (!more) _photosError = false;
    });

    final offset = more ? _photos.length : 0;
    final res = await _mediaHandler.getPhotos(
      ownerId: _targetId,
      count: 30,
      offset: offset,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _photosLoading = false;
        _photosLoadedOnce = true;
        _photosCount = data.count > 0 ? data.count : (more ? _photos.length + data.items.length : data.items.length);
        if (more) {
          _photos.addAll(data.items);
        } else {
          _photos
            ..clear()
            ..addAll(data.items);
        }
        _photosHasMore = data.items.isNotEmpty && _photos.length < _photosCount;
      });
    } else {
      setState(() {
        _photosLoading = false;
        if (!more && _photos.isEmpty) {
          _photosError = true;
        }
      });
    }
  }

  Future<void> _loadVideos({bool more = false, bool forceRefresh = false}) async {
    if (_videosLoading) return;
    setState(() {
      _videosLoading = true;
      if (!more) _videosError = false;
    });

    final offset = more ? _videos.length : 0;
    final res = await _mediaHandler.getVideos(
      ownerId: _targetId,
      count: 20,
      offset: offset,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _videosLoading = false;
        _videosLoadedOnce = true;
        _videosCount = data.count > 0 ? data.count : (more ? _videos.length + data.items.length : data.items.length);
        if (more) {
          _videos.addAll(data.items);
        } else {
          _videos
            ..clear()
            ..addAll(data.items);
        }
        _videosHasMore = data.items.isNotEmpty && _videos.length < _videosCount;
      });
    } else {
      setState(() {
        _videosLoading = false;
        if (!more && _videos.isEmpty) {
          _videosError = true;
        }
      });
    }
  }

  Future<void> _loadAudios({bool more = false, bool forceRefresh = false}) async {
    if (_audiosLoading) return;
    setState(() {
      _audiosLoading = true;
      if (!more) _audiosError = false;
    });

    final offset = more ? _audios.length : 0;
    final res = await _mediaHandler.getAudios(
      ownerId: _targetId,
      count: 30,
      offset: offset,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _audiosLoading = false;
        _audiosLoadedOnce = true;
        _audiosCount = data.count > 0 ? data.count : (more ? _audios.length + data.items.length : data.items.length);
        if (more) {
          _audios.addAll(data.items);
        } else {
          _audios
            ..clear()
            ..addAll(data.items);
        }
        _audiosHasMore = data.items.isNotEmpty && _audios.length < _audiosCount;
      });
    } else {
      setState(() {
        _audiosLoading = false;
        if (!more && _audios.isEmpty) {
          _audiosError = true;
        }
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const DrawerBoundPhysics(
              parent: PageScrollPhysics(parent: ClampingScrollPhysics()),
            ),
            onPageChanged: (index) {
              final newTab = MediaTab.values[index];
              if (_activeTab != newTab) {
                _selectTab(newTab, animatePage: false);
              }
            },
            children: [
              _MediaKeepAlive(child: _buildPhotosTab(context)),
              _MediaKeepAlive(child: _buildVideosTab(context)),
              _MediaKeepAlive(child: _buildAudioTab(context)),
            ],
          ),
        ),
        if (!widget.hideAppBar) const RetroAudioMiniPlayer(),
      ],
    );

    if (widget.hideAppBar) {
      return body;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopWide = screenWidth >= 850;

    return Scaffold(
      backgroundColor: RetroTheme.scaffoldBackground,
      appBar: RetroAppBar(
        showBackButton: true,
        titleWidget: RetroSegmentedControl<MediaTab>(
          tabs: const {
            MediaTab.photos: 'Фото',
            MediaTab.videos: 'Видео',
            MediaTab.audio: 'Аудио',
          },
          selected: _activeTab,
          onSelected: _selectTab,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          hasShadow: false,
        ),
        actions: [
          if (_activeTab == MediaTab.audio)
            RetroHeaderButton(
              icon: Icons.queue_music_rounded,
              text: 'Плейлисты',
              onPressed: () => AudioPlaylistsView.open(
                context,
                client: widget.client,
                account: widget.account,
                ownerId: _targetId,
              ),
            ),
        ],
      ),
      body: isDesktopWide
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 850),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.symmetric(
                    vertical: BorderSide(
                      color: const Color(0xFFC3D1E0).withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(-3, 0),
                    ),
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(3, 0),
                    ),
                  ],
                ),
                child: body,
              ),
            )
          : body,
    );
  }

  // --- Photos Tab ---
  Widget _buildPhotosTab(BuildContext context) {
    if (_photosError && _photos.isEmpty) {
      return _buildErrorState(
        title: 'Не удалось загрузить фотографии',
        onRetry: () => _loadPhotos(forceRefresh: true),
      );
    }

    if (_photosLoading && _photos.isEmpty) {
      return const Center(
        child: RetroLoadingIndicator(size: 32),
      );
    }

    if (_photos.isEmpty) {
      return RetroPullToRefresh(
        onRefresh: () => _loadPhotos(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: _buildEmptyState(
                icon: Icons.photo_library_outlined,
                text: 'Нет фотографий',
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = screenWidth < 480
        ? 3
        : (screenWidth < 750 ? 4 : 5);

    return RetroPullToRefresh(
      onRefresh: () => _loadPhotos(forceRefresh: true),
      child: CustomScrollView(
        controller: _photosScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'Фотографии',
              count: _photosCount > 0 ? _photosCount : _photos.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(4),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final photo = _photos[index];
                  return GestureDetector(
                    onTap: () {
                      RetroMediaViewer.open(
                        context,
                        items: _photos
                            .map((p) => Attachment(type: 'photo', photo: p))
                            .toList(),
                        initialIndex: index,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E7EB),
                        border: Border.all(
                          color: const Color(0xFFD0D7DE),
                          width: 0.5,
                        ),
                      ),
                      child: Image.network(
                        photo.url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: RetroLoadingIndicator(size: 18),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Color(0xFF8B98A7),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _photos.length,
              ),
            ),
          ),
          if (_photosLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: RetroLoadingIndicator(size: 24)),
              ),
            ),
        ],
      ),
    );
  }

  // --- Videos Tab ---
  Widget _buildVideosTab(BuildContext context) {
    if (_videosError && _videos.isEmpty) {
      return _buildErrorState(
        title: 'Не удалось загрузить видеозаписи',
        onRetry: () => _loadVideos(forceRefresh: true),
      );
    }

    if (_videosLoading && _videos.isEmpty) {
      return const Center(
        child: RetroLoadingIndicator(size: 32),
      );
    }

    if (_videos.isEmpty) {
      return RetroPullToRefresh(
        onRefresh: () => _loadVideos(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: _buildEmptyState(
                icon: Icons.video_library_outlined,
                text: 'Нет видеозаписей',
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTwoColumn = screenWidth >= 620;

    return RetroPullToRefresh(
      onRefresh: () => _loadVideos(forceRefresh: true),
      child: CustomScrollView(
        controller: _videosScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              title: 'Видеозаписи',
              count: _videosCount > 0 ? _videosCount : _videos.length,
            ),
          ),
          if (!isTwoColumn)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = _videos[index];
                  return _buildVideoCard(context, video);
                },
                childCount: _videos.length,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = _videos[index];
                    return _buildVideoCard(context, video, inGrid: true);
                  },
                  childCount: _videos.length,
                ),
              ),
            ),
          if (_videosLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: RetroLoadingIndicator(size: 24)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoAttachment video, {bool inGrid = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => RetroVideoPlayerView.open(context, video),
      child: Container(
        margin: inGrid ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD4DAE2), width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              offset: Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: inGrid ? 4 : 0,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.photoUrl.isNotEmpty)
                      Image.network(
                        video.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF2B333E),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF2B333E),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    // Vignette
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x15000000),
                            Color(0x60000000),
                          ],
                        ),
                      ),
                    ),
                    // Play icon in center
                    Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xBB000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    // Duration badge in bottom right
                    if (video.duration > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xDD000000),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _formatDuration(video.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title.isNotEmpty ? video.title : 'Видеозапись',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RetroTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  if (video.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      video.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RetroTheme.textSecondary,
                        fontSize: 11.5,
                      ),
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

  // --- Audio Tab (iPod style) ---
  Widget _buildAudioTab(BuildContext context) {
    if (_audiosError && _audios.isEmpty) {
      return _buildErrorState(
        title: 'Не удалось загрузить аудиозаписи',
        onRetry: () => _loadAudios(forceRefresh: true),
      );
    }

    if (_audiosLoading && _audios.isEmpty) {
      return const Center(
        child: RetroLoadingIndicator(size: 32),
      );
    }

    if (_audios.isEmpty) {
      return RetroPullToRefresh(
        onRefresh: () => _loadAudios(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: _buildEmptyState(
                icon: Icons.music_note_rounded,
                text: 'Нет аудиозаписей',
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: _audioService,
      builder: (context, _) {
        return RetroPullToRefresh(
          onRefresh: () => _loadAudios(forceRefresh: true),
          child: CustomScrollView(
            controller: _audiosScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  title: 'Аудиозаписи',
                  count: _audiosCount > 0 ? _audiosCount : _audios.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0E000000),
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _audios.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 0.8,
                        color: RetroTheme.itemDivider,
                      ),
                      itemBuilder: (context, index) {
                        final audio = _audios[index];
                        final isCurrent = _audioService.currentTrack?.id == audio.id;
                        final isThisPlaying = isCurrent && _audioService.isPlaying;
                        final isThisBuffering = isCurrent && _audioService.isBuffering;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (isCurrent) {
                              _audioService.togglePlayPause();
                            } else {
                              _audioService.playTrack(audio, playlist: _audios);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            color: isCurrent
                                ? const Color(0xFFEDF4FA)
                                : (index.isOdd ? const Color(0xFFFAFBFC) : Colors.white),
                            child: Row(
                              children: [
                                // Play/Pause circular button
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isThisPlaying
                                        ? const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0xFF2A6099), Color(0xFF1B426E)],
                                          )
                                        : const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0xFF4C75A3), Color(0xFF2A5280)],
                                          ),
                                    border: Border.all(
                                      color: const Color(0xFF1B3D66),
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        offset: Offset(0, 1),
                                        blurRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: isThisBuffering
                                      ? const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          isThisPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Title & Artist
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        audio.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? const Color(0xFF1E62B3)
                                              : RetroTheme.textPrimary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        audio.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: RetroTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Duration
                                Text(
                                  _formatDuration(audio.duration),
                                  style: TextStyle(
                                    color: isCurrent
                                        ? const Color(0xFF1E62B3)
                                        : RetroTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_audiosLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: RetroLoadingIndicator(size: 24)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Common Header
  Widget _buildSectionHeader({
    required String title,
    required int count,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFE9EDF2),
        border: Border(
          bottom: BorderSide(color: Color(0xFFCCD4DE), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF455A73),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5A7A9F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }



  Widget _buildEmptyState({required IconData icon, required String text}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: const Color(0xFF8C9BAE)),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: RetroTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({required String title, required VoidCallback onRetry}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD6DCE5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF8B98A7),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RetroTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: RetroTheme.vkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaKeepAlive extends StatefulWidget {
  final Widget child;
  const _MediaKeepAlive({required this.child});

  @override
  State<_MediaKeepAlive> createState() => _MediaKeepAliveState();
}

class _MediaKeepAliveState extends State<_MediaKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

