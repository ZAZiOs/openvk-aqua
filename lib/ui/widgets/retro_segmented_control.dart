import 'package:flutter/material.dart';

class RetroSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  const RetroSegmentedControl({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3659),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF142A47), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.entries.map((entry) {
          final isSelected = entry.key == selected;
          return GestureDetector(
            onTap: () => onSelected(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF4F7FB8), Color(0xFF2B578C)],
                      )
                    : null,
                border: isSelected
                    ? Border.all(color: const Color(0xFF1D406B), width: 1)
                    : null,
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x40000000),
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFB4C8E0),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    shadows: isSelected
                        ? [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, -1),
                              blurRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
