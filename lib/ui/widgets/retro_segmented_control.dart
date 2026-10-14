import 'package:flutter/material.dart';

class RetroSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool hasShadow;
  final EdgeInsetsGeometry padding;

  const RetroSegmentedControl({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.hasShadow = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    final entries = tabs.entries.toList();

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF1B3D66),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF1B3D66), width: 1),
        boxShadow: hasShadow
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(entries.length, (index) {
              final entry = entries[index];
              final isSelected = entry.key == selected;
              final isLast = index == entries.length - 1;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(entry.key),
                    child: Container(
                      padding: padding,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF15293F), Color(0xFF1B334E)],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF4C75A3), Color(0xFF2A5280)],
                              ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFE8EEF5),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: isSelected
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.black.withValues(alpha: 0.35),
                              offset: const Offset(0, -1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      color: const Color(0xFF1B3D66),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
