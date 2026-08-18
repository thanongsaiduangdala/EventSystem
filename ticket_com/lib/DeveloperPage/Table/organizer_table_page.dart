import 'package:flutter/material.dart';
import '../../services/event_api_service.dart';

class OrganizerTablePage extends StatefulWidget {
  const OrganizerTablePage({super.key});

  @override
  State<OrganizerTablePage> createState() => OrganizerTablePageState();
}

class OrganizerTablePageState extends State<OrganizerTablePage> {
  List<EventOrganizer> _organizers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await EventApiService.getAllOrganizers();
      if (!mounted) return;
      setState(() => _organizers = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(EventOrganizer org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete organizer?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${org.name}".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EventApiService.deleteOrganizer(org.id);
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openEditDialog(EventOrganizer org) async {
    final nameController = TextEditingController(text: org.name);
    final descController = TextEditingController(text: org.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Edit Organizer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await EventApiService.updateOrganizer(
          id: org.id,
          name: nameController.text.trim(),
          logoPath: org.logoPath,
          createdByAccountId: org.createdByAccountId,
          description: descController.text.trim(),
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1E1E)),
        dataRowColor: WidgetStateProperty.all(Colors.black),
        columns: const [
          DataColumn(
            label: Text('ID', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Name', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Description', style: TextStyle(color: Colors.white)),
          ),
          DataColumn(
            label: Text('Actions', style: TextStyle(color: Colors.white)),
          ),
        ],
        rows: _organizers.map((org) {
          return DataRow(
            cells: [
              DataCell(
                Text('${org.id}', style: const TextStyle(color: Colors.white)),
              ),
              DataCell(
                Text(org.name, style: const TextStyle(color: Colors.white)),
              ),
              DataCell(
                Text(
                  org.description ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => _openEditDialog(org),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _confirmDelete(org),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
