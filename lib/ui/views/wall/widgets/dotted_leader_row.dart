import 'package:flutter/material.dart';

class DottedLeaderRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? valueColor;
  final Color? linkColor;
  final Color? dotsColor;

  const DottedLeaderRow({
    super.key,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
    this.labelColor,
    this.valueColor,
    this.linkColor,
    this.dotsColor,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final actualLabelColor = labelColor ?? const Color(0xFF869EB5);
    final actualDotsColor = dotsColor ?? const Color(0xFF384A5C);
    final actualValueColor = valueColor ?? const Color(0xFFCAD7E5);
    final actualLinkColor = linkColor ?? const Color(0xFF6DAAE6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: actualLabelColor,
              fontWeight: FontWeight.w500,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 16,
              child: CustomPaint(
                painter: _DottedLeaderPainter(color: actualDotsColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: isLink ? actualLinkColor : actualValueColor,
                decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                decorationColor: actualLinkColor,
                fontWeight: isLink ? FontWeight.w600 : FontWeight.w500,
                shadows: const [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLeaderPainter extends CustomPainter {
  final Color color;

  const _DottedLeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const dotSpacing = 5.5;
    const dotRadius = 0.85;
    final y = size.height / 2;

    for (double x = 2.0; x < size.width - 2.0; x += dotSpacing) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}
