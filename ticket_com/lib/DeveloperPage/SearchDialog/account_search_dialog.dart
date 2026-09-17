import 'package:flutter/material.dart';
import '../../services/event_organizer_api_service.dart';

class AccountSearchDialog extends StatefulWidget {
  final List<VerifiedAccount> accounts;
  const AccountSearchDialog({super.key, required this.accounts});

  @override
  State<AccountSearchDialog> createState() => _AccountSearchDialogState();
}

class _AccountSearchDialogState extends State<AccountSearchDialog> {
  final _controller = TextEditingController();
  late List<VerifiedAccount> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.accounts;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.accounts.where((a) {
        return q.isEmpty ||
            a.id.toString().contains(q) ||
            a.fullName.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _filter,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by ID, name, or email',
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
                        'No verified accounts found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final a = _filtered[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2A2A2A),
                            child: Icon(
                              Icons.verified_user,
                              color: Colors.greenAccent,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            a.fullName.isEmpty
                                ? 'Account #${a.id}'
                                : a.fullName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${a.id}'
                            '${a.email.isNotEmpty ? '  •  ${a.email}' : ''}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => Navigator.pop(context, a),
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
