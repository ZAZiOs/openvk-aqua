import 'package:flutter/material.dart';

import '../../../core/api/auth_handler.dart';
import '../../../core/api/media_handler.dart';
import '../../../core/api/openvk_client.dart';
import '../../../core/models/attachment.dart';
import '../../../core/models/audio_playlist.dart';
import '../../../core/services/audio_player_service.dart';
import '../../theme/retro_theme.dart';
import '../../widgets/retro_app_bar.dart';
import '../../widgets/retro_loading_indicator.dart';
import '../../widgets/retro_pull_to_refresh.dart';
import 'retro_audio_mini_player.dart';

class AudioPlaylistDetailView extends StatefulWidget {
  final OpenVkClient client;
  final SavedAccount account;
  final AudioPlaylist playlist;

  const AudioPlaylistDetailView({
    super.key,
    required this.client,
    required this.account,
    required this.playlist,
  });

  static Future<void> open(
    BuildContext context, {
    required OpenVkClient client,
    required SavedAccount account,
    required AudioPlaylist playlist,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AudioPlaylistDetailView(
          client: client,
          account: account,
          playlist: playlist,
        ),
      ),
    );
  }

  @override
  State<AudioPlaylistDetailView> createState() => _AudioPlaylistDetailViewState();
}

class _AudioPlaylistDetailViewState extends State<AudioPlaylistDetailView> {
  late final MediaHandler _mediaHandler;
  final _audioService = RetroAudioPlayerService.instance;
  final ScrollController _scrollController = ScrollController();

  final List<AudioAttachment> _tracks = [];
  int _tracksCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _mediaHandler = MediaHandler(widget.client);
    _tracksCount = widget.playlist.size;
    _scrollController.addListener(_onScroll);
    _loadTracks();
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
      _loadTracks(more: true);
    }
  }

  Future<void> _loadTracks({bool more = false, bool forceRefresh = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (more) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _hasError = false;
      }
    });

    final offset = more ? _tracks.length : 0;
    final res = await _mediaHandler.getAudios(
      ownerId: widget.playlist.ownerId,
      albumId: widget.playlist.id,
      count: 30,
      offset: offset,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;

    if (res.isSuccess && res.dataOrNull != null) {
      final data = res.dataOrNull!;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _tracksCount = data.count > 0 ? data.count : (more ? _tracks.length + data.items.length : data.items.length);
        if (more) {
          _tracks.addAll(data.items);
        } else {
          _tracks
            ..clear()
            ..addAll(data.items);
        }
        _hasMore = data.items.isNotEmpty && _tracks.length < _tracksCount;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!more && _tracks.isEmpty) {
          _hasError = true;
        }
      });
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_tracks.isEmpty) return;
    if (shuffle) {
      final list = List<AudioAttachment>.from(_tracks)..shuffle();
      _audioService.playTrack(list.first, playlist: list);
    } else {
      _audioService.playTrack(_tracks.first, playlist: _tracks);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopWide = screenWidth >= 850;

    final body = Column(
      children: [
        Expanded(
          child: _hasError && _tracks.isEmpty
              ? _buildErrorState()
              : _isLoading && _tracks.isEmpty
                  ? const Center(child: RetroLoadingIndicator(size: 32))
                  : RetroPullToRefresh(
                      onRefresh: () => _loadTracks(forceRefresh: true),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeaderCard()),
                          if (_tracks.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          else ...[
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
                                  child: ListenableBuilder(
                                    listenable: _audioService,
                                    builder: (context, _) {
                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _tracks.length,
                                        separatorBuilder: (context, index) => const Divider(
                                          height: 1,
                                          thickness: 0.8,
                                          color: RetroTheme.itemDivider,
                                        ),
                                        itemBuilder: (context, index) {
                                          return _buildTrackTile(_tracks[index], index);
                                        },
                                      );
                                    },
                                  ),
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
                        ],
                      ),
                    ),
        ),
        const RetroAudioMiniPlayer(),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFCAD4DF),
      appBar: RetroAppBar(
        showBackButton: true,
        title: widget.playlist.title,
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

  Widget _buildHeaderCard() {
    final coverUrl = widget.playlist.getFullCoverUrl(widget.client.baseUrl);
    final count = _tracksCount > 0 ? _tracksCount : _tracks.length;
    final durationStr = _formatTotalDuration(widget.playlist.length);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album Cover
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFFE2E7ED),
                  border: Border.all(color: const Color(0xFFB8C5D3), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
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
              // Meta info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      style: const TextStyle(
                        color: RetroTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.playlist.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.playlist.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RetroTheme.textSecondary,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EDF2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCCD4DE), width: 0.8),
                          ),
                          child: Text(
                            '$count ${_pluralTracks(count)}',
                            style: const TextStyle(
                              color: Color(0xFF455A73),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (durationStr.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EDF2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCCD4DE), width: 0.8),
                            ),
                            child: Text(
                              durationStr,
                              style: const TextStyle(
                                color: Color(0xFF455A73),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (widget.playlist.listens > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EDF2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCCD4DE), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.headphones_rounded, size: 12, color: Color(0xFF5A7A9F)),
                                const SizedBox(width: 3),
                                Text(
                                  '${widget.playlist.listens}',
                                  style: const TextStyle(
                                    color: Color(0xFF455A73),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
          // Action Buttons: "Воспроизвести всё" and "Перемешать"
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _tracks.isNotEmpty ? () => _playAll(shuffle: false) : null,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
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
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 19),
                        SizedBox(width: 5),
                        Text(
                          'Воспроизвести всё',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Color(0x80000000),
                                offset: Offset(0, -1),
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
              GestureDetector(
                onTap: _tracks.isNotEmpty ? () => _playAll(shuffle: true) : null,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: const Color(0xFFF2F4F7),
                    border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle_rounded, color: Color(0xFF455A73), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Перемешать',
                        style: TextStyle(
                          color: Color(0xFF455A73),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
          size: 46,
        ),
      ),
    );
  }

  Widget _buildTrackTile(AudioAttachment audio, int index) {
    final isCurrent = _audioService.currentTrack?.id == audio.id;
    final isThisPlaying = isCurrent && _audioService.isPlaying;
    final isThisBuffering = isCurrent && _audioService.isBuffering;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isCurrent) {
          _audioService.togglePlayPause();
        } else {
          _audioService.playTrack(audio, playlist: _tracks);
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
              width: 30,
              height: 30,
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
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : Icon(
                      isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
            ),
            const SizedBox(width: 12),
            // Track Info
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
                      color: isCurrent ? const Color(0xFF1E62B3) : RetroTheme.textPrimary,
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
                color: isCurrent ? const Color(0xFF1E62B3) : RetroTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.queue_music_rounded, size: 52, color: Color(0xFF8C9BAE)),
          SizedBox(height: 12),
          Text(
            'В этом плейлисте пока нет треков',
            style: TextStyle(
              color: RetroTheme.textSecondary,
              fontSize: 14.5,
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
              'Не удалось загрузить треки плейлиста',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RetroTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => _loadTracks(forceRefresh: true),
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
}
