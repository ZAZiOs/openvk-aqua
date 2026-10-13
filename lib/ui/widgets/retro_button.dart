import 'package:flutter/material.dart';

import '../theme/retro_theme.dart';

class RetroButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const RetroButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
    this.fontSize = 16,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return Center(
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 30),
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnabled
                  ? (_isPressed
                        ? const Color(0xFF133967)
                        : const Color(0xFF1D4A7E))
                  : Colors.grey.shade400,
              width: 1,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isPressed ? 0.35 : 0.2),
                      offset: Offset(0, _isPressed ? 1 : 2),
                      blurRadius: _isPressed ? 2 : 4,
                    ),
                  ]
                : null,
            gradient: isEnabled
                ? (_isPressed
                      ? RetroTheme.buttonPressedGradient
                      : RetroTheme.buttonGradient)
                : LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500],
                  ),
          ),
          padding: widget.padding,
          child: widget.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isEnabled ? const Color(0xFFEDEDED) : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.fontSize,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        offset: const Offset(0, -1),
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
