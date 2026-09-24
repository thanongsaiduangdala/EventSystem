import 'package:flutter/material.dart';
import '../../services/event_api_service.dart';

class OrganizerSearchDialog extends StatefulWidget {
  final List<EventOrganizer> organizers;
  const OrganizerSearchDialog({super.key, required this.organizers});

  @override
  State<OrganizerSearchDialog> createState() => _OrganizerSearchDialogState();
}

class _OrganizerSearchDialogState extends State<OrganizerSearchDialog> {
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
                style: const TextStyle(color: Color(0xFF212121)),
                decoration: InputDecoration(
                  hintText: 'Search by name or ID',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0x33000000)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5B4DFF)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No organizers found',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final org = _filtered[index];
                        return ListTile(
                          title: Text(
                            org.name,
                            style: const TextStyle(color: Color(0xFF212121)),
                          ),
                          subtitle: Text(
                            'ID: ${org.id}',
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
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
