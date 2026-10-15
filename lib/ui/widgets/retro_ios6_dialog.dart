import 'package:flutter/material.dart';

Future<bool?> showIos6ConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = 'Отмена',
  String confirmText = 'Открепить',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0x73000000),
    builder: (ctx) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xF01D2D42),
                  Color(0xF80E1826),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: Stack(
                children: [
                  // Classic iOS 6 Glass Gloss highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 55,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(0, -1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD6E3F2),
                              fontSize: 13.5,
                              height: 1.35,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, -1),
                                  blurRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _Ios6DialogButton(
                                text: cancelText,
                                isPrimary: false,
                                isDestructive: false,
                                onPressed: () => Navigator.of(ctx).pop(false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Ios6DialogButton(
                                text: confirmText,
                                isPrimary: true,
                                isDestructive: isDestructive,
                                onPressed: () => Navigator.of(ctx).pop(true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Ios6DialogButton extends StatefulWidget {
  final String text;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _Ios6DialogButton({
    required this.text,
    required this.isPrimary,
    required this.isDestructive,
    required this.onPressed,
  });

  @override
  State<_Ios6DialogButton> createState() => _Ios6DialogButtonState();
}

class _Ios6DialogButtonState extends State<_Ios6DialogButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors;
    final Color borderColor;

    if (widget.isDestructive) {
      colors = _isPressed
          ? const [Color(0xFF5A1414), Color(0xFF380808)]
          : const [Color(0xFF962D2D), Color(0xFF641818)];
      borderColor = const Color(0xFF3D0E0E);
    } else if (widget.isPrimary) {
      colors = _isPressed
          ? const [Color(0xFF21426B), Color(0xFF132943)]
          : const [Color(0xFF3B6799), Color(0xFF21426B)];
      borderColor = const Color(0xFF142944);
    } else {
      colors = _isPressed
          ? const [Color(0xFF2A313D), Color(0xFF1B2028)]
          : const [Color(0xFF5A6375), Color(0xFF2A313D)];
      borderColor = const Color(0xFF1B2028);
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 40),
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isPressed ? 0.4 : 0.25),
              offset: Offset(0, _isPressed ? 0.5 : 1.5),
              blurRadius: _isPressed ? 1 : 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(0, -1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
