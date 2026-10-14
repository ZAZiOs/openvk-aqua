import 'package:flutter/material.dart';

import '../../../../core/models/user.dart';

class WallCountersGrid extends StatelessWidget {
  final UserCounters counters;
  final ValueChanged<String>? onCounterTap;

  const WallCountersGrid({
    super.key,
    required this.counters,
    this.onCounterTap,
  });

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
    final items = [
      _CounterItem(
        count: counters.friends,
        label: _plural(counters.friends, 'Друг', 'Друга', 'Друзей'),
        keyId: 'friends',
      ),
      _CounterItem(
        count: counters.groups,
        label: _plural(counters.groups, 'Группа', 'Группы', 'Групп'),
        keyId: 'groups',
      ),
      _CounterItem(
        count: counters.followers,
        label: _plural(counters.followers, 'Подписчик', 'Подписчика', 'Подписчиков'),
        keyId: 'followers',
      ),
      _CounterItem(
        count: counters.photos,
        label: _plural(counters.photos, 'Фотография', 'Фотографии', 'Фотографий'),
        keyId: 'photos',
      ),
      _CounterItem(
        count: counters.videos,
        label: _plural(counters.videos, 'Видеозапись', 'Видеозаписи', 'Видеозаписей'),
        keyId: 'videos',
      ),
      _CounterItem(
        count: counters.audios,
        label: _plural(counters.audios, 'Аудиозапись', 'Аудиозаписи', 'Аудиозаписей'),
        keyId: 'audios',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTile(items[0])),
            const SizedBox(width: 6),
            Expanded(child: _buildTile(items[1])),
            const SizedBox(width: 6),
            Expanded(child: _buildTile(items[2])),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildTile(items[3])),
            const SizedBox(width: 6),
            Expanded(child: _buildTile(items[4])),
            const SizedBox(width: 6),
            Expanded(child: _buildTile(items[5])),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(_CounterItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCounterTap != null ? () => onCounterTap!(item.keyId) : null,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2B3947).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: const Color(0xFF2E3946).withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${item.count}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD4E0EC),
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 1),
                      blurRadius: 1.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF71879D),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterItem {
  final int count;
  final String label;
  final String keyId;

  const _CounterItem({
    required this.count,
    required this.label,
    required this.keyId,
  });
}
