import 'package:flutter/material.dart';
import '../../services/event_organizer_api_service.dart';

/// Dedicated to EventOrganizerForm / event_organizer_api_service.dart.
/// Kept separate from the shared OrganizerSearchDialog (which still reads
/// EventOrganizer from event_api_service.dart and is used by
/// event_info_form.dart) so changes to either service don't collide.
class EventOrganizerSearchDialog extends StatefulWidget {
  final List<EventOrganizer> organizers;
  const EventOrganizerSearchDialog({super.key, required this.organizers});

  @override
  State<EventOrganizerSearchDialog> createState() =>
      _EventOrganizerSearchDialogState();
}

class _EventOrganizerSearchDialogState
    extends State<EventOrganizerSearchDialog> {
  final _searchController = TextEditingController();
  late List<EventOrganizer> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.organizers;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.organizers.where((org) {
        return org.name.toLowerCase().contains(query) ||
            org.id.toString().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No organizers found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final org = _filtered[index];
                        return ListTile(
                          title: Text(
                            org.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${org.id}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => Navigator.pop(context, org),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
