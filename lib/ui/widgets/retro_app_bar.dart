import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

class RetroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;

  final double cornerRadius;

  const RetroAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.bottom,
    this.cornerRadius = 8.0,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RetroTheme.headerGradient,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: kToolbarHeight - 2,
                      child: NavigationToolbar(
                        leading:
                            leading ??
                            (showBackButton
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _buildRetroBackButton(context),
                                  )
                                : null),
                        middle:
                            titleWidget ??
                            (title != null
                                ? Text(
                                    title!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x99000000),
                                          offset: Offset(0, -1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                  )
                                : null),
                        trailing: actions != null
                            ? Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions!,
                                ),
                              )
                            : null,
                        centerMiddle: true,
                      ),
                    ),

                    Container(height: 1, color: RetroTheme.headerBorder),
                    if (bottom != null) bottom!,
                  ],
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RetroTopHighlightPainter(
                    cornerRadius: cornerRadius,
                    color: Colors.white.withValues(alpha: 0.30),
                    strokeWidth: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetroBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: InkWell(
        onTap: onBackPressed ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF1B3D66)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4C75A3), Color(0xFF2A5280)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'Назад',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
    );
  }
}

class RetroMenuButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RetroMenuButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 34,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFF1B3D66), width: 1),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4C75A3), Color(0xFF2A5280)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetroTopHighlightPainter extends CustomPainter {
  final double cornerRadius;
  final Color color;
  final double strokeWidth;

  const _RetroTopHighlightPainter({
    required this.cornerRadius,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfStroke = strokeWidth / 2;
    final r = cornerRadius;
    final fadeHeight = r + 7.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.25, 1.0],
        colors: [color, color, color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, fadeHeight));

    final path = Path();

    path.moveTo(halfStroke, fadeHeight);
    path.lineTo(halfStroke, r);
    path.arcToPoint(
      Offset(r, halfStroke),
      radius: Radius.circular(r - halfStroke),
      clockwise: true,
    );
    path.lineTo(size.width - r, halfStroke);
    path.arcToPoint(
      Offset(size.width - halfStroke, r),
      radius: Radius.circular(r - halfStroke),
      clockwise: true,
    );
    path.lineTo(size.width - halfStroke, fadeHeight);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RetroTopHighlightPainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
