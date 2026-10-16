import 'package:flutter/material.dart';


class RetroStatusBadge extends StatelessWidget {
  final bool isSuccess;
  final VoidCallback? onTap;
  final double size;

  const RetroStatusBadge({
    super.key,
    required this.isSuccess,
    this.onTap,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final badgeWidget = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              offset: const Offset(0, 1.5),
              blurRadius: 3.0,
            )
          ],
          gradient: isSuccess
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF67DD48),
                    Color(0xFF38B923),
                    Color(0xFF1E8A10),
                  ],
                  stops: [0.0, 0.48, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEE5348),
                    Color(0xFFD42C20),
                    Color(0xFFA8160C),
                  ],
                  stops: [0.0, 0.48, 1.0],
                ),
        ),
        child: ClipOval(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size * 0.48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Icon(
                  isSuccess ? Icons.check_rounded : Icons.close_rounded,
                  size: size * 0.58,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0x66000000),
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
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }
}
