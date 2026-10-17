import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/media_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/audio_playlist.dart';
import '../../../core/services/audio_player_service.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import 'audio_playlist_detail_view.dart';
import 'retro_audio_mini_player.dart';

class AudioPlaylistsView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final int? ownerId;

  const AudioPlaylistsView({
    super.key,
    required this.client,
    required this.account,
    this.ownerId,
  });

  static Future<void> open(
    BuildContext context, {
    required OpenVkClient client,
    required SavedAccount account,
    int? ownerId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AudioPlaylistsView(
          client: client,
          account: account,
          ownerId: ownerId,
        ),
      ),
    );
  }

  @override
  State<AudioPlaylistsView> createState() => _AudioPlaylistsViewState();
}

class _AudioPlaylistsViewState extends State<AudioPlaylistsView> {
  late final MediaHandler _mediaHandler;
  final _audioService = RetroAudioPlayerService.instance;
  final ScrollController _scrollController = ScrollController();

  final List<AudioPlaylist> _playlists = [];
  int _playlistsCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  int? _quickPlayingPlaylistId;

  int get _targetId => widget.ownerId ?? widget.account.userId;

  @override
  void initState() {
    super.initState();
    _mediaHandler = MediaHandler(widget.client);
    _scrollController.addListener(_onScroll);
    _loadPlaylists();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 300 && !_isLoading && !_isLoadingMore && _hasMore) {
      _loadPlaylists(more: true);
    }
  }

  Future<void> _loadPlaylists({bool more = false, bool forceRefresh = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (more) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _hasError = false;
      }
    });

    final offset = more ? _playlists.length : 0;
    final res = await _mediaHandler.getAlbums(
      ownerId: _targetId,
      count: 40,
      offset: offset,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _playlistsCount = data.count > 0 ? data.count : (more ? _playlists.length + data.items.length : data.items.length);
        if (more) {
          _playlists.addAll(data.items);
        } else {
          _playlists
            ..clear()
            ..addAll(data.items);
        }
        _hasMore = data.items.isNotEmpty && _playlists.length < _playlistsCount;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!more && _playlists.isEmpty) {
          _hasError = true;
        }
      });
    }
  }

  Future<void> _quickPlayPlaylist(AudioPlaylist playlist) async {
    if (_quickPlayingPlaylistId == playlist.id) return;

    setState(() {
      _quickPlayingPlaylistId = playlist.id;
    });

    try {
      final res = await _mediaHandler.getAudios(
        ownerId: playlist.ownerId,
        albumId: playlist.id,
        count: 50,
        offset: 0,
      );

      if (!mounted) return;

      if (res.isSuccess && res.dataOrNull != null && res.dataOrNull!.items.isNotEmpty) {
        final tracks = res.dataOrNull!.items;
        await _audioService.playTrack(tracks.first, playlist: tracks);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('В этом плейлисте нет аудиозаписей'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _quickPlayingPlaylistId = null;
        });
      }
    }
  }

  String _formatTotalDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '$h ч $m мин';
    }
    return '$m мин';
  }

  String _pluralTracks(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) {
      return 'аудиозаписей';
    }
    if (mod10 == 1) {
      return 'аудиозапись';
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return 'аудиозаписи';
    }
    return 'аудиозаписей';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopWide = screenWidth >= 850;

    final body = Column(
      children: [
        Expanded(
          child: _hasError && _playlists.isEmpty
              ? _buildErrorState()
              : _isLoading && _playlists.isEmpty
                  ? const Center(child: RetroLoadingIndicator(size: 32))
                  : _playlists.isEmpty
                      ? RetroPullToRefresh(
                          onRefresh: () => _loadPlaylists(forceRefresh: true),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.45,
                                child: _buildEmptyState(),
                              ),
                            ],
                          ),
                        )
                      : RetroPullToRefresh(
                          onRefresh: () => _loadPlaylists(forceRefresh: true),
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: _buildSectionHeader(
                                  count: _playlistsCount > 0 ? _playlistsCount : _playlists.length,
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildPlaylistCard(_playlists[index]);
                                    },
                                    childCount: _playlists.length,
                                  ),
                                ),
                              ),
                              if (_isLoadingMore)
                                const SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(child: RetroLoadingIndicator(size: 24)),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
        const RetroAudioMiniPlayer(),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFCAD4DF),
      appBar: const RetroAppBar(
        showBackButton: true,
        title: 'Плейлисты',
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isDesktopWide ? 850 : double.infinity),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            border: isDesktopWide
                ? const Border.symmetric(
                    vertical: BorderSide(
                      color: Color(0xFFB8C5D3),
                      width: 1,
                    ),
                  )
                : null,
            boxShadow: isDesktopWide
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required int count}) {
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
          const Text(
            'Плейлисты',
            style: TextStyle(
              color: Color(0xFF455A73),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          if (count > 0)
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
      ),
    );
  }

  Widget _buildPlaylistCard(AudioPlaylist playlist) {
    final coverUrl = playlist.getFullCoverUrl(widget.client.baseUrl);
    final isQuickPlaying = _quickPlayingPlaylistId == playlist.id;
    final durationStr = _formatTotalDuration(playlist.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AudioPlaylistDetailView.open(
              context,
              client: widget.client,
              account: widget.account,
              playlist: playlist,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Cover
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFE2E7ED),
                    border: Border.all(color: const Color(0xFFB8C5D3), width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: coverUrl != null
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildCoverPlaceholder(),
                        )
                      : _buildCoverPlaceholder(),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RetroTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (playlist.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          playlist.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: RetroTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${playlist.size} ${_pluralTracks(playlist.size)}',
                            style: const TextStyle(
                              color: Color(0xFF5A7A9F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (durationStr.isNotEmpty) ...[
                            const Text(
                              '•',
                              style: TextStyle(color: Color(0xFF8B98A7), fontSize: 12),
                            ),
                            Text(
                              durationStr,
                              style: const TextStyle(
                                color: RetroTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (playlist.listens > 0) ...[
                            const Text(
                              '•',
                              style: TextStyle(color: Color(0xFF8B98A7), fontSize: 12),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.headphones_rounded, size: 12, color: Color(0xFF8B98A7)),
                                const SizedBox(width: 2),
                                Text(
                                  '${playlist.listens}',
                                  style: const TextStyle(
                                    color: RetroTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Play button right on card
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _quickPlayPlaylist(playlist),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1B3D66), width: 1),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4C75A3), Color(0xFF2A5280)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isQuickPlaying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A7A9F), Color(0xFF3B5678)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.album_rounded,
          color: Colors.white70,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music_rounded, size: 54, color: Color(0xFF8C9BAE)),
          SizedBox(height: 12),
          Text(
            'Плейлистов пока нет',
            style: TextStyle(
              color: RetroTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
            const Icon(Icons.cloud_off_rounded, color: Color(0xFF8B98A7), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить плейлисты',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RetroTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => _loadPlaylists(forceRefresh: true),
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
