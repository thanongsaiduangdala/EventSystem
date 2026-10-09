import 'package:flutter/material.dart';
import '../services/account_api_service.dart';

/// What the admin picked in the "linked records" pop-up.
class AccountDeleteChoice {
  /// 'selective' | 'cascade' | 'force'
  final String mode;

  /// "table.column" keys, only used for 'selective'.
  final List<String> targets;

  const AccountDeleteChoice(this.mode, [this.targets = const []]);
}

/// Shows everything that is linked to an account and lets the admin choose how
/// to continue. Returns null when the admin cancels.
Future<AccountDeleteChoice?> showAccountDependenciesDialog(
  BuildContext context,
  AccountDependencies deps,
) {
  return showDialog<AccountDeleteChoice>(
    context: context,
    builder: (_) => _AccountDependenciesDialog(deps: deps),
  );
}

class _AccountDependenciesDialog extends StatefulWidget {
  final AccountDependencies deps;
  const _AccountDependenciesDialog({required this.deps});

  @override
  State<_AccountDependenciesDialog> createState() =>
      _AccountDependenciesDialogState();
}

class _AccountDependenciesDialogState
    extends State<_AccountDependenciesDialog> {
  static const _dark = Color(0xFF212121);
  static const _grey = Color(0xFF757575);

  /// "table.column" keys of the top-level links the admin ticked.
  final Set<String> _selected = {};

  List<AccountDependencyNode> get _blocking =>
      widget.deps.nodes.where((n) => n.blocking).toList();

  List<AccountDependencyNode> get _automatic =>
      widget.deps.nodes.where((n) => !n.blocking).toList();

  Future<bool> _confirm(String title, String message, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: _dark)),
        content: Text(message, style: const TextStyle(color: _grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _onDeleteEverything() async {
    final ok = await _confirm(
      'Delete everything connected?',
      'This permanently deletes "${widget.deps.accountName}" and every record '
          'listed above that depends on it. This cannot be undone.',
      'Delete everything',
    );
    if (ok && mounted) {
      Navigator.pop(context, const AccountDeleteChoice('cascade'));
    }
  }

  Future<void> _onDeleteAccountOnly() async {
    final ok = await _confirm(
      'Delete the account only?',
      'The account will be deleted and the database checks are skipped. The '
          'linked records stay in the database but will point at an account '
          'that no longer exists (orphaned data). This cannot be undone.',
      'Delete account only',
    );
    if (ok && mounted) {
      Navigator.pop(context, const AccountDeleteChoice('force'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(deps),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  if (_blocking.isNotEmpty) ...[
                    _sectionTitle(
                      'Blocking the delete',
                      'Tick the ones you want to delete.',
                    ),
                    for (final n in _blocking)
                      _nodeTile(n, 0, selectable: true),
                  ],
                  if (_automatic.isNotEmpty) ...[
                    _sectionTitle(
                      'Removed automatically with the account',
                      'The database deletes these itself.',
                    ),
                    for (final n in _automatic) _nodeTile(n, 0),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AccountDependencies deps) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.link, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This account is linked to other records',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${deps.accountName}${deps.email.isEmpty ? '' : '  •  ${deps.email}'}',
                  style: const TextStyle(color: _grey),
                ),
                const SizedBox(height: 6),
                const Text(
                  'It cannot be deleted normally. Choose what should happen '
                  'to the records below.',
                  style: TextStyle(color: _grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _dark,
              fontSize: 14,
            ),
          ),
          Text(hint, style: const TextStyle(color: _grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _nodeTile(
    AccountDependencyNode node,
    int depth, {
    bool selectable = false,
  }) {
    final actionText = node.isUnlinkOnly
        ? 'kept, link cleared'
        : (depth == 0 ? 'will be deleted' : 'deleted with it');

    final tile = Container(
      margin: const EdgeInsets.only(top: 6),
      padding: EdgeInsets.fromLTRB(selectable ? 0 : 10, 8, 10, 8),
      decoration: BoxDecoration(
        color: depth == 0 ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          if (selectable)
            Checkbox(
              value: _selected.contains(node.key),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(node.key);
                } else {
                  _selected.remove(node.key);
                }
              }),
            )
          else if (depth > 0)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: _grey,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.label,
                  style: const TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${node.table}.${node.column}  •  $actionText',
                  style: const TextStyle(color: _grey, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: node.blocking ? Colors.red.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${node.count}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: node.blocking ? Colors.red.shade700 : _dark,
              ),
            ),
          ),
        ],
      ),
    );

    if (node.children.isEmpty) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in node.children) _nodeTile(c, depth + 1)],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only the ticked links (+ whatever hangs off them). The account goes
          // too once nothing blocks it any more.
          OutlinedButton(
            onPressed: count == 0
                ? null
                : () => Navigator.pop(
                    context,
                    AccountDeleteChoice('selective', _selected.toList()),
                  ),
            child: Text(
              count == 0
                  ? 'Delete ticked records (tick some above)'
                  : 'Delete $count ticked ${count == 1 ? 'group' : 'groups'}'
                        ' (+ account if nothing else blocks it)',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // The account and every record listed above.
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _onDeleteEverything,
            child: const Text('Delete account + everything connected'),
          ),
          const SizedBox(height: 8),
          // Only the account row; foreign-key checks are skipped.
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: _onDeleteAccountOnly,
            child: const Text('Delete account only (ignore links)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
