import 'package:flutter/material.dart';
import '../../services/event_api_service.dart';

class EventSearchDialog extends StatefulWidget {
  final List<EventModel> events;
  const EventSearchDialog({super.key, required this.events});

  @override
  State<EventSearchDialog> createState() => _EventSearchDialogState();
}

class _EventSearchDialogState extends State<EventSearchDialog> {
  final _searchController = TextEditingController();
  late List<EventModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.events;
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
      _filtered = widget.events.where((e) {
        return e.name.toLowerCase().contains(query) ||
            e.id.toString().contains(query);
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
                        'No events found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final event = _filtered[index];
                        return ListTile(
                          title: Text(
                            event.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${event.id}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => Navigator.pop(context, event),
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
