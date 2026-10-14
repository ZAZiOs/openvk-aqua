import 'package:flutter/material.dart';

import '../../core/models/conversations_response.dart';
import 'retro_loading_indicator.dart';

class RetroChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final List<ChatMemberAvatarInfo>? members;
  final String fallbackText;
  final double size;
  final bool isOnline;

  const RetroChatAvatar({
    super.key,
    this.avatarUrl,
    this.members,
    this.fallbackText = '?',
    this.size = 50,
    this.isOnline = false,
  });

  static const List<Color> _palette = [
    Color(0xFF7E9BB8),
    Color(0xFF8F93BD),
    Color(0xFF82AFA5),
    Color(0xFFB59A7A),
    Color(0xFFB5808E),
    Color(0xFF919FAF),
  ];

  Color _colorForText(String text) {
    if (text.isEmpty) return _palette[0];
    final code = text.codeUnitAt(0);
    return _palette[code % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasSingleUrl = avatarUrl != null &&
        avatarUrl!.trim().isNotEmpty &&
        avatarUrl!.startsWith('http');

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x22000000), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
            color: const Color(0xFFD3D8DE),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: hasSingleUrl
                ? _buildSingleAvatar(avatarUrl!)
                : _buildAvatarContent(),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF6CC447),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleAvatar(String url) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: RetroLoadingIndicator(size: size * 0.4),
        );
      },
      errorBuilder: (_, _, _) => _buildPlaceholder(fallbackText),
    );
  }

  Widget _buildAvatarContent() {
    final validMembers = members?.take(4).toList();

    if (validMembers == null || validMembers.isEmpty) {
      return _buildPlaceholder(fallbackText);
    }

    if (validMembers.length == 1) {
      return _buildMemberCell(validMembers[0]);
    }

    if (validMembers.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMemberCell(validMembers[0])),
          Container(width: 1, color: Colors.white),
          Expanded(child: _buildMemberCell(validMembers[1])),
        ],
      );
    }

    if (validMembers.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildMemberCell(validMembers[0])),
          Container(width: 1, color: Colors.white),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildMemberCell(validMembers[1])),
                Container(height: 1, color: Colors.white),
                Expanded(child: _buildMemberCell(validMembers[2])),
              ],
            ),
          ),
        ],
      );
    }

    // 4 members grid
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMemberCell(validMembers[0])),
              Container(width: 1, color: Colors.white),
              Expanded(child: _buildMemberCell(validMembers[1])),
            ],
          ),
        ),
        Container(height: 1, color: Colors.white),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMemberCell(validMembers[2])),
              Container(width: 1, color: Colors.white),
              Expanded(child: _buildMemberCell(validMembers[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCell(ChatMemberAvatarInfo member) {
    final hasUrl = member.url != null &&
        member.url!.trim().isNotEmpty &&
        member.url!.startsWith('http');

    if (hasUrl) {
      return SizedBox.expand(
        child: Image.network(
          member.url!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildLetterCell(member.fallbackText),
        ),
      );
    }

    return _buildLetterCell(member.fallbackText);
  }

  Widget _buildLetterCell(String text) {
    final letter = text.trim().isNotEmpty
        ? text.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      color: _colorForText(text),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: (size * 0.24).clamp(8.0, 16.0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    final isGroupFallback = text == '?' || text.isEmpty;

    return Container(
      color: const Color(0xFF9FB0C2),
      child: Center(
        child: isGroupFallback
            ? Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: size * 0.55,
              )
            : Text(
                text.trim().substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
