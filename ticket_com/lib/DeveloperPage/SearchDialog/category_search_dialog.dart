import 'package:flutter/material.dart';
import '../../models/category_models.dart';
import '../../utils/category_icons.dart';

class CategorySearchDialog extends StatefulWidget {
  final List<CategoryModel> categories;
  const CategorySearchDialog({super.key, required this.categories});

  @override
  State<CategorySearchDialog> createState() => _CategorySearchDialogState();
}

class _CategorySearchDialogState extends State<CategorySearchDialog> {
  final _controller = TextEditingController();
  late List<CategoryModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.categories;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.categories.where((c) {
        return q.isEmpty ||
            c.id.toString().contains(q) ||
            c.name.toLowerCase().contains(q);
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
                  hintText: 'Search by ID or category name',
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
                        'No categories found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final c = _filtered[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 36,
                              height: 36,
                              color: const Color(0xFF2A2A2A),
                              child: Icon(
                                c.iconPath == null
                                    ? Icons.category_outlined
                                    : iconForKey(c.iconPath!),
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID: ${c.id}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => Navigator.pop(context, c),
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
