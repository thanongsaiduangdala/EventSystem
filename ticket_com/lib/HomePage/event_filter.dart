import 'package:flutter/material.dart';

const Color _kPurple = Color(0xFF7C4DFF);
const Color _kTextDark = Color(0xFF212121);

enum EventSort { relevance, soonest, cheapest, popular }

enum EventPeriod { any, today, thisWeek, thisMonth }

/// How far away an event may be from the user's chosen location.
enum EventDistance { any, within5, within10, within25, within50 }

/// Returns the max distance in km for [d], or null when unlimited.
double? distanceLimitKm(EventDistance d) {
  switch (d) {
    case EventDistance.any:
      return null;
    case EventDistance.within5:
      return 5;
    case EventDistance.within10:
      return 10;
    case EventDistance.within25:
      return 25;
    case EventDistance.within50:
      return 50;
  }
}

String distanceLabel(EventDistance d) {
  switch (d) {
    case EventDistance.any:
      return 'Anywhere';
    case EventDistance.within5:
      return 'Within 5 km';
    case EventDistance.within10:
      return 'Within 10 km';
    case EventDistance.within25:
      return 'Within 25 km';
    case EventDistance.within50:
      return 'Within 50 km';
  }
}

class EventFilter {
  const EventFilter({
    this.priceEnabled = false,
    this.minPrice = 0,
    this.maxPrice = 1000000,
    this.period = EventPeriod.any,
    this.distance = EventDistance.any,
    this.sort = EventSort.relevance,
  });

  final bool priceEnabled;
  final double minPrice;
  final double maxPrice;
  final EventPeriod period;
  final EventDistance distance;
  final EventSort sort;

  bool get hasConstraints =>
      priceEnabled ||
      period != EventPeriod.any ||
      distance != EventDistance.any;

  bool get isActive => hasConstraints || sort != EventSort.relevance;

  EventFilter copyWith({
    bool? priceEnabled,
    double? minPrice,
    double? maxPrice,
    EventPeriod? period,
    EventDistance? distance,
    EventSort? sort,
  }) {
    return EventFilter(
      priceEnabled: priceEnabled ?? this.priceEnabled,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      period: period ?? this.period,
      distance: distance ?? this.distance,
      sort: sort ?? this.sort,
    );
  }
}

String formatKip(num value) {
  final s = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$buf ₭';
}

String periodLabel(EventPeriod period) {
  switch (period) {
    case EventPeriod.any:
      return 'Any time';
    case EventPeriod.today:
      return 'Today';
    case EventPeriod.thisWeek:
      return 'This week';
    case EventPeriod.thisMonth:
      return 'This month';
  }
}

String sortLabel(EventSort sort) {
  switch (sort) {
    case EventSort.relevance:
      return 'Best match';
    case EventSort.soonest:
      return 'Soonest';
    case EventSort.cheapest:
      return 'Cheapest';
    case EventSort.popular:
      return 'Most popular';
  }
}

Future<EventFilter?> showEventFilterSheet(
  BuildContext context, {
  required EventFilter current,
  required double maxBound,
}) {
  return showModalBottomSheet<EventFilter>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _FilterSheet(current: current, maxBound: maxBound),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.maxBound});

  final EventFilter current;
  final double maxBound;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late EventFilter _f;

  @override
  void initState() {
    super.initState();
    final bound = widget.maxBound <= 0 ? 1.0 : widget.maxBound;
    _f = widget.current.copyWith(
      minPrice: widget.current.minPrice.clamp(0, bound).toDouble(),
      maxPrice: widget.current.maxPrice.clamp(0, bound).toDouble(),
      priceEnabled: widget.current.priceEnabled &&
          widget.current.maxPrice < bound,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bound = widget.maxBound <= 0 ? 1.0 : widget.maxBound;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filters',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _f.priceEnabled,
              onChanged: (v) => setState(() {
                _f = _f.copyWith(
                  priceEnabled: v,
                  minPrice: v ? _f.minPrice : 0,
                  maxPrice: v ? _f.maxPrice : bound,
                );
              }),
              title: const Text(
                'Price range (Kip)',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_f.priceEnabled) ...[
              RangeSlider(
                values: RangeValues(
                  _f.minPrice.clamp(0, bound).toDouble(),
                  _f.maxPrice.clamp(0, bound).toDouble(),
                ),
                min: 0,
                max: bound,
                divisions: 40,
                activeColor: _kPurple,
                labels: RangeLabels(
                  formatKip(_f.minPrice),
                  formatKip(_f.maxPrice),
                ),
                onChanged: (v) => setState(() {
                  _f = _f.copyWith(minPrice: v.start, maxPrice: v.end);
                }),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatKip(_f.minPrice),
                      style: const TextStyle(fontSize: 12)),
                  Text(formatKip(_f.maxPrice),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quick('Free', () {
                    setState(() => _f = _f.copyWith(minPrice: 0, maxPrice: 0));
                  }),
                  _quick('Under 50K', () {
                    setState(() =>
                        _f = _f.copyWith(minPrice: 0, maxPrice: 50000));
                  }),
                  _quick('Under 100K', () {
                    setState(() =>
                        _f = _f.copyWith(minPrice: 0, maxPrice: 100000));
                  }),
                  _quick('Under 500K', () {
                    setState(() =>
                        _f = _f.copyWith(minPrice: 0, maxPrice: 500000));
                  }),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'When',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in EventPeriod.values)
                  ChoiceChip(
                    label: Text(periodLabel(p)),
                    selected: _f.period == p,
                    selectedColor: _kPurple,
                    labelStyle: TextStyle(
                      color: _f.period == p ? Colors.white : _kTextDark,
                    ),
                    onSelected: (_) => setState(() => _f = _f.copyWith(period: p)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Distance',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in EventDistance.values)
                  ChoiceChip(
                    label: Text(distanceLabel(d)),
                    selected: _f.distance == d,
                    selectedColor: _kPurple,
                    labelStyle: TextStyle(
                      color: _f.distance == d ? Colors.white : _kTextDark,
                    ),
                    onSelected: (_) =>
                        setState(() => _f = _f.copyWith(distance: d)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Sort by',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in EventSort.values)
                  ChoiceChip(
                    label: Text(sortLabel(s)),
                    selected: _f.sort == s,
                    selectedColor: _kPurple,
                    labelStyle: TextStyle(
                      color: _f.sort == s ? Colors.white : _kTextDark,
                    ),
                    onSelected: (_) => setState(() => _f = _f.copyWith(sort: s)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _f = const EventFilter()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _kPurple),
                    onPressed: () => Navigator.pop(context, _f),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quick(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
