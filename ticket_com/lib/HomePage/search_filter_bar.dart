import 'package:flutter/material.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// One selectable chip inside a [FilterGroup]. A `null` [value] means "All".
class FilterOption {
  const FilterOption(this.label, this.value);

  final String label;
  final Object? value;
}

/// A labelled row of mutually exclusive chips (e.g. "Role: All / Admin /
/// Staff"). [selected] is the currently chosen option value; `null` = "All".
class FilterGroup {
  const FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<FilterOption> options;
  final Object? selected;
  final ValueChanged<Object?> onChanged;

  bool get isActive => selected != null;
}

/// Search box plus horizontally scrolling filter chips, styled like the
/// search/filters on the "My Events" tab. The parent owns the state: it
/// passes the [controller], rebuilds in [onChanged], and applies the filters
/// to its own list.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.groups = const [],
    this.onClearAll,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final List<FilterGroup> groups;

  /// Shows a "Clear" button (when a search or filter is active) that should
  /// reset the search text and every filter.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final anyActive =
        controller.text.trim().isNotEmpty || groups.any((g) => g.isActive);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
            prefixIcon: const Icon(Icons.search, color: _kTextGrey),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, color: _kTextGrey, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kAccent, width: 1.6),
            ),
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0)
                    const SizedBox(
                      height: 22,
                      child: VerticalDivider(width: 16, color: _kTextGrey),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      groups[i].label,
                      style: const TextStyle(
                        color: _kTextGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final option in groups[i].options)
                    _chip(
                      label: option.label,
                      selected: groups[i].selected == option.value,
                      onTap: () => groups[i].onChanged(option.value),
                    ),
                ],
                if (anyActive && onClearAll != null)
                  TextButton.icon(
                    onPressed: onClearAll,
                    style: TextButton.styleFrom(foregroundColor: kAccent),
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ] else if (anyActive && onClearAll != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(foregroundColor: kAccent),
              child: const Text(
                'Clear',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kTextDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        selected: selected,
        selectedColor: kAccent,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(color: selected ? kAccent : const Color(0xFFD5D2EC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
