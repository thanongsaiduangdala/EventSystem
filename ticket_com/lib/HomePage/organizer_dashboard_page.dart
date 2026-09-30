import 'package:flutter/material.dart';
import 'package:ticket_com/HomePage/become_organizer_page.dart';
import 'package:ticket_com/HomePage/event_analytics_page.dart';
import 'package:ticket_com/HomePage/event_form_page.dart';
import 'package:ticket_com/HomePage/organizer_invite_page.dart';
import 'package:ticket_com/HomePage/pill_toggle.dart';
import 'package:ticket_com/HomePage/team_images.dart';
import 'package:ticket_com/HomePage/team_member_dashboard_page.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/organizer_member_api_service.dart';
import 'package:ticket_com/services/ticket_type_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kGreen = Color(0xFF2E9E5B);
const Color _kAmber = Color(0xFFB26A00);
const Color _kRed = Color(0xFFE53935);

class OrganizerDashboardPage extends StatefulWidget {
  const OrganizerDashboardPage({super.key});

  @override
  State<OrganizerDashboardPage> createState() => _OrganizerDashboardPageState();
}

class _OrganizerDashboardPageState extends State<OrganizerDashboardPage> {
  bool _loading = true;
  String? _error;

  int _accountId = 0;

  List<EventOrganizer> _myOrganizers = [];
  List<EventModel> _myEvents = [];
  List<EventOrganizer> _allOrganizers = [];

  List<TeamMembership> _memberships = [];

  EventOrganizer? _pendingOrganizer;

  List<OrganizerMemberDetail> _invites = [];

  int? _tabIndex;

  int _memberSection = 0;
  final _eventSearch = TextEditingController();
  int? _statusFilter;
  bool? _visibleFilter;

  List<EventModel> get _filteredEvents {
    final query = _eventSearch.text.trim().toLowerCase();
    return _myEvents.where((e) {
      if (_statusFilter != null && e.eventStatusId != _statusFilter) {
        return false;
      }
      if (_visibleFilter != null && e.eventVisible != _visibleFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final name = e.name.toLowerCase();
        final org = _organizerNameFor(e.organizerId).toLowerCase();
        if (!name.contains(query) && !org.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  Map<int, EventImageModel> _coverByEvent = {};
  Set<int> _eventsWithTickets = {};
  bool _ticketInfoKnown = false;

  EventOrganizer? get _primaryOrganizer =>
      _myOrganizers.isEmpty ? null : _myOrganizers.first;

  @override
  void initState() {
    super.initState();
    _accountId = AuthService.currentSession?.accountId ?? 0;
    _load();
  }

  @override
  void dispose() {
    _eventSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final organizers =
          await EventApiService.getAllOrganizers(includeUnapproved: true);
      final mine = organizers
          .where((o) => o.createdByAccountId == _accountId)
          .toList();
      final myOrganizers = mine.where((o) => o.isApproved).toList();
      final unapproved = mine.where((o) => !o.isApproved).toList()
        ..sort((a, b) => (a.isPending ? 0 : 1).compareTo(b.isPending ? 0 : 1));
      final myIds = myOrganizers.map((o) => o.id).toSet();

      List<EventModel> events = [];
      if (myIds.isNotEmpty) {
        final all = await EventApiService.getAllEventsWithStatus();
        events = all.where((e) => myIds.contains(e.organizerId)).toList();
      }

      var memberships = <TeamMembership>[];
      try {
        memberships = await OrganizerMemberApiService.getMyMemberships();
      } catch (_) {}

      var invites = <OrganizerMemberDetail>[];
      try {
        invites = await OrganizerMemberApiService.getMyInvites();
      } catch (_) {}

      final coverByEvent = <int, EventImageModel>{};
      final eventsWithTickets = <int>{};
      var ticketInfoKnown = false;
      if (events.isNotEmpty) {
        final eventIds = events.map((e) => e.id).toSet();
        try {
          final images = await EventImageApiService.getAllEventImages();
          for (final image in images) {
            if (!eventIds.contains(image.eventId)) continue;
            if (image.isThumbnail || !coverByEvent.containsKey(image.eventId)) {
              coverByEvent[image.eventId] = image;
            }
          }
        } catch (_) {
        }
        try {
          final tickets = await TicketTypeApiService.getAllTicketTypes();
          eventsWithTickets.addAll(tickets.map((t) => t.eventId));
          ticketInfoKnown = true;
        } catch (_) {
        }
      }

      if (!mounted) return;
      setState(() {
        _myOrganizers = myOrganizers;
        _pendingOrganizer = unapproved.isEmpty ? null : unapproved.first;
        _allOrganizers = organizers;
        _myEvents = events;
        _coverByEvent = coverByEvent;
        _eventsWithTickets = eventsWithTickets;
        _ticketInfoKnown = ticketInfoKnown;
        _memberships = memberships;
        _invites = invites;
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


  void _openCreateEvent() {
    final organizerId = _primaryOrganizer?.id;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EventFormPage(organizerId: organizerId),
      ),
    ).then((saved) {
      if (saved == true) {
        _snack('Event created. It will be visible after approval.');
        _load();
      }
    });
  }

  void _openEditEvent(EventModel event) {
    final wasDenied = event.eventStatusId == EventStatus.denied;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EventFormPage(event: event)),
    ).then((saved) {
      if (saved == true) {
        _snack(wasDenied
            ? 'Event updated and resubmitted for approval.'
            : 'Event updated.');
        _load();
      }
    });
  }

  Future<void> _openAnalytics(EventModel event) async {
    List<TicketTypeModel> tickets = const [];
    try {
      tickets = await TicketTypeApiService.getTicketTypesByEvent(event.id);
    } catch (_) {
    }
    if (!mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventAnalyticsPage(event: event, ticketTypes: tickets),
      ),
    );
  }

  Future<void> _toggleEventVisibility(EventModel event, bool visible) async {
    final index = _myEvents.indexWhere((e) => e.id == event.id);
    if (index == -1) return;
    final previous = _myEvents[index];
    setState(() => _myEvents[index] = previous.copyWith(eventVisible: visible));
    try {
      await EventApiService.setEventVisibility(
        eventId: event.id,
        eventVisible: visible,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _myEvents[index] = previous);
      _snack('Could not update visibility: $e');
    }
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Remove event?', style: TextStyle(color: _kTextDark)),
        content: Text(
          'This will permanently delete "${event.name}".',
          style: const TextStyle(color: _kTextGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EventApiService.deleteEvent(event.id);
      if (!mounted) return;
      _snack('Event removed');
      _load();
    } catch (e) {
      _snack('Remove failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  @override
  Widget build(BuildContext context) {
    final organizer = _primaryOrganizer;
    final hasEvents = organizer != null;
    final ownIds = _myOrganizers.map((o) => o.id).toSet();
    final joined =
        _memberships.where((m) => !ownIds.contains(m.eventOrganizerId)).toList();
    final session = AuthService.currentSession;
    final isOrganizerAccount = hasEvents ||
        (session?.isOrganizer ?? false) ||
        (session?.isSuperAdmin ?? false);
    final ready = !_loading && _error == null;
    final tab = _tabIndex ??
        (hasEvents || _pendingOrganizer != null ? 0 : 2);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: Text(
          isOrganizerAccount ? 'Organization' : 'Org Team Member',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : _error != null
              ? _errorBox()
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tabBody(
                    tab: tab,
                    organizer: organizer,
                    ownIds: ownIds,
                    joined: joined,
                  ),
                ),
      bottomNavigationBar: ready
          ? NavigationBar(
              selectedIndex: tab,
              backgroundColor: Colors.white,
              indicatorColor: kAccent.withValues(alpha: 0.14),
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'My Events',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.groups_2_outlined),
                  selectedIcon: Icon(Icons.groups_2),
                  label: 'My Team',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _invites.isNotEmpty,
                    label: Text('${_invites.length}'),
                    child: const Icon(Icons.badge_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _invites.isNotEmpty,
                    label: Text('${_invites.length}'),
                    child: const Icon(Icons.badge),
                  ),
                  label: 'Team Member',
                ),
              ],
            )
          : null,
      floatingActionButton: ready && hasEvents && tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Event',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }

  Widget _eventsTab(EventOrganizer organizer) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _organizerHeader(organizer),
        const SizedBox(height: 20),
        _searchAndFilters(),
        const SizedBox(height: 16),
        _eventsSection(),
      ],
    );
  }

  Widget _organizerHeader(EventOrganizer organizer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kAccent, Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your organizer account',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      organizer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _headerStat('${_myEvents.length}', 'Events'),
              const Spacer(),
              if (_myOrganizers.length > 1)
                Text(
                  '${_myOrganizers.length} organizer profiles',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _searchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _eventSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search events by name or organizer...',
            hintStyle: const TextStyle(color: _kTextGrey, fontSize: 13.5),
            prefixIcon: const Icon(Icons.search, color: _kTextGrey),
            suffixIcon: _eventSearch.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, color: _kTextGrey, size: 20),
                    onPressed: () {
                      _eventSearch.clear();
                      setState(() {});
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
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Status: All',
                selected: _statusFilter == null,
                onTap: () => setState(() => _statusFilter = null),
              ),
              _filterChip(
                label: 'Approved',
                selected: _statusFilter == EventStatus.approved,
                onTap: () => setState(
                  () => _statusFilter = EventStatus.approved,
                ),
              ),
              _filterChip(
                label: 'Pending',
                selected: _statusFilter == EventStatus.pending,
                onTap: () => setState(
                  () => _statusFilter = EventStatus.pending,
                ),
              ),
              _filterChip(
                label: 'Denied',
                selected: _statusFilter == EventStatus.denied,
                onTap: () => setState(() => _statusFilter = EventStatus.denied),
              ),
              const SizedBox(width: 6),
              const VerticalDivider(width: 16, color: _kTextGrey),
              _filterChip(
                label: 'Visibility: All',
                selected: _visibleFilter == null,
                onTap: () => setState(() => _visibleFilter = null),
              ),
              _filterChip(
                label: 'Public',
                selected: _visibleFilter == true,
                onTap: () => setState(() => _visibleFilter = true),
              ),
              _filterChip(
                label: 'Not public',
                selected: _visibleFilter == false,
                onTap: () => setState(() => _visibleFilter = false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
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
        checkmarkColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? kAccent : const Color(0xFFD5D2EC),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _eventsSection() {
    final visible = _filteredEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'My Events',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${visible.length} / ${_myEvents.length}',
              style: const TextStyle(color: _kTextGrey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_myEvents.isEmpty)
          _emptyCard(
            icon: Icons.event_available_outlined,
            title: 'No events yet',
            message: 'Tap "Create Event" to add your first event, with its photos, '
                'categories, sponsors, ticket types and questions.',
          )
        else if (visible.isEmpty)
          _emptyCard(
            icon: Icons.search_off,
            title: 'No matching events',
            message: 'No events match your search and filters. Clear them to see '
                'everything.',
          )
        else
          ...visible.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _eventCard(e),
              )),
      ],
    );
  }

  Widget _eventThumb(EventModel event) {
    final cover = _coverByEvent[event.id];
    final placeholder = Container(
      color: const Color(0xFFEFEEFC),
      alignment: Alignment.center,
      child: Icon(
        cover == null ? Icons.add_photo_alternate_outlined : Icons.event,
        color: kAccent,
        size: 26,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: cover == null
            ? placeholder
            : Image.network(
                EventImageApiService.thumbnailUrl(cover.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }

  Widget _eventCard(EventModel event) {
    final orgName = _organizerNameFor(event.organizerId);
    final needsTickets =
        _ticketInfoKnown && !_eventsWithTickets.contains(event.id);
    return GestureDetector(
      onTap: () => _openAnalytics(event),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusChip(event.eventStatusId),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.bar_chart, color: kAccent, size: 20),
                  tooltip: 'Analytics',
                  onPressed: () => _openAnalytics(event),
                ),
                TextButton.icon(
                  onPressed: () => _openEditEvent(event),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88E5),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                  tooltip: 'Remove',
                  onPressed: () => _confirmDeleteEvent(event),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _eventThumb(event),
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
                          color: _kTextDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            color: _kTextGrey,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              orgName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kTextGrey,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fmt(event.start)}  \u2192  ${_fmt(event.end)}',
                        style: const TextStyle(color: _kTextGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  event.eventVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: event.eventVisible ? _kGreen : _kTextGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.eventVisible
                        ? 'Visible to the public'
                        : 'Hidden from the public',
                    style: const TextStyle(
                      color: _kTextGrey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: event.eventVisible,
                  activeThumbColor: _kGreen,
                  onChanged: (val) => _toggleEventVisibility(event, val),
                ),
              ],
            ),
            if (needsTickets) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: _kAmber,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No ticket types yet. Tap Edit to add some so people '
                        'can buy tickets.',
                        style: TextStyle(color: _kAmber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(int statusId) {
    final (bg, fg, label) = switch (statusId) {
      EventStatus.approved => (_kGreen, Colors.white, 'Approved'),
      EventStatus.denied => (_kRed, Colors.white, 'Denied'),
      _ => (const Color(0xFFFFF3E0), _kAmber, 'Pending Approval'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kTextGrey, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
        ],
      ),
    );
  }


  Widget _tabBody({
    required int tab,
    required EventOrganizer? organizer,
    required Set<int> ownIds,
    required List<TeamMembership> joined,
  }) {
    switch (tab) {
      case 0:
        return organizer != null
            ? _eventsTab(organizer)
            : _becomeOrganizerPrompt(
                key: const ValueKey('no-org-events'),
                icon: Icons.event_outlined,
                title: 'Create your own events',
                message: 'Want to create your own events and sell tickets? '
                    'Become your own Organizer.',
              );
      case 1:
        return organizer != null
            ? TeamMemberDashboardPage(
                key: const ValueKey('own-team-tab'),
                embedded: true,
                orgIds: ownIds,
              )
            : _becomeOrganizerPrompt(
                key: const ValueKey('no-org-team'),
                icon: Icons.groups_2_outlined,
                title: 'Build your own team',
                message: 'Want your own organization and team? Become your '
                    'own Organizer, then invite people and assign roles.',
              );
      default:
        return _teamMemberTab(joined);
    }
  }

  Widget _teamMemberTab(List<TeamMembership> joined) {
    return Column(
      key: const ValueKey('team-member-tab'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: PillToggle(
            labels: const ['Joined Org', 'Pending Org'],
            selected: _memberSection,
            badges: {1: _invites.length},
            onChanged: (i) => setState(() => _memberSection = i),
          ),
        ),
        Expanded(
          child: _memberSection == 0
              ? _joinedOrganizations(joined)
              : _pendingOrganizations(),
        ),
      ],
    );
  }

  Widget _becomeOrganizerPrompt({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final pending = _pendingOrganizer;
    if (pending != null) {
      return _orgReviewStatus(key: key, organizer: pending);
    }
    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kAccent, size: 40),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kTextGrey, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _openBecomeOrganizer,
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text(
            'Click here to become an Organizer',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Future<void> _openBecomeOrganizer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BecomeOrganizerPage()),
    );
    if (mounted) _load();
  }

  Widget _orgReviewStatus({Key? key, required EventOrganizer organizer}) {
    final denied = organizer.isDenied;
    final color = denied ? _kRed : kAccent;
    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              denied ? Icons.gpp_bad_outlined : Icons.hourglass_top,
              color: color,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          denied ? 'Organization not approved' : 'Organization pending approval',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          denied
              ? '“${organizer.name}” was not approved. Please contact '
                  'support if you think this is a mistake.'
              : '“${organizer.name}” has been submitted. An admin or employee '
                  'needs to approve your organization before you can create '
                  'events or build a team.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kTextGrey, fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh status'),
        ),
      ],
    );
  }

  Widget _joinedOrganizations(List<TeamMembership> joined) {
    return RefreshIndicator(
      key: const ValueKey('member-orgs'),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              const Text(
                'Organizations you joined',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${joined.length}',
                style: const TextStyle(color: _kTextGrey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap an organization to see your role and its events.',
            style: TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (joined.isEmpty)
            _infoCard(
              icon: Icons.groups_2_outlined,
              text: 'You have not joined another organization yet. When an '
                  'organization invites you, it shows up under Pending Org.',
            ),
          for (final m in joined) ...[
            _joinedOrgCard(m),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black26, size: 40),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextGrey, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _pendingOrganizations() {
    return RefreshIndicator(
      key: const ValueKey('member-invites'),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              const Text(
                'Invitations',
                style: TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${_invites.length}',
                style: const TextStyle(color: _kTextGrey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Organizations that invited you to join their team. Tap one to '
            'review it and join or decline.',
            style: TextStyle(color: _kTextGrey, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (_invites.isEmpty)
            _infoCard(
              icon: Icons.mark_email_unread_outlined,
              text: 'No pending invitations right now.',
            ),
          for (final invite in _invites) ...[
            _inviteCard(invite),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _inviteCard(OrganizerMemberDetail invite) {
    final name =
        invite.organizerName.isEmpty ? 'Organization' : invite.organizerName;
    final desc = invite.organizerDescription ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrganizerInvitePage(memberId: invite.id),
            ),
          );
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Color(0xFFFF8F00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kTextDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          invite.roleName.isEmpty
                              ? 'Invited to join their team'
                              : 'Invited as ${invite.roleName}',
                          style: const TextStyle(
                            color: _kTextGrey,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        color: _kAmber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _joinedOrgCard(TeamMembership m) {
    final name = m.organizerName.isEmpty ? 'Organization' : m.organizerName;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamMemberDashboardPage(
              membership: m,
              showOrgPicker: false,
              title: name,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              OrgLogo(path: m.organizerLogoPath, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.teamRoleName,
                      style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: _kTextGrey, size: 40),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextGrey),
            ),
            const SizedBox(height: 14),
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

  String _organizerNameFor(int organizerId) {
    final match = _allOrganizers.where((o) => o.id == organizerId);
    return match.isEmpty ? 'Organizer #$organizerId' : match.first.name;
  }

  String _fmt(DateTime dt) => '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
