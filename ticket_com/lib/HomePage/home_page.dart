import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/HomePage/event_card.dart';
import 'package:ticket_com/HomePage/event_detail_page.dart';
import 'package:ticket_com/HomePage/event_filter.dart';
import 'package:ticket_com/HomePage/event_list_page.dart';
import 'package:ticket_com/HomePage/nearby_event_card.dart';
import 'package:ticket_com/l10n/app_localizations.dart';
import 'package:ticket_com/map/location_picker_page.dart';
import 'package:ticket_com/services/account_category_api_service.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/orders_api_service.dart';
import 'package:ticket_com/services/ticket_attendence_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/services/wishlist_api_service.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kPurple = Color(0xFF7C4DFF);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;

  List<EventModel> _events = [];
  List<EventModel> _randomOrder = [];
  Map<int, EventImageModel> _imageByEvent = {};
  Map<int, EventOrganizer> _organizerById = {};
  List<CategoryModel> _categories = [];
  Map<int, List<int>> _eventCategories = {};
  Set<int> _preferredCategories = {};
  Map<int, int> _wishCounts = {};
  Map<int, WishlistModel> _myWishByEvent = {};
  Map<int, int> _minPriceByEvent = {};
  Set<int> _boughtEventIds = {};

  static const LatLng _defaultLocation = LatLng(17.9757, 102.6331);
  LatLng _userLocation = _defaultLocation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedCategoryIds = {};
  EventFilter _filter = const EventFilter();
  static const int _pageSize = 20;
  int _page = 0;
  double _maxPriceBound = 1000000;

  static const Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final categories = await _optional(
        CategoryApiService.getAllCategories,
        const <CategoryModel>[],
      );
      final eventCats = await _optional(
        CategoryApiService.getAllEventCategories,
        const <EventCategoryModel>[],
      );
      final accountCats = await _optional(
        AccountCategoryApiService.getAllAccountCategories,
        const <AccountCategoryModel>[],
      );
      final wishes = await _optional(
        WishlistApiService.getAllWishes,
        const <WishlistModel>[],
      );
      final tickets = await _optional(
        TicketTypeApiService.getAllTicketTypes,
        const <TicketTypeModel>[],
      );

      final imageByEvent = <int, EventImageModel>{};
      for (final img in images) {
        if (img.isThumbnail || !imageByEvent.containsKey(img.eventId)) {
          imageByEvent[img.eventId] = img;
        }
      }

      final eventCategories = <int, List<int>>{};
      for (final ec in eventCats) {
        eventCategories.putIfAbsent(ec.eventId, () => []).add(ec.categoryId);
      }

      final minPriceByEvent = <int, int>{};
      for (final t in tickets) {
        final current = minPriceByEvent[t.eventId];
        if (current == null || t.priceInKip < current) {
          minPriceByEvent[t.eventId] = t.priceInKip;
        }
      }
      final maxTicket = tickets.isEmpty
          ? 0
          : tickets.map((t) => t.priceInKip).reduce(math.max);
      final priceBound =
          math.max(100000, ((maxTicket / 10000).ceil() * 10000)).toDouble();

      // "Interesting for you" is driven by the categories the signed-in
      // account favourited in the accountcategory table. No favourites ->
      // we fall back to a random order at render time.
      final preferred = <int>{};
      final session = AuthService.currentSession;
      if (session != null) {
        preferred.addAll(
          accountCats
              .where((a) => a.accountId == session.accountId)
              .map((a) => a.categoryId),
        );
      }

      // Events the signed-in user already bought tickets for, used to show a
      // "Bought" badge on their cards.
      final boughtEventIds = <int>{};
      if (session != null) {
        final eventByTicketType = {for (final t in tickets) t.id: t.eventId};
        final myOrders = await _optional(
          () => OrdersApiService.getOrdersByAccount(session.accountId),
          const <OrderModel>[],
        );
        for (final order in myOrders) {
          final attendees = await _optional(
            () => TicketAttendenceApiService.getTicketAttendeesByOrder(order.id),
            const <TicketAttendeeModel>[],
          );
          for (final a in attendees) {
            final eventId = eventByTicketType[a.ticketTypeId];
            if (eventId != null) boughtEventIds.add(eventId);
          }
        }
      }

      final wishCounts = <int, int>{};
      for (final w in wishes) {
        wishCounts[w.eventId] = (wishCounts[w.eventId] ?? 0) + 1;
      }

      final myWishByEvent = <int, WishlistModel>{};
      if (session != null) {
        for (final w in wishes) {
          if (w.accountId == session.accountId) {
            myWishByEvent[w.eventId] = w;
          }
        }
      }

      final active =
          events.where((e) => e.end.isAfter(DateTime.now())).toList();
      final shuffled = List<EventModel>.of(active)..shuffle();

      if (!mounted) return;
      setState(() {
        _events = active;
        _randomOrder = shuffled;
        _imageByEvent = imageByEvent;
        _organizerById = {for (final o in organizers) o.id: o};
        _categories = categories;
        _eventCategories = eventCategories;
        _preferredCategories = preferred;
        _wishCounts = wishCounts;
        _myWishByEvent = myWishByEvent;
        _minPriceByEvent = minPriceByEvent;
        _boughtEventIds = boughtEventIds;
        _maxPriceBound = priceBound;
        if (_filter.maxPrice > priceBound) {
          _filter = _filter.copyWith(maxPrice: priceBound);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }

  double _distanceKm(EventModel event) {
    return _distance.as(
      LengthUnit.Kilometer,
      _userLocation,
      LatLng(event.latitude, event.longitude),
    );
  }

  int _popularity(EventModel event) => _wishCounts[event.id] ?? 0;

  List<EventModel> get _allNearEvents {
    final list = List<EventModel>.of(_events)
      ..sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
    return list;
  }

  List<EventModel> get _allUpcomingEvents {
    final list = List<EventModel>.of(_events)
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  List<EventModel> get _allInterestingEvents {
    if (_preferredCategories.isNotEmpty) {
      final pick = _events
          .where((e) => (_eventCategories[e.id] ?? [])
              .any((c) => _preferredCategories.contains(c)))
          .toList()
        ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
      if (pick.isNotEmpty) return pick;
    }
    return _randomOrder;
  }

  List<EventModel> get _allMostJoinedEvents {
    final list = List<EventModel>.of(_events)
      ..sort((a, b) => _popularity(b).compareTo(_popularity(a)));
    return list;
  }

  bool get _isFiltering =>
      _searchQuery.trim().isNotEmpty ||
      _selectedCategoryIds.isNotEmpty ||
      _filter.isActive;

  int _minPrice(EventModel event) => _minPriceByEvent[event.id] ?? 0;

  bool _withinPrice(EventModel event) {
    if (!_filter.priceEnabled) return true;
    final price = _minPrice(event);
    return price >= _filter.minPrice && price <= _filter.maxPrice;
  }

  bool _withinPeriod(EventModel event) {
    final now = DateTime.now();
    switch (_filter.period) {
      case EventPeriod.any:
        return true;
      case EventPeriod.today:
        final d = event.start;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case EventPeriod.thisWeek:
        return event.start.isAfter(now) &&
            event.start.isBefore(now.add(const Duration(days: 7)));
      case EventPeriod.thisMonth:
        return event.start.isAfter(now) &&
            event.start.isBefore(now.add(const Duration(days: 30)));
    }
  }

  bool _withinDistance(EventModel event) {
    final limit = distanceLimitKm(_filter.distance);
    if (limit == null) return true;
    return _distanceKm(event) <= limit;
  }

  /// Relevance ranking for the combined search / category / filter query.
  ///
  /// Events are scored by how many of the *active* criteria they satisfy:
  /// name/organizer text, the selected categories, and the price/period/
  /// distance filters. Matching everything (search AND categories AND filter)
  /// outranks matching any subset, so the caller gets a graceful fallback
  /// ladder: query+cats+filter -> query+cats / query+filter / cats+filter ->
  /// query / cats / filter.
  List<EventModel> get _results {
    final q = _searchQuery.trim().toLowerCase();
    final hasSearch = q.isNotEmpty;
    final hasCats = _selectedCategoryIds.isNotEmpty;
    final filtersActive = _filter.hasConstraints;
    final hasConstraints = hasSearch || hasCats || filtersActive;
    final activeDims =
        (hasSearch ? 1 : 0) + (hasCats ? 1 : 0) + (filtersActive ? 1 : 0);

    final scored = <_ScoredEvent>[];
    for (final event in _events) {
      final eventCats = (_eventCategories[event.id] ?? const <int>[]).toSet();

      final nameMatch = hasSearch && event.name.toLowerCase().contains(q);
      final organizerName =
          _organizerById[event.organizerId]?.name.toLowerCase() ?? '';
      final organizerMatch = hasSearch && organizerName.contains(q);
      final searchHit = nameMatch || organizerMatch;

      final matchedCats =
          hasCats ? eventCats.intersection(_selectedCategoryIds).length : 0;
      final allCatsHit = hasCats && matchedCats == _selectedCategoryIds.length;
      final catHit = matchedCats > 0;

      final filterHit =
          _withinPrice(event) && _withinPeriod(event) && _withinDistance(event);

      var dims = 0;
      if (hasSearch && searchHit) dims++;
      if (hasCats && catHit) dims++;
      if (filtersActive && filterHit) dims++;

      // Matches none of the active criteria -> not part of the result set.
      if (hasConstraints && dims == 0) continue;

      var score = 0;
      if (hasSearch && searchHit) score += nameMatch ? 12 : 8;
      if (hasCats && catHit) score += allCatsHit ? 10 : 5;
      if (filtersActive && filterHit) score += 4;
      // Bonus when the event satisfies every active criterion at once.
      if (hasConstraints && dims == activeDims) score += 60;

      scored.add(_ScoredEvent(event, score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      switch (_filter.sort) {
        case EventSort.soonest:
          return a.event.start.compareTo(b.event.start);
        case EventSort.cheapest:
          return _minPrice(a.event).compareTo(_minPrice(b.event));
        case EventSort.popular:
          return _popularity(b.event).compareTo(_popularity(a.event));
        case EventSort.relevance:
          final byPopularity =
              _popularity(b.event).compareTo(_popularity(a.event));
          if (byPopularity != 0) return byPopularity;
          return a.event.start.compareTo(b.event.start);
      }
    });

    return scored.map((s) => s.event).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _page = 0;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _page = 0;
    });
  }

  void _toggleCategory(int id) {
    setState(() {
      if (!_selectedCategoryIds.remove(id)) _selectedCategoryIds.add(id);
      _page = 0;
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showEventFilterSheet(
      context,
      current: _filter,
      maxBound: _maxPriceBound,
    );
    if (result != null && mounted) {
      setState(() {
        _filter = result;
        _page = 0;
      });
    }
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategoryIds.clear();
      _filter = const EventFilter();
      _page = 0;
    });
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerPage(initialLocation: _userLocation),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _userLocation = picked);
    }
  }

  Future<void> _toggleWish(EventModel event) async {
    final session = AuthService.currentSession;
    final messenger = ScaffoldMessenger.of(context);
    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please log in to save events')),
      );
      return;
    }

    final existing = _myWishByEvent[event.id];
    try {
      if (existing != null) {
        await WishlistApiService.deleteWishById(existing.id);
      } else {
        final result = await WishlistApiService.createWish(
          accountId: session.accountId,
          eventId: event.id,
        );
        final newId = result['WishID'] is int
            ? result['WishID'] as int
            : int.tryParse(result['WishID'].toString());
        if (mounted) {
          setState(() {
            _myWishByEvent[event.id] = WishlistModel(
              id: newId ?? -1,
              accountId: session.accountId,
              eventId: event.id,
            );
            _wishCounts[event.id] = (_wishCounts[event.id] ?? 0) + 1;
          });
        }
      }
      if (existing != null && mounted) {
        setState(() {
          _myWishByEvent.remove(event.id);
          _wishCounts[event.id] = (_wishCounts[event.id] ?? 0) - 1;
        });
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              existing != null ? 'Removed from wish list' : 'Saved to wish list',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not update wish list')),
        );
      }
    }
  }

  String get _locationLabel {
    final lat = _userLocation.latitude;
    final lng = _userLocation.longitude;
    if (lat == _defaultLocation.latitude &&
        lng == _defaultLocation.longitude) {
      return 'Vientiane, Laos';
    }
    return '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}';
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
          color: _kPurple,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: _loading && _events.isEmpty
              ? _loadingView(context)
              : _body(context),
        ),
      ),
    );
  }

  Widget _loadingView(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(
            child: CircularProgressIndicator(color: _kPurple),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final l10n = l10nOf(context);
    final topPad = MediaQuery.paddingOf(context).top;

    if (_error != null && _events.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _kPurple),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                _header(context, topPad),
                SizedBox(height: _categories.isEmpty ? 0 : 34),
              ],
            ),
            if (_categories.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 17,
                child: _categoryBar(context),
              ),
          ],
        ),
        SizedBox(height: _categories.isEmpty ? 20 : 0),
        if (_isFiltering)
          ..._resultsBody(context)
        else ...[
          _sectionHeader(
            context,
            l10n.upcomingEvents,
            onSeeAll: () =>
                _openAllEvents(l10n.upcomingEvents, _allUpcomingEvents),
          ),
          const SizedBox(height: 12),
          if (_allUpcomingEvents.isEmpty)
            _padded(_emptyState(context, l10n.noUpcomingEvents))
          else
            _horizontalEvents(_allUpcomingEvents),
          const SizedBox(height: 20),
          _sectionHeader(
            context,
            l10n.nearYou,
            onSeeAll: () => _openAllEvents(l10n.nearYou, _allNearEvents),
          ),
          const SizedBox(height: 12),
          if (_allNearEvents.isEmpty)
            _padded(_emptyState(context, l10n.noEventsNearYou))
          else
            _horizontalNearbyEvents(context, _allNearEvents),
          const SizedBox(height: 20),
          _sectionHeader(
            context,
            l10n.interestingForYou,
            onSeeAll: () =>
                _openAllEvents(l10n.interestingForYou, _allInterestingEvents),
          ),
          const SizedBox(height: 12),
          if (_allInterestingEvents.isEmpty)
            _padded(_emptyState(context, l10n.noInterestingEvents))
          else
            _horizontalEvents(_allInterestingEvents),
          const SizedBox(height: 20),
          _sectionHeader(
            context,
            l10n.mostJoinedEvents,
            onSeeAll: () =>
                _openAllEvents(l10n.mostJoinedEvents, _allMostJoinedEvents),
          ),
          const SizedBox(height: 12),
          if (_allMostJoinedEvents.isEmpty)
            _padded(_emptyState(context, l10n.noMostJoinedEvents))
          else
            _horizontalEvents(_allMostJoinedEvents),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ---------------- results ----------------

  /// Builds the "filtering" body: a ranked result list shown 20 events per
  /// page, with `<` / `>` controls to walk between pages.
  List<Widget> _resultsBody(BuildContext context) {
    final l10n = l10nOf(context);
    final results = _results;
    final totalPages =
        results.isEmpty ? 1 : (results.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = math.min(start + _pageSize, results.length);
    final pageItems =
        start >= results.length ? <EventModel>[] : results.sublist(start, end);

    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.searchResults,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${results.length}',
              style: const TextStyle(
                color: _kTextGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _clearSearchAndFilters,
              child: Text(
                l10n.clearAll,
                style: const TextStyle(
                  color: _kPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    if (results.isEmpty) {
      widgets.add(_padded(_emptyState(context, l10n.noMatchingEvents)));
      widgets.add(const SizedBox(height: 24));
      return widgets;
    }

    for (var i = 0; i < pageItems.length; i += 2) {
      final first = pageItems[i];
      final second = i + 1 < pageItems.length ? pageItems[i + 1] : null;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _resultCard(first)),
              const SizedBox(width: 12),
              if (second != null)
                Expanded(child: _resultCard(second))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    widgets.add(_paginationBar(page, totalPages));
    return widgets;
  }

  Widget _resultCard(EventModel event) {
    return EventCard(
      event: event,
      image: _imageByEvent[event.id],
      attend: _wishCounts[event.id] ?? 0,
      saved: _myWishByEvent.containsKey(event.id),
      bought: _boughtEventIds.contains(event.id),
      onSaveTap: () => _toggleWish(event),
      onTap: () => _openEventDetail(event),
    );
  }

  Widget _paginationBar(int page, int totalPages) {
    final canPrev = page > 0;
    final canNext = page < totalPages - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: canPrev ? () => setState(() => _page = page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kPurple,
              disabledForegroundColor: const Color(0xFFBDBDBD),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${page + 1} / $totalPages',
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: canNext ? () => setState(() => _page = page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kPurple,
              disabledForegroundColor: const Color(0xFFBDBDBD),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- header ----------------

  Widget _header(BuildContext context, double topPad) {
    final l10n = l10nOf(context);
    return ClipPath(
      clipper: const _HeaderCurveClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 28),
        child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.menu, color: Colors.white),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickLocation,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Column(
                      children: [
                        Text(
                          '${l10n.currentLocation} ▾',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _locationLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _searchField(context, l10n)),
              const SizedBox(width: 10),
              _filterButton(l10n),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, AppLocalizations l10n) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: l10n.searchHint,
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: const Icon(Icons.close, color: Colors.white70, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _filterButton(AppLocalizations l10n) {
    final active = _filter.isActive;
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              color: active ? _kPurple : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.filters,
              style: TextStyle(
                color: active ? _kPurple : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBar(BuildContext context) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth > 32 ? constraints.maxWidth - 32 : 0,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _categories.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _categoryPill(_categories[i]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryPill(CategoryModel category) {
    final selected = _selectedCategoryIds.contains(category.id);
    final color = _pillColor(category.name);
    return InkWell(
      onTap: () => _toggleCategory(category.id),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : iconForKey(category.iconPath ?? ''),
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _pillColor(String name) {
    final k = name.toLowerCase().trim();
    const colors = <String, Color>{
      'food': Color(0xFF4FC3F7),
      'sports+': Color(0xFFD81B60),
      'sports': Color(0xFFEC407A),
      'pilot': Color(0xFF5C6BC0),
      'running': Color(0xFF1E88E5),
      'fitness': Color(0xFF26A69A),
      'culture': Color(0xFF8E44AD),
      'music': Color(0xFFFF7043),
      'festival': Color(0xFFFB8C00),
      'art': Color(0xFFAB47BC),
      'nature': Color(0xFF43A047),
      'adventure': Color(0xFF795548),
      'community': Color(0xFF00ACC1),
    };
    final known = colors[k];
    if (known != null) return known;
    const palette = [
      Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFFEC407A),
      Color(0xFFFF7043), Color(0xFF26C6DA),
    ];
    return palette[k.hashCode.abs() % palette.length];
  }

  // ---------------- sections ----------------

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10nOf(context).seeAll,
                  style: const TextStyle(
                    color: Color(0xFF7C7C7C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF7C7C7C), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontally scrolling row of compact event cards. Shows up to 10 events
  /// before the section's "See all" action is needed to view the full list.
  Widget _horizontalEvents(List<EventModel> events) {
    final shown = events.take(10).toList();
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final event = shown[index];
          return SizedBox(
            width: 172,
            child: EventCard(
              event: event,
              image: _imageByEvent[event.id],
              attend: _wishCounts[event.id] ?? 0,
              saved: _myWishByEvent.containsKey(event.id),
              bought: _boughtEventIds.contains(event.id),
              onSaveTap: () => _toggleWish(event),
              onTap: () => _openEventDetail(event),
            ),
          );
        },
      ),
    );
  }

  /// Horizontally scrolling row of wide split cards for the "Near You"
  /// section. Shows up to 5 events before "See all" is needed.
  Widget _horizontalNearbyEvents(BuildContext context, List<EventModel> events) {
    final shown = events.take(5).toList();
    final cardWidth = MediaQuery.sizeOf(context).width - 48;
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final event = shown[index];
          return SizedBox(
            width: cardWidth,
            child: NearbyEventCard(
              event: event,
              image: _imageByEvent[event.id],
              attend: _wishCounts[event.id] ?? 0,
              organizerName: _organizerById[event.organizerId]?.name,
              saved: _myWishByEvent.containsKey(event.id),
              bought: _boughtEventIds.contains(event.id),
              onSaveTap: () => _toggleWish(event),
              onTap: () => _openEventDetail(event),
            ),
          );
        },
      ),
    );
  }

  Widget _padded(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  void _openAllEvents(String title, List<EventModel> events) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventListPage(
          title: title,
          events: events,
          imageByEvent: _imageByEvent,
          wishCounts: _wishCounts,
          savedIds: _myWishByEvent.keys.toSet(),
          boughtIds: _boughtEventIds,
          onToggleWish: _toggleWish,
          onEventTap: _openEventDetail,
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
          attend: _wishCounts[event.id] ?? 0,
          saved: _myWishByEvent.containsKey(event.id),
          onToggleWish: _toggleWish,
          minPrice: _minPriceByEvent[event.id],
          categories: _categoriesForEvent(event.id),
        ),
      ),
    );
  }

  List<CategoryModel> _categoriesForEvent(int eventId) {
    return [
      for (final id in (_eventCategories[eventId] ?? const <int>[]))
        if (_categories.any((c) => c.id == id))
          _categories.firstWhere((c) => c.id == id),
    ];
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
}

/// Pairs an event with its relevance score in the ranked result list.
class _ScoredEvent {
  _ScoredEvent(this.event, this.score);

  final EventModel event;
  final int score;
}

/// Gives the header soft, continuously-curved bottom corners (iPhone-style
/// squircle) so the centred category pills sit on its bottom edge.
class _HeaderCurveClipper extends CustomClipper<Path> {
  const _HeaderCurveClipper();

  static const double _radius = 28;
  static const double _smoothing = 0.45;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    const r = _radius;
    const c = r * (1 - _smoothing);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, h - r)
      ..cubicTo(0, h - c, c, h, r, h)
      ..lineTo(w - r, h)
      ..cubicTo(w - c, h, w, h - c, w, h - r)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant _HeaderCurveClipper oldClipper) => false;
}
