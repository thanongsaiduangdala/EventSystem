import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/HomePage/event_detail_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kPurpleDeep = Color(0xFF4A00E0);
const Color _kPurpleLight = Color(0xFF8E2DE2);
const Color _kNavy = Color(0xFF1A1F4D);
const Color _kToday = Color(0xFFE53935);
const Color _kGrey = Color(0xFF9E9E9E);
const Color _kTextGrey = Color(0xFF757575);

/// One selectable category filter chip shown in the pill row: [id] is the
/// backend category id, [color]/[icon] drive the badge on pills, map pins
/// and the ticket-card thumbnail.
class CategoryChipOption {
  final int id;
  final String name;
  final Color color;
  final IconData icon;

  const CategoryChipOption({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}

/// Pick a chip/pin color from a category name, matching the reference
/// palette (Sports red, Music purple, Food green) with a gentle fallback
/// for any other category.
class TicketPanel extends StatefulWidget {
  const TicketPanel({super.key});

  @override
  State<TicketPanel> createState() => _TicketPanelState();
}

class _TicketPanelState extends State<TicketPanel> {
  bool _loading = true;
  String? _error;

  List<EventModel> _events = [];
  Map<int, EventImageModel> _imageByEvent = {};
  Map<int, EventOrganizer> _organizerById = {};
  Map<int, int> _attendeeCountByEvent = {};
  Map<int, Set<int>> _categoryIdByEvent = {};
  List<CategoryChipOption>? _categoryOptionsInUse;

  late DateTime _month;
  DateTime? _selectedDate;
  bool _upcoming = true;

  // Search + category filtering (mirrors the reference search bar + pills).
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int? _filteredCategoryId;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final events = await EventApiService.getAllEvents();
      final images = await _optional(
        EventImageApiService.getAllEventImages,
        const <EventImageModel>[],
      );
      final organizers = await _optional(
        EventApiService.getAllOrganizers,
        const <EventOrganizer>[],
      );
      final tickets = await _optional(
        TicketTypeApiService.getAllTicketTypes,
        const <TicketTypeModel>[],
      );
      final categories = await _optional(
        CategoryApiService.getAllCategories,
        const <CategoryModel>[],
      );
      final eventCategories = await _optional(
        CategoryApiService.getAllEventCategories,
        const <EventCategoryModel>[],
      );

      final session = AuthService.currentSession;
      final myAttendees = <TicketAttendeeModel>[];
      if (session != null) {
        final orders = await _optional(
          () => OrdersApiService.getOrdersByAccount(session.accountId),
          const <OrderModel>[],
        );
        for (final order in orders) {
          final orderAttendees = await _optional(
            () => TicketAttendenceApiService.getTicketAttendeesByOrder(order.id),
            const <TicketAttendeeModel>[],
          );
          myAttendees.addAll(orderAttendees);
        }
      }

      final imageByEvent = <int, EventImageModel>{};
      for (final img in images) {
        if (img.isThumbnail || !imageByEvent.containsKey(img.eventId)) {
          imageByEvent[img.eventId] = img;
        }
      }

      // Map each ticket type -> its event, then my bought event ids.
      final eventByTicketType = {for (final t in tickets) t.id: t.eventId};
      final myEventIds = <int>{};
      final attendeeCount = <int, int>{};
      for (final a in myAttendees) {
        final eventId = eventByTicketType[a.ticketTypeId];
        if (eventId != null) {
          myEventIds.add(eventId);
          attendeeCount[eventId] = (attendeeCount[eventId] ?? 0) + 1;
        }
      }

      final bought =
          events.where((e) => myEventIds.contains(e.id)).toList();

      final categoryIdByEvent = <int, Set<int>>{};
      for (final ec in eventCategories) {
        categoryIdByEvent
            .putIfAbsent(ec.eventId, () => <int>{})
            .add(ec.categoryId);
      }

      final usedCategoryIds = <int>{};
      for (final e in bought) {
        usedCategoryIds.addAll(categoryIdByEvent[e.id] ?? const <int>{});
      }

      final options = <CategoryChipOption>[];
      for (final c in categories) {
        if (!usedCategoryIds.contains(c.id)) continue;
        options.add(
          CategoryChipOption(
            id: c.id,
            name: c.name,
            color: categoryColorFor(c.name),
            icon: iconForKey(c.iconPath ?? ''),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _events = bought;
        _imageByEvent = imageByEvent;
        _organizerById = {for (final o in organizers) o.id: o};
        _attendeeCountByEvent = attendeeCount;
        _categoryIdByEvent = categoryIdByEvent;
        _categoryOptionsInUse = options;
        _snapMonthToEvents();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static Future<T> _optional<T>(
    Future<T> Function() load,
    T fallback,
  ) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  bool get _hasEventInCurrentMonth {
    return _events.any(
      (e) => e.start.year == _month.year && e.start.month == _month.month,
    );
  }

  void _snapMonthToEvents() {
    if (_hasEventInCurrentMonth) return;
    final now = DateTime.now();
    final future = _events.where((e) => e.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final target = future.isNotEmpty
        ? future.first.start
        : (_events.isNotEmpty
            ? (_events.map((e) => e.start).reduce((a, b) => a.isAfter(b) ? a : b))
            : null);
    if (target != null) {
      _month = DateTime(target.year, target.month);
    }
  }

  bool _isPast(EventModel event) => event.end.isBefore(DateTime.now());

  List<EventModel> get _visibleEvents {
    var list =
        _events.where((e) => _upcoming ? !_isPast(e) : _isPast(e)).toList();

    final query = _search.toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        return e.name.toLowerCase().contains(query) ||
            e.address.toLowerCase().contains(query) ||
            e.description.toLowerCase().contains(query);
      }).toList();
    }

    final categoryId = _filteredCategoryId;
    if (categoryId != null) {
      list = list.where((e) {
        final ids = _categoryIdByEvent[e.id];
        return ids != null && ids.contains(categoryId);
      }).toList();
    }

    final selected = _selectedDate;
    if (selected != null) {
      list = list
          .where((e) =>
              e.start.year == selected.year &&
              e.start.month == selected.month &&
              e.start.day == selected.day)
          .toList();
    }
    list.sort((a, b) => _upcoming
        ? a.start.compareTo(b.start)
        : b.start.compareTo(a.start));
    return list;
  }

  Set<int> get _eventDaysInMonth {
    return _events
        .where((e) => e.start.year == _month.year && e.start.month == _month.month)
        .map((e) => e.start.day)
        .toSet();
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDate = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (_selectedDate != null &&
          _selectedDate!.year == date.year &&
          _selectedDate!.month == date.month &&
          _selectedDate!.day == date.day) {
        _selectedDate = null;
      } else {
        _selectedDate = date;
      }
    });
  }

  int get leading {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    return firstWeekday - 1;
  }

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: RefreshIndicator(
          color: _kPurpleDeep,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: _loading && _events.isEmpty ? _loadingView() : _body(context),
        ),
      ),
    );
  }

  Widget _loadingView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator(color: _kPurpleDeep)),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final events = _visibleEvents;
    final l10n = l10nOf(context);

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _header(context, topPad),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _upcoming ? l10n.upcomingEvents : l10n.pastEvents,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_selectedDate != null)
                TextButton(
                  onPressed: () => _selectDate(_selectedDate!),
                  child: Text(
                    '${_selectedDate!.year}/${_two(_selectedDate!.month)}/${_two(_selectedDate!.day)}  ✕',
                    style: const TextStyle(
                      color: _kPurpleDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null && _events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _errorBox(),
          )
        else if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _emptyState(
              context,
              _events.isEmpty
                  ? l10n.noTicketsYet
                  : (_upcoming ? l10n.noUpcomingEvents : l10n.noPastEvents),
            ),
          )
        else
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ticketCard(e),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header(BuildContext context, double topPad) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPurpleLight, _kPurpleDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 20),
      child: Column(
        children: [
          _searchBar(context),
          const SizedBox(height: 16),
          if (_categoryChips.isNotEmpty) ...[
            _categoryPills(context),
            const SizedBox(height: 16),
          ],
          _calendarCard(),
          const SizedBox(height: 16),
          _toggle(context),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.chevron_left, color: Colors.black45, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10nOf(context).searchHint,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.black, fontSize: 15),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _month = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                  );
                  _selectedDate = null;
                  _searchController.clear();
                  _search = '';
                });
              },
              icon: const Icon(Icons.my_location, color: kAccent, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPills(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final chip in _categoryChips) ...[
            const SizedBox(width: 8),
            _pillItem(
              context,
              chip.id,
              chip.name,
              chip.color,
              chip.icon,
              chip,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pillItem(
    BuildContext context,
    int? categoryId,
    String? name,
    Color color,
    IconData icon,
    CategoryChipOption? chip,
  ) {
    final active = (chip == null && _filteredCategoryId == null) ||
        (chip != null && _filteredCategoryId == chip.id);
    return GestureDetector(
      onTap: chip == null
          ? () => setState(() => _filteredCategoryId = null)
          : () => setState(() {
                _filteredCategoryId =
                    active ? null : chip.id;
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                name ?? l10nOf(context).filters,
                style: TextStyle(
                  color: active ? _kPurpleDeep : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CategoryChipOption> get _categoryChips {
    return _categoryOptionsInUse ?? const [];
  }

  Widget _calendarCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left, color: _kNavy),
              ),
              Expanded(
                child: Text(
                  '${_monthName(_month.month)} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right, color: _kNavy),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final d in const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _calendarGrid(),
        ],
      ),
    );
  }

  Widget _calendarGrid() {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = _daysInMonth;
    final leading = firstOfMonth.weekday - 1;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final eventDays = _eventDaysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final day = index - leading + 1;
        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
        final date = DateTime(_month.year, _month.month, day);
        return _dayCell(date, eventDays.contains(day));
      },
    );
  }

  Widget _dayCell(DateTime date, bool hasEvent) {
    final now = DateTime.now();
    final isToday = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
    final selected = _selectedDate != null &&
        _selectedDate!.year == date.year &&
        _selectedDate!.month == date.month &&
        _selectedDate!.day == date.day;

    Color? fill;
    Color border = Colors.transparent;
    Color textColor = _kNavy;

    if (selected) {
      fill = kAccent;
      textColor = Colors.white;
    } else if (hasEvent) {
      fill = _kNavy;
      textColor = Colors.white;
    } else if (isToday) {
      border = _kToday;
    }

    return Center(
      child: GestureDetector(
        onTap: () => _selectDate(date),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(BuildContext context) {
    final l10n = l10nOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleItem(l10n.upcoming, true)),
          Expanded(child: _toggleItem(l10n.pastEvents.toUpperCase(), false)),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool upcoming) {
    final active = _upcoming == upcoming;
    return GestureDetector(
      onTap: () => setState(() {
        _upcoming = upcoming;
        _selectedDate = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _kPurpleDeep : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _ticketCard(EventModel event) {
    final image = _imageByEvent[event.id];
    final organizer = _organizerById[event.organizerId]?.name ?? '';
    final attend = _attendeeCountByEvent[event.id] ?? 0;
    final chip = _chipForEvent(event);

    return GestureDetector(
      onTap: () => _openEventDetail(event),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(image, chip),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _metaRow(Icons.place_outlined, event.address),
                const SizedBox(height: 4),
                _metaRow(Icons.calendar_today_outlined, _formatDate(event.start)),
                const SizedBox(height: 4),
                _metaRow(
                  Icons.people,
                  '$attend attending',
                ),
                if (organizer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      organizer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _kNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _openEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailPage(
          event: event,
          image: _imageByEvent[event.id],
          organizer: _organizerById[event.organizerId],
          attend: _attendeeCountByEvent[event.id] ?? 0,
          categories: _categoriesForEvent(event),
        ),
      ),
    );
  }

  List<CategoryModel> _categoriesForEvent(EventModel event) {
    final ids = _categoryIdByEvent[event.id];
    if (ids == null || ids.isEmpty) return const [];
    final options = _categoryOptionsInUse ?? const [];
    return [
      for (final option in options)
        if (ids.contains(option.id))
          CategoryModel(id: option.id, name: option.name),
    ];
  }

  CategoryChipOption? _chipForEvent(EventModel event) {
    final ids = _categoryIdByEvent[event.id];
    if (ids == null) return null;
    final options = _categoryOptionsInUse;
    if (options == null || options.isEmpty) return null;
    for (final id in ids) {
      for (final option in options) {
        if (option.id == id) return option;
      }
    }
    return null;
  }

  Widget _thumbnail(EventImageModel? image, CategoryChipOption? chip) {
    return Container(
      width: 64,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(image),
          if (chip != null)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: chip.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Icon(chip.icon, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _image(EventImageModel? image) {
    if (image == null) return _placeholderImage();
    final url = EventImageApiService.thumbnailUrl(image.imagePath);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholderImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholderImage();
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: const Icon(Icons.event, color: Color(0xFFBDBDBD), size: 24),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _kGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Colors.grey, size: 40),
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _kPurpleDeep),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }

  static String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) =>
      '${d.year}/${_two(d.month)}/${_two(d.day)}';
}
