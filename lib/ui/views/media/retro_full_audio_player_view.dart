import 'package:flutter/material.dart' hide RepeatMode;

import '../../../core/models/attachment.dart';
import '../../../core/services/audio_player_service.dart';
import '../../widgets/retro_app_bar.dart';

class RetroFullAudioPlayerView extends StatefulWidget {
  const RetroFullAudioPlayerView({super.key});

  static bool _isOpen = false;

  /// Opens the full-screen player with a smooth slide-up animation.
  static Future<void> open(BuildContext context) async {
    if (_isOpen || !context.mounted) return;
    _isOpen = true;
    try {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const RetroFullAudioPlayerView();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  State<RetroFullAudioPlayerView> createState() => _RetroFullAudioPlayerViewState();
}

class _RetroFullAudioPlayerViewState extends State<RetroFullAudioPlayerView> {
  final _service = RetroAudioPlayerService.instance;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isSeeking = false;
  double _seekFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
  }

  String _formatRemaining(Duration pos, Duration dur) {
    final remSec = (dur.inSeconds - pos.inSeconds).clamp(0, dur.inSeconds);
    return '-${_formatDuration(remSec)}';
  }

  String _plural(int count, String one, String few, String many) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final track = _service.currentTrack;
        final isPlaying = _service.isPlaying;
        final isBuffering = _service.isBuffering;

        final maxSec = _service.duration.inSeconds.toDouble();
        final curSec = _isSeeking
            ? (_seekFraction * (maxSec > 0 ? maxSec : 1.0))
            : _service.position.inSeconds.toDouble().clamp(0.0, maxSec > 0 ? maxSec : 1.0);

        final durObj = _service.duration;
        final posObj = _isSeeking ? Duration(seconds: curSec.toInt()) : _service.position;

        return Scaffold(
          backgroundColor: const Color(0xFF181C22),
          appBar: RetroAppBar(
            title: _currentPage == 0 ? 'Сейчас играет' : 'Список треков',
            showBackButton: false,
            leading: RetroHeaderButton(
              text: 'Свернуть',
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              RetroHeaderButton(
                icon: _currentPage == 0 ? Icons.queue_music_rounded : Icons.album_rounded,
                text: _currentPage == 0 ? 'Список' : 'Плеер',
                onPressed: () {
                  if (_currentPage == 0) {
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    _pageController.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              _buildPlayerPage(track, isPlaying, isBuffering, maxSec, curSec, durObj, posObj),
              _buildPlaylistPage(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerPage(
    AudioAttachment? track,
    bool isPlaying,
    bool isBuffering,
    double maxSec,
    double curSec,
    Duration durObj,
    Duration posObj,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2B323D),
              Color(0xFF1B2028),
              Color(0xFF101318),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Album Artwork Box with iOS 6 Gloss & Jewel Case Shadow
                    _buildAlbumArt(track?.coverUrl),

                    // Track Title & Artist
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track?.title ?? 'Нет активного трека',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Color(0xBB000000),
                                offset: Offset(0, 1.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track?.artist ?? 'OpenVK Музыка',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9FB2C8),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Scrubber / Position Slider
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 4,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: Color(0xFF4C8CD2),
                            inactiveTrackColor: Color(0xFF384351),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: maxSec > 0 ? curSec.clamp(0.0, maxSec) : 0.0,
                            max: maxSec > 0 ? maxSec : 1.0,
                            onChangeStart: (_) {
                              setState(() => _isSeeking = true);
                            },
                            onChanged: (val) {
                              setState(() {
                                _seekFraction = maxSec > 0 ? (val / maxSec) : 0.0;
                              });
                            },
                            onChangeEnd: (val) async {
                              _isSeeking = false;
                              await _service.seekTo(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(posObj.inSeconds),
                                style: const TextStyle(
                                  color: Color(0xFF90A1B5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatRemaining(posObj, durObj),
                                style: const TextStyle(
                                  color: Color(0xFF90A1B5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Main Playback Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Shuffle
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: _service.isShuffle ? const Color(0xFF4C8CD2) : Colors.white60,
                            size: 24,
                          ),
                          onPressed: _service.toggleShuffle,
                        ),
                        // Previous
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
                          onPressed: _service.previous,
                        ),
                        // Play/Pause Big Button
                        GestureDetector(
                          onTap: _service.togglePlayPause,
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF5B89BD), Color(0xFF264C7A)],
                              ),
                              border: Border.all(color: const Color(0xFF152A42), width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x60000000),
                                  offset: Offset(0, 3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: isBuffering
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                          ),
                        ),
                        // Next
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
                          onPressed: _service.next,
                        ),
                        // Repeat
                        IconButton(
                          icon: Icon(
                            _service.repeatMode == AudioRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: _service.repeatMode != AudioRepeatMode.off
                                ? const Color(0xFF4C8CD2)
                                : Colors.white60,
                            size: 24,
                          ),
                          onPressed: _service.toggleRepeat,
                        ),
                      ],
                    ),

                    // Volume Slider Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_down_rounded, color: Color(0xFF8B9CB2), size: 20),
                          Expanded(
                            child: SliderTheme(
                              data: const SliderThemeData(
                                trackHeight: 3,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: Color(0xFF8B9CB2),
                                inactiveTrackColor: Color(0xFF384351),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _service.volume,
                                onChanged: (val) => _service.setVolume(val),
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up_rounded, color: Color(0xFF8B9CB2), size: 20),
                        ],
                      ),
                    ),

                    // Swipe hint indicator
                    GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Свайп влево для списка треков',
                              style: TextStyle(
                                color: Color(0xFF7E92A8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 14, color: Color(0xFF7E92A8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistPage() {
    final playlist = _service.playlist;
    final currentTrack = _service.currentTrack;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B323D),
            Color(0xFF1B2028),
            Color(0xFF101318),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              children: [
                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2E3846), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_rounded, color: Color(0xFF8EA4BF), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Всего: ${playlist.length} ${_plural(playlist.length, 'трек', 'трека', 'треков')}',
                        style: const TextStyle(
                          color: Color(0xFFC7D5E5),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_service.isShuffle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x334C8CD2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x664C8CD2), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shuffle_rounded, color: Color(0xFF67A4E8), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Случайно',
                                style: TextStyle(
                                  color: Color(0xFF67A4E8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Playlist
                Expanded(
                  child: playlist.isEmpty
                      ? const Center(
                          child: Text(
                            'Очередь воспроизведения пуста',
                            style: TextStyle(color: Color(0xFF8B9CB2), fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: playlist.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Color(0xFF222B35),
                            indent: 48,
                          ),
                          itemBuilder: (context, index) {
                            final item = playlist[index];
                            final isCurrent = currentTrack?.id == item.id;
                            final isPlaying = isCurrent && _service.isPlaying;

                            return Material(
                              color: isCurrent ? const Color(0x284C8CD2) : Colors.transparent,
                              child: InkWell(
                                onTap: () => _service.playTrack(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 26,
                                        child: isCurrent
                                            ? Icon(
                                                isPlaying
                                                    ? Icons.volume_up_rounded
                                                    : Icons.pause_rounded,
                                                color: const Color(0xFF67A4E8),
                                                size: 18,
                                              )
                                            : Text(
                                                '${index + 1}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Color(0xFF6E8196),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.title.isNotEmpty ? item.title : 'Без названия',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrent
                                                    ? const Color(0xFF67A4E8)
                                                    : Colors.white,
                                                fontSize: 14,
                                                fontWeight: isCurrent
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.artist.isNotEmpty ? item.artist : 'Неизвестный исполнитель',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrent
                                                    ? const Color(0xFF90BBEA)
                                                    : const Color(0xFF8C9FB5),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (item.duration > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: Text(
                                            _formatDuration(item.duration),
                                            style: TextStyle(
                                              color: isCurrent
                                                  ? const Color(0xFF67A4E8)
                                                  : const Color(0xFF6E8196),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(String? coverUrl) {
    const double artSize = 250.0;

    return Center(
      child: Container(
        width: artSize,
        height: artSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF384351), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              offset: Offset(0, 8),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(),
              )
            else
              _buildPlaceholderArt(),
            // iOS 6 Diagonal Glass Gloss Effect
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: artSize * 0.5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x35FFFFFF),
                      Color(0x05FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C394A),
            Color(0xFF1E2835),
            Color(0xFF121A24),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Color(0xFF8EA4BF),
          size: 110,
        ),
      ),
    );
  }
}
