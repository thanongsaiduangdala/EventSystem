import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ticket_com/HomePage/event_filter.dart';
import 'package:ticket_com/HomePage/event_detail_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/location_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/services/wishlist_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

/// One selectable category pin/pill for the map: [id] is the backend
/// category id, [color]/[icon] drive the marker pins and the filter pills.
class _CategoryPin {
  final int id;
  final String name;
  final Color color;
  final IconData icon;

  const _CategoryPin({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}

class MapPanel extends StatefulWidget {
  const MapPanel({super.key});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> with TickerProviderStateMixin {
  static const LatLng _center = LatLng(17.9757, 102.6331);
  static const Distance _distance = Distance();

  /// Zoom levels at or above this count as "zoomed in": the bottom card list
  /// switches from wishlist events to the events currently visible on screen.
  static const double _zoomInThreshold = 15;
  static const int _maxVisibleCards = 10;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _cardController =
      PageController(viewportFraction: 0.84);

  List<EventModel> _events = [];
  Map<int, EventImageModel> _imageByEvent = {};
  Map<int, EventOrganizer> _organizerById = {};
  Map<int, Set<int>> _categoryIdByEvent = {};
  final Map<int, int> _wishCounts = {};
  Map<int, int> _minPriceByEvent = {};
  List<_CategoryPin> _categories = [];
  EventModel? _pinnedEvent;
  final Set<int> _wishedEventIds = {};
  final Map<int, int> _wishIdByEvent = {};

  // Search + category + filter behaviour mirrors the Home page.
  String _searchQuery = '';
  bool _showSuggestions = false;
  final Set<int> _selectedCategoryIds = {};
  EventFilter _filter = const EventFilter();
  double _maxPriceBound = 1000000;
  late LatLng _userLocation;
  bool _mapCentered = false;
  double _mapZoom = 12;

  bool _loading = true;
  String? _error;

  /// Drives the smooth "fly to event" camera animation.
  late final AnimationController _flyController;
  LatLng? _flyFrom;
  LatLng? _flyTo;
  double _flyFromZoom = 12;
  double _flyToZoom = 12;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(_onFlyTick);
    _userLocation = LocationService.currentOrFallback;
    LocationService.position.addListener(_onLocationChanged);
    LocationService.ensureResolved();
    _load();
  }

  @override
  void dispose() {
    _flyController.dispose();
    LocationService.position.removeListener(_onLocationChanged);
    _searchController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  /// Animates the camera from its current position to [target] / [zoom].
  void _animateTo(LatLng target, double zoom) {
    try {
      final camera = _mapController.camera;
      _flyFrom = camera.center;
      _flyFromZoom = camera.zoom;
    } catch (_) {
      _mapController.move(target, zoom);
      return;
    }
    _flyTo = target;
    _flyToZoom = zoom;
    _flyController.forward(from: 0);
  }

  void _onFlyTick() {
    final from = _flyFrom;
    final to = _flyTo;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_flyController.value);
    _mapController.move(
      LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ),
      _flyFromZoom + (_flyToZoom - _flyFromZoom) * t,
    );
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final next = LocationService.currentOrFallback;
    setState(() => _userLocation = next);
    if (_mapCentered) return;
    _mapCentered = true;
    if (next == kDefaultCenter) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(next, 14);
    });
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
      final eventCategories = await _optional(
        CategoryApiService.getAllEventCategories,
        const <EventCategoryModel>[],
      );
      final tickets = await _optional(
        TicketTypeApiService.getAllTicketTypes,
        const <TicketTypeModel>[],
      );

      final categoryIdByEvent = <int, Set<int>>{};
      for (final ec in eventCategories) {
        categoryIdByEvent
            .putIfAbsent(ec.eventId, () => <int>{})
            .add(ec.categoryId);
      }

      final usedIds = <int>{};
      for (final e in events) {
        usedIds.addAll(categoryIdByEvent[e.id] ?? const <int>{});
      }

      final pins = <_CategoryPin>[];
      for (final c in categories) {
        if (!usedIds.contains(c.id)) continue;
        pins.add(
          _CategoryPin(
            id: c.id,
            name: c.name,
            color: categoryColorFor(c.name),
            icon: iconForKey(c.iconPath ?? ''),
          ),
        );
      }

      final imageByEvent = <int, EventImageModel>{};
      for (final img in images) {
        if (img.isThumbnail || !imageByEvent.containsKey(img.eventId)) {
          imageByEvent[img.eventId] = img;
        }
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

      if (!mounted) return;
      setState(() {
        _events = events..sort((a, b) => a.start.compareTo(b.start));
        _imageByEvent = imageByEvent;
        _organizerById = {for (final o in organizers) o.id: o};
        _categoryIdByEvent = categoryIdByEvent;
        _categories = pins;
        _minPriceByEvent = minPriceByEvent;
        if (_filter.maxPrice > priceBound) {
          _filter = _filter.copyWith(maxPrice: priceBound);
        }
        _maxPriceBound = priceBound;
        _loading = false;
      });

      await _refreshWishes();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final list = _results;
        if (list.isNotEmpty) _focusEvent(list.first);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
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

  Future<void> _refreshWishes() async {
    final session = AuthService.currentSession;
    if (session == null) return;
    final wishes = await _optional(
      WishlistApiService.getAllWishes,
      const <WishlistModel>[],
    );
    if (!mounted) return;
    setState(() {
      _wishCounts.clear();
      for (final w in wishes) {
        _wishCounts[w.eventId] = (_wishCounts[w.eventId] ?? 0) + 1;
      }
      _wishedEventIds
        ..clear()
        ..addAll(wishes
            .where((w) => w.accountId == session.accountId)
            .map((w) => w.eventId));
      _wishIdByEvent.clear();
      for (final w in wishes) {
        if (w.accountId == session.accountId) {
          _wishIdByEvent[w.eventId] = w.id;
        }
      }
    });
  }

  /// The cards shown in the bottom panel:
  /// - Zoomed out: the pinned event (from a map tap), then the wished events
  ///   that still match the current search / category / filter query.
  /// - Zoomed in: the pinned event, then the events currently visible on the
  ///   map viewport, nearest to the screen centre first.
  List<EventModel> get _cardEvents {
    final result = <EventModel>[];
    final pinned = _pinnedEvent;
    if (pinned != null && _events.any((e) => e.id == pinned.id)) {
      result.add(pinned);
    }

    final zoomedIn = _isZoomedIn;
    final source = zoomedIn ? _visibleEvents() : _events;
    for (final e in source) {
      if (pinned != null && e.id == pinned.id) continue;
      if (result.any((r) => r.id == e.id)) continue;
      if (!zoomedIn && !_wishedEventIds.contains(e.id)) continue;
      if (!_passes(e)) continue;
      result.add(e);
    }
    return result;
  }

  bool get _isZoomedIn => _mapZoom >= _zoomInThreshold;

  /// Events inside the current map viewport, nearest to the screen centre
  /// first. Only meaningful while zoomed in.
  List<EventModel> _visibleEvents() {
    try {
      final camera = _mapController.camera;
      final bounds = camera.visibleBounds;
      final center = camera.center;
      final visible = <EventModel>[];
      for (final e in _events) {
        final p = LatLng(e.latitude, e.longitude);
        if (!bounds.contains(p)) continue;
        visible.add(e);
      }
      visible.sort((a, b) {
        final aLat = a.latitude - center.latitude;
        final aLng = a.longitude - center.longitude;
        final bLat = b.latitude - center.latitude;
        final bLng = b.longitude - center.longitude;
        return (aLat * aLat + aLng * aLng).compareTo(bLat * bLat + bLng * bLng);
      });
      return visible.take(_maxVisibleCards).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------- search / category / filter (Home page parity) ----------------

  double _distanceKm(EventModel event) {
    return _distance.as(
      LengthUnit.Kilometer,
      _userLocation,
      LatLng(event.latitude, event.longitude),
    );
  }

  int _popularity(EventModel event) => _wishCounts[event.id] ?? 0;

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

  /// Whether an event survives the current search / category / filter query
  /// (used both for the marker list and for the wished events in the card
  /// panel).
  bool _passes(EventModel event) {
    final q = _searchQuery.trim().toLowerCase();
    final hasSearch = q.isNotEmpty;
    final hasCats = _selectedCategoryIds.isNotEmpty;
    final filtersActive = _filter.hasConstraints;
    final hasConstraints = hasSearch || hasCats || filtersActive;
    if (!hasConstraints) return true;

    final eventCats = _categoryIdByEvent[event.id] ?? const <int>{};
    final searchHit = hasSearch &&
        (event.name.toLowerCase().contains(q) ||
            (_organizerById[event.organizerId]?.name.toLowerCase() ?? '')
                .contains(q));
    final catHit = hasCats &&
        eventCats.intersection(_selectedCategoryIds).isNotEmpty;
    final filterHit =
        _withinPrice(event) && _withinPeriod(event) && _withinDistance(event);

    var dims = 0;
    if (hasSearch && searchHit) dims++;
    if (hasCats && catHit) dims++;
    if (filtersActive && filterHit) dims++;
    return dims > 0;
  }

  /// Ranked event list for the map markers, using the same relevance scoring
  /// as the Home page: search + categories + filters each score, and matching
  /// every active criterion earns a big bonus.
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
      final eventCats = _categoryIdByEvent[event.id] ?? const <int>{};

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

  // ---------------- interactions ----------------

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _showSuggestions = value.trim().isNotEmpty;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _showSuggestions = false;
    });
    _resetToFirstResult();
  }

  /// Name / organizer matches for the current query, prefix matches first.
  List<EventModel> get _suggestions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = _events.where((e) {
      if (e.name.toLowerCase().contains(q)) return true;
      final organizer = _organizerById[e.organizerId]?.name.toLowerCase() ?? '';
      return organizer.contains(q);
    }).toList();
    matches.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches.take(8).toList();
  }

  void _selectSuggestion(EventModel event) {
    FocusScope.of(context).unfocus();
    _searchController.text = event.name;
    _searchController.selection = TextSelection.collapsed(
      offset: event.name.length,
    );
    setState(() {
      _searchQuery = event.name;
      _showSuggestions = false;
    });
    _selectEvent(event);
  }

  void _toggleCategory(int id) {
    setState(() {
      if (!_selectedCategoryIds.remove(id)) _selectedCategoryIds.add(id);
    });
    _resetToFirstResult();
  }

  Future<void> _openFilterSheet() async {
    final result = await showEventFilterSheet(
      context,
      current: _filter,
      maxBound: _maxPriceBound,
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _resetToFirstResult();
    }
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _showSuggestions = false;
      _selectedCategoryIds.clear();
      _filter = const EventFilter();
    });
    _resetToFirstResult();
  }

  void _focusEvent(EventModel event) {
    final zoom = _mapZoom >= _zoomInThreshold ? _mapZoom : 14.0;
    _animateTo(LatLng(event.latitude, event.longitude), zoom);
  }

  void _selectEvent(EventModel event) {
    setState(() {
      _pinnedEvent = event;
      _showSuggestions = false;
    });
    if (_cardController.hasClients) _cardController.jumpToPage(0);
    _focusEvent(event);
  }

  void _onCardChanged(int index) {
    final list = _cardEvents;
    if (index >= 0 && index < list.length) _focusEvent(list[index]);
  }

  void _resetToFirstResult() {
    final list = _results;
    if (list.isEmpty) return;
    if (_cardController.hasClients) _cardController.jumpToPage(0);
    _focusEvent(list.first);
  }

  Future<void> _goToMyLocation() async {
    await LocationService.ensureResolved();
    if (!mounted) return;
    _animateTo(LocationService.currentOrFallback, 14);
  }

  /// Animates the camera zoom by [delta] levels, keeping the same centre.
  void _zoomBy(double delta) {
    try {
      final camera = _mapController.camera;
      final target = (camera.zoom + delta).clamp(3.0, 19.0);
      if (target == camera.zoom) return;
      _animateTo(camera.center, target);
    } catch (_) {}
  }

  Future<void> _toggleWish(EventModel event) async {
    final session = AuthService.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save events')),
      );
      return;
    }

    if (_wishedEventIds.contains(event.id)) {
      final wishId = _wishIdByEvent[event.id];
      if (wishId != null) {
        await _optional(() => WishlistApiService.deleteWishById(wishId), null);
      }
    } else {
      await _optional(
        () => WishlistApiService.createWish(
          accountId: session.accountId,
          eventId: event.id,
        ),
        null,
      );
    }
    await _refreshWishes();
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
          saved: _wishedEventIds.contains(event.id),
          onToggleWish: (e) => _toggleWish(e),
          minPrice: _minPriceByEvent[event.id],
          categories: _categoriesForEvent(event),
        ),
      ),
    );
  }

  List<CategoryModel> _categoriesForEvent(EventModel event) {
    final ids = _categoryIdByEvent[event.id];
    if (ids == null || ids.isEmpty) return const [];
    return [
      for (final category in _categories)
        if (ids.contains(category.id))
          CategoryModel(id: category.id, name: category.name),
    ];
  }

  void _showCategoriesSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Categories',
                        style: TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSearchAndFilters,
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFF7C4DFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_categories.isEmpty)
                  const Text(
                    'No categories available',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  for (final c in _categories)
                    ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _toggleCategory(c.id);
                      },
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(c.icon, size: 18, color: Colors.white),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: _selectedCategoryIds.contains(c.id)
                          ? const Icon(Icons.check_circle, color: Color(0xFF7C4DFF))
                          : const Icon(
                              Icons.radio_button_unchecked,
                              color: Colors.grey,
                            ),
                    ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _toggleCategory(_categories.isNotEmpty ? -1 : 0);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        body: Stack(
          children: [
            _mapView(),
            _topBar(),
            if (_categories.isNotEmpty) _fab(),
            if (!_loading) _zoomControls(),
            if (!_loading && _error == null && _cardEvents.isNotEmpty)
              _bottomCards(),
            if (!_loading &&
                _error == null &&
                _results.isNotEmpty &&
                _cardEvents.isEmpty)
              _cardHint(),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: kAccent),
              ),
            if (_error != null && !_loading) _errorView(),
            if (!_loading && _error == null && _results.isEmpty) _emptyView(),
            Positioned(
              left: 8,
              bottom: 194,
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 12,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && _flyController.isAnimating) {
            _flyController.stop();
          }
          final zoom = camera.zoom.floorToDouble();
          if (_mapZoom != zoom) {
            setState(() => _mapZoom = zoom);
          }
        },
        onTap: (tapPosition, latLng) {
          if (_showSuggestions) {
            setState(() => _showSuggestions = false);
          }
          if (_pinnedEvent != null) {
            setState(() => _pinnedEvent = null);
            if (_cardController.hasClients) _cardController.jumpToPage(0);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.reservation_system',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: _userLocation,
              width: 24,
              height: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            ..._buildEventMarkers(),
          ],
        ),
      ],
    );
  }

  Widget _buildPin(EventModel event) {
    final pin = _categoryForEvent(event);
    final color = pin?.color ?? kAccent;
    final icon = pin?.icon ?? Icons.event;
    return GestureDetector(
      onTap: () => _selectEvent(event),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Transform.rotate(
              angle: 0.7853982,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -13),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      Color.lerp(color, Colors.black, 0.18)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Groups events that land on the same screen cell at the current zoom into
  /// a single numbered cluster marker. Zooming the map in splits them apart,
  /// so far-away clusters never overlap and the layer stays fast.
  List<Marker> _buildEventMarkers() {
    return _clusterEvents(_results, _mapZoom).map((cluster) {
      if (cluster.events.length == 1) {
        final e = cluster.events.first;
        return Marker(
          point: LatLng(e.latitude, e.longitude),
          width: 46,
          height: 56,
          child: _buildPin(e),
        );
      }
      return Marker(
        point: cluster.center,
        width: 42,
        height: 42,
        child: _buildCluster(cluster),
      );
    }).toList();
  }

  List<_EventCluster> _clusterEvents(List<EventModel> events, double zoom) {
    final scale = 256 * math.pow(2, zoom).toDouble();
    // Approximate screen size of a marker pin in pixels.
    const cell = 70.0;
    final cells = <String, _EventCluster>{};
    for (final e in events) {
      final x = ((e.longitude + 180) / 360) * scale;
      final latRad = e.latitude * math.pi / 180;
      final y =
          (1 -
                  math.log(math.tan(latRad) + 1 / math.cos(latRad)) /
                      math.pi) /
              2 *
              scale;
      final key = '${(x / cell).floor()},${(y / cell).floor()}';
      final entry = cells[key];
      if (entry == null) {
        cells[key] = _EventCluster(LatLng(e.latitude, e.longitude), [e]);
      } else {
        entry.events.add(e);
        final count = entry.events.length;
        entry.center = LatLng(
          (entry.center.latitude * (count - 1) + e.latitude) / count,
          (entry.center.longitude * (count - 1) + e.longitude) / count,
        );
      }
    }
    return cells.values.toList();
  }

  Widget _buildCluster(_EventCluster cluster) {
    return GestureDetector(
      onTap: () {
        _animateTo(cluster.center, math.min(_mapZoom + 2, 19));
      },
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kAccent.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${cluster.events.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _CategoryPin? _categoryForEvent(EventModel event) {
    final ids = _categoryIdByEvent[event.id];
    if (ids == null) return null;
    for (final id in ids) {
      for (final pin in _categories) {
        if (pin.id == id) return pin;
      }
    }
    return null;
  }

  Widget _topBar() {
    final suggestions = _suggestions;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _searchRow(),
                  const SizedBox(height: 10),
                  _pillRow(),
                ],
              ),
              if (_showSuggestions && suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 54),
                  child: _suggestionList(suggestions),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionList(List<EventModel> suggestions) {
    return Material(
      elevation: 6,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = suggestions[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.event, color: kAccent, size: 20),
              title: Text(
                event.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                event.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () => _selectSuggestion(event),
            );
          },
        ),
      ),
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                const Icon(Icons.chevron_left, color: Colors.black45, size: 24),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Find events, workshops or other activities...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, color: Colors.grey, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _toolButton(
          icon: Icons.tune,
          active: _filter.isActive,
          onTap: _openFilterSheet,
        ),
        const SizedBox(width: 8),
        _toolButton(
          icon: Icons.my_location,
          active: false,
          onTap: _goToMyLocation,
        ),
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: active ? kAccent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : kAccent,
          size: 22,
        ),
      ),
    );
  }

  Widget _pillRow() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _pill(_categories[index]),
      ),
    );
  }

  Widget _pill(_CategoryPin pin) {
    final selected = _selectedCategoryIds.contains(pin.id);
    return GestureDetector(
      onTap: () => _toggleCategory(pin.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pin.color,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : pin.icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              pin.name,
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

  Widget _fab() {
    return Positioned(
      right: 16,
      bottom: 208,
      child: FloatingActionButton(
        heroTag: 'map-layers',
        onPressed: _showCategoriesSheet,
        backgroundColor: kAccent,
        elevation: 4,
        child: const Icon(Icons.layers, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _zoomControls() {
    return Positioned(
      right: 16,
      bottom: 276,
      child: Column(
        children: [
          _zoomButton(Icons.add, () => _zoomBy(1)),
          const SizedBox(height: 10),
          _zoomButton(Icons.remove, () => _zoomBy(-1)),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Icon(icon, color: kAccent, size: 22),
      ),
    );
  }

  Widget _bottomCards() {
    final list = _cardEvents;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: 150,
        child: PageView.builder(
          controller: _cardController,
          itemCount: list.length,
          onPageChanged: _onCardChanged,
          itemBuilder: (context, index) => _eventCard(list[index]),
        ),
      ),
    );
  }

  Widget _cardHint() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.favorite_border, color: kAccent, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap a pin on the map to see event details',
                style: TextStyle(
                  color: Color(0xFF616161),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(EventModel event) {
    final image = _imageByEvent[event.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: GestureDetector(
        onTap: () => _openEventDetail(event),
        child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumbnail(image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCardDate(event.start),
                          style: const TextStyle(
                            color: kAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _toggleWish(event),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _wishedEventIds.contains(event.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: _wishedEventIds.contains(event.id)
                        ? kPink
                        : Colors.grey,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _thumbnail(EventImageModel? image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 88,
        height: 108,
        child: _image(image),
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
      child: const Icon(Icons.event, color: Color(0xFFBDBDBD), size: 28),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF757575)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: kAccent),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'No events match your search',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatCardDate(DateTime d) {
    int hour = d.hour % 12;
    if (hour == 0) hour = 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${_weekdays[d.weekday - 1]}, '
        '${_months[d.month - 1]} ${d.day} · '
        '$hour:${_two(d.minute)} $ampm';
  }
}

/// Pairs an event with its relevance score in the ranked result list.
class _ScoredEvent {
  _ScoredEvent(this.event, this.score);

  final EventModel event;
  final int score;
}

/// Events that share a screen cell at the current zoom. [center] is the
/// average of the clustered points so tapping a cluster jumps to its group.
class _EventCluster {
  _EventCluster(this.center, this.events);

  LatLng center;
  final List<EventModel> events;
}