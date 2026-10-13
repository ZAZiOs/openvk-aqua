import 'package:flutter/material.dart';

import '../../core/api/auth_handler.dart';
import 'retro_avatar.dart';
import 'retro_bottom_bar.dart';

enum RetroSection {
  profile('Стена'),
  friends('Друзья'),
  photos('Фотографии'),
  videos('Видеозаписи'),
  audio('Аудиозаписи'),
  messages('Сообщения'),
  groups('Группы'),
  news('Новости'),
  feedback('Ответы'),
  bookmarks('Закладки'),
  settings('Настройки');

  final String title;
  const RetroSection(this.title);

  RetroTab? get bottomTab {
    switch (this) {
      case RetroSection.news:
        return RetroTab.news;
      case RetroSection.profile:
        return RetroTab.wall;
      case RetroSection.messages:
        return RetroTab.messages;
      case RetroSection.friends:
        return RetroTab.friends;
      case RetroSection.audio:
        return RetroTab.media;
      default:
        return null;
    }
  }

  static RetroSection fromTab(RetroTab tab) {
    switch (tab) {
      case RetroTab.news:
        return RetroSection.news;
      case RetroTab.wall:
        return RetroSection.profile;
      case RetroTab.messages:
        return RetroSection.messages;
      case RetroTab.friends:
        return RetroSection.friends;
      case RetroTab.media:
        return RetroSection.audio;
    }
  }
}

class RetroSidebarItemData {
  final String title;
  final IconData icon;
  final RetroSection section;

  const RetroSidebarItemData({
    required this.title,
    required this.icon,
    required this.section,
  });
}

class RetroSidebar extends StatelessWidget {
  final SavedAccount account;
  final VoidCallback? onLogout;
  final RetroSection currentSection;
  final ValueChanged<RetroSection> onSectionSelected;

  const RetroSidebar({
    super.key,
    required this.account,
    this.onLogout,
    required this.currentSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = <RetroSidebarItemData>[
      RetroSidebarItemData(
        title: 'Друзья',
        icon: Icons.person,
        section: RetroSection.friends,
      ),
      RetroSidebarItemData(
        title: 'Фотографии',
        icon: Icons.camera_alt,
        section: RetroSection.photos,
      ),
      RetroSidebarItemData(
        title: 'Видеозаписи',
        icon: Icons.video_collection_outlined,
        section: RetroSection.videos,
      ),
      RetroSidebarItemData(
        title: 'Аудиозаписи',
        icon: Icons.music_note,
        section: RetroSection.audio,
      ),
      RetroSidebarItemData(
        title: 'Сообщения',
        icon: Icons.mail,
        section: RetroSection.messages,
      ),
      RetroSidebarItemData(
        title: 'Группы',
        icon: Icons.group,
        section: RetroSection.groups,
      ),
      RetroSidebarItemData(
        title: 'Новости',
        icon: Icons.chat_bubble,
        section: RetroSection.news,
      ),
      RetroSidebarItemData(
        title: 'Ответы',
        icon: Icons.forum,
        section: RetroSection.feedback,
      ),
      RetroSidebarItemData(
        title: 'Закладки',
        icon: Icons.star,
        section: RetroSection.bookmarks,
      ),
      RetroSidebarItemData(
        title: 'Настройки',
        icon: Icons.settings,
        section: RetroSection.settings,
      ),
    ];

    return Material(
      color: const Color(0xFF1E2631),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildProfileRow(context),
            for (final item in items) _buildMenuItem(context, item),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context) {
    final isSelected = currentSection == RetroSection.profile;

    return InkWell(
      onTap: () => onSectionSelected(RetroSection.profile),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF161D26) : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF131820), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            RetroAvatar(
              url: account.avatarUrl,
              fallbackText: account.name,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                account.name,
                style: const TextStyle(
                  color: Color(0xFFE8EEF5),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Color(0x99000000),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF384654),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, RetroSidebarItemData item) {
    final isSelected = item.section == currentSection;

    return InkWell(
      onTap: () => onSectionSelected(item.section),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF161D26) : Colors.transparent,
          border: const Border(
            top: BorderSide(color: Color(0xFF283442), width: 1),
            bottom: BorderSide(color: Color(0xFF131820), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(
                item.icon,
                size: 21,
                color: isSelected
                    ? const Color(0xFFB5C7D9)
                    : const Color(0xFF8E9BAA),
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 1,
                    color: Color(0x66000000),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFE8EEF5),
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 1,
                      color: Color(0x99000000),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(0xFF384654),
            ),
          ],
        ),
      ),
    );
  }
}
