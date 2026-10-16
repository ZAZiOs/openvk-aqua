import 'package:flutter/material.dart';

/// An iOS 6 skeuomorphic scroll-to-bottom arrow button.
///
/// Features a glossy silver-glass gradient, crisp beveled borders,
/// top specular sheen, engraved letterpress chevron, pressed state,
/// and an optional retro badge for unread messages.
class RetroScrollToBottomButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int unreadCount;
  final double size;

  const RetroScrollToBottomButton({
    super.key,
    required this.onPressed,
    this.unreadCount = 0,
    this.size = 38.0,
  });

  @override
  State<RetroScrollToBottomButton> createState() =>
      _RetroScrollToBottomButtonState();
}

class _RetroScrollToBottomButtonState extends State<RetroScrollToBottomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _isPressed
                    ? const Color(0xFF6B7E93)
                    : const Color(0xFF8B9CAA),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x38000000),
                  offset: Offset(0, _isPressed ? 1 : 2.5),
                  blurRadius: _isPressed ? 1.5 : 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base skeuomorphic gradient with signature iOS 6 horizon line
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: _isPressed
                            ? const [0.0, 1.0]
                            : const [0.0, 0.48, 0.50, 1.0],
                        colors: _isPressed
                            ? const [
                                Color(0xFFB8C4D2), // Pressed darker top
                                Color(0xFFDCE3EB), // Pressed bottom
                              ]
                            : const [
                                Color(0xFFFFFFFF), // Pure white gloss top
                                Color(0xFFEFF2F6), // Soft silver-white upper half
                                Color(0xFFDEE4EC), // Horizon specular line
                                Color(0xFFCCD5E1), // Metallic shaded bottom
                              ],
                      ),
                    ),
                  ),

                  // 1px top white specular highlight edge
                  if (!_isPressed)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 1.2,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),

                  // Upper glossy sheen reflection
                  if (!_isPressed)
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

                  // Engraved letterpress downward chevron
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, _isPressed ? 1.0 : 0.5),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 25,
                        color: _isPressed
                            ? const Color(0xFF143B66)
                            : const Color(0xFF225184),
                        shadows: [
                          if (_isPressed)
                            const Shadow(
                              color: Color(0x55000000),
                              offset: Offset(0, -1),
                              blurRadius: 0.5,
                            )
                          else
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.95),
                              offset: const Offset(0, 1),
                              blurRadius: 0,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Optional unread count badge in retro iOS style
          if (widget.unreadCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEE493B), Color(0xFFC71B11)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x35000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                child: Center(
                  child: Text(
                    widget.unreadCount > 99
                        ? '99+'
                        : widget.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Color(0x60000000),
                          offset: Offset(0, -0.5),
                          blurRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
