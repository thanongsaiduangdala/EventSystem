import 'package:flutter/material.dart';

/// Pill-style segmented switcher, same look as the Wish / Followed Organizers
/// toggle: a tinted track with a white pill on the active option.
///
/// [badges] optionally shows a small count next to an option's label
/// (keyed by option index); zero or missing counts are hidden.
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.badges = const {},
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;

  static const Color _deep = Color(0xFF4A00E0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4DFF), Color(0xFF8E2DE2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(child: _item(i)),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final active = selected == index;
    final count = badges[index] ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _deep : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? _deep : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? Colors.white : _deep,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
