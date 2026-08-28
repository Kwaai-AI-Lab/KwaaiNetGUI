import 'package:flutter/material.dart';

/// A caption-bar filter checkbox: a scaled-down [Checkbox] and its label,
/// sized to sit inline on a table's caption row rather than in a form.
///
/// Shared by the peers and sharding tables so a filter looks and behaves the
/// same wherever one appears.
class FilterToggle extends StatelessWidget {
  const FilterToggle({
    super.key,
    required this.label,
    required this.tooltip,
    required this.value,
    required this.onChanged,
  });

  /// Fixed text. A hidden count appended to it changes the width between
  /// states and shifts the checkbox as you toggle it — the count belongs in
  /// the caption summary, where it moves nothing.
  final String label;

  final String tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      // Whole control is the hit target, so the label toggles too — a bare
      // checkbox this small is a fussy thing to hit.
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scaled down to sit on the caption bar without setting its
              // height: an unscaled checkbox is taller than the bar's text.
              SizedBox(
                width: 16,
                height: 16,
                child: Transform.scale(
                  scale: 0.75,
                  child: Checkbox(
                    value: value,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
