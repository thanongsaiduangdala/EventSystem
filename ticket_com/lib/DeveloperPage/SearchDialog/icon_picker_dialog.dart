import 'package:flutter/material.dart';
import '../../utils/category_icons.dart';

class IconPickerDialog extends StatefulWidget {
  const IconPickerDialog({super.key});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  final _controller = TextEditingController();
  late List<CategoryIconOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = categoryIconOptions;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = categoryIconOptions.where((o) {
        return q.isEmpty ||
            o.label.toLowerCase().contains(q) ||
            o.key.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search icons',
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
                        'No icons found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final option = _filtered[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.pop(context, option),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(option.icon, color: Colors.white, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
