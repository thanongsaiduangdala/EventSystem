import 'package:flutter/material.dart';
import '../../models/sponser_models.dart';
import '../../services/sponser_api_service.dart';

class SponserSearchDialog extends StatefulWidget {
  final List<SponserModel> sponsers;
  const SponserSearchDialog({super.key, required this.sponsers});

  @override
  State<SponserSearchDialog> createState() => _SponserSearchDialogState();
}

class _SponserSearchDialogState extends State<SponserSearchDialog> {
  final _controller = TextEditingController();
  late List<SponserModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.sponsers;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.sponsers.where((s) {
        return q.isEmpty ||
            s.id.toString().contains(q) ||
            s.name.toLowerCase().contains(q);
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
                  hintText: 'Search by ID or sponsor name',
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
                        'No sponsors found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final s = _filtered[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: s.logoPath.isEmpty
                                  ? Container(
                                      color: const Color(0xFF2A2A2A),
                                      child: const Icon(
                                        Icons.handshake_outlined,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                    )
                                  : Image.network(
                                      SponserApiService.fullImageUrl(
                                        s.logoPath,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          Container(
                                        color: const Color(0xFF2A2A2A),
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white38,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${s.id}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => Navigator.pop(context, s),
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