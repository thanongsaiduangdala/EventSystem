import 'package:flutter/material.dart';
import '../../services/ticket_type_api_service.dart';

class TicketTypeTablePage extends StatefulWidget {
  const TicketTypeTablePage({super.key});

  @override
  State<TicketTypeTablePage> createState() => TicketTypeTablePageState();
}

class TicketTypeTablePageState extends State<TicketTypeTablePage> {
  List<TicketTypeModel> _ticketTypes = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await TicketTypeApiService.getAllTicketTypes();
      if (!mounted) return;
      setState(() => _ticketTypes = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(TicketTypeModel ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete ticket type?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete "${ticket.typeName}".',
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
        await TicketTypeApiService.deleteTicketType(ticket.id);
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openFormDialog({TicketTypeModel? existing}) async {
    final isEditing = existing != null;

    final eventIdController = TextEditingController(
      text: existing?.eventId.toString() ?? '',
    );
    final typeNameController = TextEditingController(
      text: existing?.typeName ?? '',
    );
    final priceController = TextEditingController(
      text: existing?.priceInKip.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: existing?.capacity.toString() ?? '',
    );
    final saleStartController = TextEditingController(
      text: existing?.saleStart ?? '',
    );
    final saleEndController = TextEditingController(
      text: existing?.saleEnd ?? '',
    );

    Widget field(
      TextEditingController controller,
      String label, {
      TextInputType? keyboardType,
      String? hint,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          isEditing ? 'Edit Ticket Type' : 'Add Ticket Type',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(
                  eventIdController,
                  'Event ID',
                  keyboardType: TextInputType.number,
                ),
                field(typeNameController, 'Type Name (e.g. VIP, Standard)'),
                field(
                  priceController,
                  'Price (Kip)',
                  keyboardType: TextInputType.number,
                ),
                field(
                  capacityController,
                  'Capacity',
                  keyboardType: TextInputType.number,
                ),
                field(
                  saleStartController,
                  'Sale Start',
                  hint: 'YYYY-MM-DD HH:MM:SS',
                ),
                field(
                  saleEndController,
                  'Sale End',
                  hint: 'YYYY-MM-DD HH:MM:SS',
                ),
              ],
            ),
          ),
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

    if (saved != true) return;

    final eventId = int.tryParse(eventIdController.text.trim());
    final price = int.tryParse(priceController.text.trim());
    final capacity = int.tryParse(capacityController.text.trim());

    if (eventId == null || price == null || capacity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event ID, Price, and Capacity must be numbers'),
        ),
      );
      return;
    }

    try {
      if (isEditing) {
        await TicketTypeApiService.updateTicketType(
          ticketTypeId: existing.id,
          eventId: eventId,
          typeName: typeNameController.text.trim(),
          priceInKip: price,
          capacity: capacity,
          saleStart: saleStartController.text.trim(),
          saleEnd: saleEndController.text.trim(),
        );
      } else {
        await TicketTypeApiService.createTicketType(
          eventId: eventId,
          typeName: typeNameController.text.trim(),
          priceInKip: price,
          capacity: capacity,
          saleStart: saleStartController.text.trim(),
          saleEnd: saleEndController.text.trim(),
        );
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E1E1E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openFormDialog(),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1E1E)),
          dataRowColor: WidgetStateProperty.all(Colors.black),
          columns: const [
            DataColumn(
              label: Text('ID', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Event ID', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Type Name', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Price (Kip)', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Capacity', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Sale Start', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Sale End', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Actions', style: TextStyle(color: Colors.white)),
            ),
          ],
          rows: _ticketTypes.map((ticket) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '${ticket.id}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    '${ticket.eventId}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    ticket.typeName,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DataCell(
                  Text(
                    '${ticket.priceInKip}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                DataCell(
                  Text(
                    '${ticket.capacity}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                DataCell(
                  Text(
                    ticket.saleStart,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                DataCell(
                  Text(
                    ticket.saleEnd,
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
                        onPressed: () => _openFormDialog(existing: ticket),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(ticket),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
