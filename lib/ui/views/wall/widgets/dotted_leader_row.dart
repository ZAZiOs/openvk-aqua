import 'package:flutter/material.dart';

class DottedLeaderRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  const DottedLeaderRow({
    super.key,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8B9FB3),
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: SizedBox(
              height: 14,
              child: CustomPaint(
                painter: _DottedLeaderPainter(color: Color(0xFF3F546C)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: isLink ? const Color(0xFF6B9ED9) : const Color(0xFFC7D3E0),
                  decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: const Color(0xFF6B9ED9),
                  fontWeight: FontWeight.w500,
                ),
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
      ..strokeWidth = 1.0;

    const dotSpacing = 5.0;
    final y = size.height - 3.0;

    for (double x = 0; x < size.width; x += dotSpacing) {
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
}
