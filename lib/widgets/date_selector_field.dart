import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class DateSelectorField extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DateSelectorField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DateSelectorField> createState() => _DateSelectorFieldState();
}

class _DateSelectorFieldState extends State<DateSelectorField> {
  final _key = GlobalKey();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggleCalendar() {
    if (_overlay != null) {
      _removeOverlay();
      return;
    }

    final box = _key.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final fieldSize = box.size;
    final screenSize = MediaQuery.of(context).size;

    const calendarWidth = 300.0;
    const calendarHeight = 300.0;
    const gap = 6.0;

    double top = offset.dy + fieldSize.height + gap;
    if (top + calendarHeight > screenSize.height) {
      top = offset.dy - calendarHeight - gap;
    }

    double left = offset.dx + fieldSize.width / 2 - calendarWidth / 2;
    left = left.clamp(8.0, screenSize.width - calendarWidth - 8);

    _overlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
            ),
          ),
          Positioned(
            top: top,
            left: left,
            width: calendarWidth,
            child: _CalendarPopup(
              selectedDate: widget.selectedDate,
              onDateSelected: (date) {
                widget.onDateSelected(date);
                _removeOverlay();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return InkWell(
      key: _key,
      onTap: _toggleCalendar,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.calendar,
                size: 11,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                _formatDate(widget.selectedDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                _overlay != null
                    ? LucideIcons.chevron_up
                    : LucideIcons.chevron_down,
                size: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarPopup extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarPopup({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Material(
      color: fillColor,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CalendarDatePicker(
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          onDateChanged: onDateSelected,
        ),
      ),
    );
  }
}
