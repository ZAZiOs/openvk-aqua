import 'package:flutter/material.dart';

enum RetroTab { news, wall, messages, friends, media }

class RetroBottomBar extends StatelessWidget {
  final RetroTab? currentTab;
  final ValueChanged<RetroTab> onTabSelected;
  final int unreadMessagesCount;

  const RetroBottomBar({
    super.key,
    this.currentTab,
    required this.onTabSelected,
    this.unreadMessagesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (
        tab: RetroTab.news,
        title: 'Новости',
        activeIcon: 'assets/navbar/ico/news_a.png',
        inactiveIcon: 'assets/navbar/ico/news.png',
        badge: 0,
      ),
      (
        tab: RetroTab.wall,
        title: 'Стена',
        activeIcon: 'assets/navbar/ico/wall_a.png',
        inactiveIcon: 'assets/navbar/ico/wall.png',
        badge: 0,
      ),
      (
        tab: RetroTab.messages,
        title: 'Сообщения',
        activeIcon: 'assets/navbar/ico/msg_a.png',
        inactiveIcon: 'assets/navbar/ico/msg.png',
        badge: unreadMessagesCount,
      ),
      (
        tab: RetroTab.friends,
        title: 'Друзья',
        activeIcon: 'assets/navbar/ico/friends_a.png',
        inactiveIcon: 'assets/navbar/ico/friends.png',
        badge: 0,
      ),
      (
        tab: RetroTab.media,
        title: 'Медиа',
        activeIcon: 'assets/navbar/ico/media_a.png',
        inactiveIcon: 'assets/navbar/ico/media.png',
        badge: 0,
      ),
    ];

    final double bottomPadding = MediaQuery.paddingOf(context).bottom;

    final Widget barContent = Container(
      height: 58,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/navbar/navbar.png'),
          fit: BoxFit.fill,
        ),
        border: Border(top: BorderSide(color: Color(0xFF383838), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const tabCount = 5;
            final tabWidth = constraints.maxWidth / tabCount;
            final activeIndex = currentTab != null
                ? RetroTab.values.indexOf(currentTab!).clamp(0, tabCount - 1)
                : -1;

            return SizedBox(
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (activeIndex >= 0)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      left: activeIndex * tabWidth,
                      width: tabWidth,
                      top: -2,
                      bottom: -2,
                      child: Center(
                        child: Image.asset(
                          'assets/navbar/ico/select_window.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                  Row(
                    children: tabs.map((cfg) {
                      return _buildTabItem(
                        tab: cfg.tab,
                        title: cfg.title,
                        activeIcon: cfg.activeIcon,
                        inactiveIcon: cfg.inactiveIcon,
                        badgeCount: cfg.badge,
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (bottomPadding > 0) {
      return Container(
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            barContent,
            SizedBox(height: bottomPadding),
          ],
        ),
      );
    }

    return barContent;
  }

  Widget _buildTabItem({
    required RetroTab tab,
    required String title,
    required String activeIcon,
    required String inactiveIcon,
    int badgeCount = 0,
  }) {
    final isSelected = currentTab != null && tab == currentTab;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabSelected(tab),
        child: Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Image.asset(
                  isSelected ? activeIcon : inactiveIcon,
                  fit: BoxFit.contain,
                ),
              ),

              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        offset: const Offset(0, 1),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              if (badgeCount > 0)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(badgeCount < 10 ? 13.0 : 16.0, -13.0),
                      child: _buildBadge(badgeCount),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    final text = count > 99 ? '99+' : count.toString();
    final isSingleDigit = count < 10;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFFF4940),
        Color(0xFFBA0707),
      ],
    );

    final border = Border.all(
      color: Colors.white,
      width: 2.0,
    );

    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        offset: const Offset(0, 1.5),
        blurRadius: 3,
      ),
    ];

    final textWidget = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: isSingleDigit ? 10.5 : 9.5,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: isSingleDigit ? 0 : -0.3,
      ),
    );

    if (isSingleDigit) {
      return Container(
        width: 19,
        height: 19,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          border: border,
          boxShadow: shadow,
        ),
        child: textWidget,
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 23,
        minHeight: 19,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: gradient,
        border: border,
        boxShadow: shadow,
      ),
      child: textWidget,
    );
  }
}
