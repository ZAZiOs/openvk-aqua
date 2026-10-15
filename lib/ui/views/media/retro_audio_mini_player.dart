import 'package:flutter/material.dart';

import '../../../core/services/audio_player_service.dart';
import 'retro_full_audio_player_view.dart';

class RetroAudioMiniPlayer extends StatefulWidget {
  const RetroAudioMiniPlayer({super.key});

  @override
  State<RetroAudioMiniPlayer> createState() => _RetroAudioMiniPlayerState();
}

class _RetroAudioMiniPlayerState extends State<RetroAudioMiniPlayer> {
  final _service = RetroAudioPlayerService.instance;
  bool _isSeeking = false;
  double _seekFraction = 0.0;
  double _dragStartY = 0.0;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
  }

  String _formatDurationObj(Duration d) {
    return _formatDuration(d.inSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final track = _service.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final maxSec = _service.duration.inSeconds.toDouble();
        final curSec = _isSeeking
            ? (_seekFraction * (maxSec > 0 ? maxSec : 1.0))
            : _service.position.inSeconds.toDouble().clamp(0.0, maxSec > 0 ? maxSec : 1.0);

        final isPlaying = _service.isPlaying;
        final isBuffering = _service.isBuffering;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) {
            _dragStartY = details.globalPosition.dy;
          },
          onVerticalDragEnd: (details) {
            final dy = details.primaryVelocity ?? 0;
            if (dy < -200) {
              RetroFullAudioPlayerView.open(context);
            }
          },
          onVerticalDragUpdate: (details) {
            if (_dragStartY - details.globalPosition.dy > 50) {
              _dragStartY = details.globalPosition.dy;
              RetroFullAudioPlayerView.open(context);
            }
          },
          onTap: () => RetroFullAudioPlayerView.open(context),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF38404B),
                  Color(0xFF22272E),
                  Color(0xFF161A1F),
                ],
              ),
              border: Border(
                top: BorderSide(color: Color(0xFF5A6675), width: 1),
                bottom: BorderSide(color: Color(0xFF0F1215), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Track Icon Box / Album Art thumbnail
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF4C75A3), Color(0xFF23446D)],
                          ),
                          border: Border.all(color: const Color(0xFF182E49), width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: track.coverUrl != null && track.coverUrl!.isNotEmpty
                            ? Image.network(
                                track.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                      const SizedBox(width: 10),
                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Color(0x99000000),
                                    offset: Offset(0, -1),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB5C1D0),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pull-up hint / chevron
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                      // Player Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                            onPressed: _service.previous,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _service.togglePlayPause,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF5B89BD), Color(0xFF264C7A)],
                                ),
                                border: Border.all(color: const Color(0xFF142C48), width: 1),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x44000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: isBuffering
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
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                            onPressed: _service.next,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Scrubber Slider Row
                  Row(
                    children: [
                      Text(
                        _formatDurationObj(_isSeeking ? Duration(seconds: curSec.toInt()) : _service.position),
                        style: const TextStyle(
                          color: Color(0xFF9AA7B6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: const Color(0xFF4C8CD2),
                            inactiveTrackColor: const Color(0xFF384351),
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
                      ),
                      Text(
                        _formatDurationObj(_service.duration),
                        style: const TextStyle(
                          color: Color(0xFF9AA7B6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
