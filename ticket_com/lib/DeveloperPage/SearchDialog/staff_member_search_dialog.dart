import 'package:flutter/material.dart';
import '../../services/organizer_member_api_service.dart';

class StaffMemberSearchDialog extends StatefulWidget {
  final List<OrganizerMemberModel> members;
  final String Function(OrganizerMemberModel member) labelBuilder;
  final String Function(OrganizerMemberModel member) subtitleBuilder;

  const StaffMemberSearchDialog({
    super.key,
    required this.members,
    required this.labelBuilder,
    required this.subtitleBuilder,
  });

  @override
  State<StaffMemberSearchDialog> createState() =>
      _StaffMemberSearchDialogState();
}

class _StaffMemberSearchDialogState extends State<StaffMemberSearchDialog> {
  final _controller = TextEditingController();
  late List<OrganizerMemberModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.members;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.members.where((m) {
        return q.isEmpty ||
            m.id.toString().contains(q) ||
            widget.labelBuilder(m).toLowerCase().contains(q) ||
            widget.subtitleBuilder(m).toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 420,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _filter,
                style: const TextStyle(color: Color(0xFF212121)),
                decoration: InputDecoration(
                  hintText: 'Search by ID, account, or organizer',
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
                        'No organizer members found',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final m = _filtered[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2A2A2A),
                            child: Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF757575),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            widget.labelBuilder(m),
                            style: const TextStyle(color: Color(0xFF212121)),
                          ),
                          subtitle: Text(
                            'ID: ${m.id}  •  ${widget.subtitleBuilder(m)}',
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
                          ),
                          onTap: () => Navigator.pop(context, m),
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
