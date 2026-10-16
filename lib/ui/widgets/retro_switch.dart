import 'dart:ui';

import 'package:flutter/material.dart';

class RetroSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String onLabel;
  final String offLabel;
  final double width;
  final double height;

  const RetroSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.onLabel = 'ВКЛ',
    this.offLabel = 'ВЫКЛ',
    this.width = 78,
    this.height = 28,
  });

  bool get isEnabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final knobSize = height - 2.0;
    final maxKnobLeft = width - knobSize - 1.0;

    return Semantics(
      toggled: value,
      enabled: isEnabled,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.55,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: const Color(0xFF7E848F),
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1.5),
                  blurRadius: 2.0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((height - 2) / 2),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: value ? 1.0 : 0.0,
                  end: value ? 1.0 : 0.0,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                builder: (context, animValue, _) {
                  final knobLeft = lerpDouble(1.0, maxKnobLeft, animValue)!;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFE2E4E8),
                              Color(0xFFF9F9FA),
                              Color(0xFFFFFFFF),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      Opacity(
                        opacity: animValue,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF3886E5),
                                Color(0xFF2067CF),
                                Color(0xFF1350B4),
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: maxKnobLeft + 4,
                        child: Opacity(
                          opacity: animValue,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                onLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      offset: Offset(0, -1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: width - knobSize,
                        child: Opacity(
                          opacity: 1.0 - animValue,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                offLabel,
                                style: const TextStyle(
                                  color: Color(0xFF7E8491),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.white,
                                      offset: Offset(0, 1),
                                      blurRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: knobLeft,
                        top: 1.0,
                        width: knobSize,
                        height: knobSize,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF9EA3AC),
                              width: 0.75,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                offset: Offset(0, 2),
                                blurRadius: 3,
                              ),
                              BoxShadow(
                                color: Color(0x20000000),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xFFEBEFF4),
                                Color(0xFFD2D7E0),
                              ],
                              stops: [0.0, 0.45, 1.0],
                            ),
                          ),
                          child: ClipOval(
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: knobSize * 0.48,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.7),
                                          Colors.white.withValues(alpha: 0.05),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
