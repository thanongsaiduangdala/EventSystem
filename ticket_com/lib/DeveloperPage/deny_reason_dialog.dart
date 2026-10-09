import 'package:flutter/material.dart';

const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);
const Color _kRed = Color(0xFFE53935);

/// Asks the reviewer WHY they are denying something. Returns the trimmed
/// comment, or null if they cancelled. The Deny button stays disabled until a
/// real comment is typed, because the organizer needs it to fix the problem.
Future<String?> showDenyReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DenyReasonDialog(title: title, message: message),
  );
}

class _DenyReasonDialog extends StatefulWidget {
  const _DenyReasonDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_DenyReasonDialog> createState() => _DenyReasonDialogState();
}

class _DenyReasonDialogState extends State<_DenyReasonDialog> {
  static const int _minLength = 3;
  static const int _maxLength = 500;

  final _controller = TextEditingController();

  bool get _valid => _controller.text.trim().length >= _minLength;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(widget.title, style: const TextStyle(color: _kTextDark)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: const TextStyle(color: _kTextGrey)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Why is it denied? (required)',
                hintText: 'e.g. The logo is blurry, please upload a clearer one.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              _valid ? () => Navigator.pop(context, _controller.text.trim()) : null,
          child: Text(
            'Deny',
            style: TextStyle(
              color: _valid ? _kRed : Colors.black26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
