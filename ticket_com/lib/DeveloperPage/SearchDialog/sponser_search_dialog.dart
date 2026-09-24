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
      backgroundColor: Colors.white,
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
                style: const TextStyle(color: Color(0xFF212121)),
                decoration: InputDecoration(
                  hintText: 'Search by ID or sponsor name',
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
                        'No sponsors found',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
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
                                        color: Color(0xFF9E9E9E),
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
                                          color: Color(0xFF9E9E9E),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            s.name,
                            style: const TextStyle(color: Color(0xFF212121)),
                          ),
                          subtitle: Text(
                            'ID: ${s.id}',
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
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