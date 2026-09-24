import 'package:flutter/material.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/services/notification_service.dart';

const Color _kAccent = Color(0xFF7C4DFF);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

const Map<String, IconData> _typeIcons = {
  'order': Icons.confirmation_number_outlined,
  'event': Icons.calendar_today_outlined,
  'wish': Icons.favorite_outline,
  'promo': Icons.local_offer_outlined,
  'system': Icons.info_outline,
};

const Map<String, Color> _typeColors = {
  'order': Color(0xFF7C4DFF),
  'event': Color(0xFF1E88E5),
  'wish': Color(0xFFEC407A),
  'promo': Color(0xFFFF7043),
  'system': Color(0xFF26A69A),
};

/// Full-screen notification list. Shows every notification newest first, with
/// unread ones highlighted by an accent dot and a bold title. Tapping a
/// notification marks it as read; the app-bar action marks everything read.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    NotificationService.instance.refresh(force: true);
  }

  AppBar _appBar(BuildContext context) {
    final l10n = l10nOf(context);
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _kTextDark,
      elevation: 0,
      title: Text(
        l10n.notification,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        ListenableBuilder(
          listenable: NotificationService.instance,
          builder: (context, _) {
            final unread = NotificationService.instance.unreadCount;
            return TextButton(
              onPressed: unread == 0
                  ? null
                  : NotificationService.instance.markAllRead,
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: _kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _appBar(context),
      body: ListenableBuilder(
        listenable: NotificationService.instance,
        builder: (context, _) {
          final items = NotificationService.instance.itemsNewestFirst;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: _kTextGrey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationTile(
                notification: items[index],
                onOpenDetail: (n) => _showNotificationDetail(context, n),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Floating rectangle card in the middle of the screen showing the full
  /// content of one notification.
  void _showNotificationDetail(
    BuildContext context,
    AppNotification notification,
  ) {
    final icon = _typeIcons[notification.type] ?? Icons.notifications_none;
    final color = _typeColors[notification.type] ?? _kAccent;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(
                              color: _kTextDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _typeChip(notification.type, color),
                              Text(
                                relativeTime(notification.time),
                                style: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => Navigator.pop(dialogContext),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          color: Color(0xFF9E9E9E),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0x14000000)),
                const SizedBox(height: 16),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _formatFullTime(notification.time),
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _typeChip(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'order':
        return 'TICKET';
      case 'event':
        return 'EVENT';
      case 'wish':
        return 'WISH LIST';
      case 'promo':
        return 'PROMO';
      default:
        return 'GAEA';
    }
  }
}

String _formatFullTime(DateTime time) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${months[time.month - 1]} ${time.year}, $hh:$mm';
}

/// The small rectangle shown below the home-page bell icon. Lists the newest
/// few notifications and a "See all" action that opens [NotificationPage].
class NotificationDropdown extends StatelessWidget {
  const NotificationDropdown({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final width = MediaQuery.sizeOf(context).width - 32;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width.clamp(240, 380),
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              spreadRadius: 2,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: NotificationService.instance,
          builder: (context, _) {
            final all = NotificationService.instance.itemsNewestFirst;
            final shown = all.take(4).toList();
            final unread = NotificationService.instance.unreadCount;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        l10n.notification,
                        style: const TextStyle(
                          color: _kTextDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7043),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (unread > 0)
                        TextButton(
                          onPressed: NotificationService.instance.markAllRead,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Mark all read',
                            style: TextStyle(
                              color: _kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No notifications yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kTextGrey, fontSize: 13),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: shown.length,
                      itemBuilder: (context, index) =>
                          _NotificationTile(notification: shown[index]),
                    ),
                  ),
                const Divider(height: 1, color: Color(0x14000000)),
                InkWell(
                  onTap: onSeeAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.seeAll,
                          style: const TextStyle(
                            color: _kAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: _kAccent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onOpenDetail});

  final AppNotification notification;
  final ValueChanged<AppNotification>? onOpenDetail;

  void _handleTap(BuildContext context) {
    if (!notification.read) {
      NotificationService.instance.markRead(notification.id);
    }
    onOpenDetail?.call(notification);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[notification.type] ?? Icons.notifications_none;
    final color = _typeColors[notification.type] ?? _kAccent;

    return Material(
      color: notification.read ? Colors.white : const Color(0xFFF3EFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: _kTextDark,
                              fontSize: 14,
                              fontWeight: notification.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.read) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C4DFF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextGrey,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      relativeTime(notification.time),
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact relative time, e.g. "Just now", "12m ago", "3h ago", "2d ago".
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}