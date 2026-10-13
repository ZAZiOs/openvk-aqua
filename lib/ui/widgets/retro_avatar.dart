import 'package:flutter/material.dart';

class RetroAvatar extends StatelessWidget {
  final String? url;
  final String fallbackText;
  final double size;
  final bool isOnline;

  const RetroAvatar({
    super.key,
    this.url,
    this.fallbackText = '?',
    this.size = 48,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final validUrl =
        url != null && url!.trim().isNotEmpty && url!.startsWith('http');

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
            child: validUrl
                ? Image.network(
                    url!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
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

  Widget _buildPlaceholder() {
    final letter = fallbackText.trim().isNotEmpty
        ? fallbackText.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      color: const Color(0xFF9FB0C2),
      child: Center(
        child: Text(
          letter,
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
