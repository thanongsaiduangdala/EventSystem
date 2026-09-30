import 'package:flutter/material.dart';
import 'package:ticket_com/services/event_image_api_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';

class OrgLogo extends StatelessWidget {
  const OrgLogo({
    super.key,
    required this.path,
    this.size = 46,
    this.onDark = false,
  });

  final String? path;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: onDark
          ? Colors.white.withValues(alpha: 0.18)
          : kAccent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(
        Icons.apartment,
        color: onDark ? Colors.white : kAccent,
        size: size * 0.52,
      ),
    );
    final p = path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.27),
      child: SizedBox(
        width: size,
        height: size,
        child: (p == null || p.isEmpty)
            ? placeholder
            : Image.network(
                EventOrganizerApiService.fullImageUrl(p),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class EventThumb extends StatelessWidget {
  const EventThumb({super.key, required this.image, this.size = 64});

  final EventImageModel? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFEFEEFC),
      alignment: Alignment.center,
      child: Icon(Icons.event, color: kAccent, size: size * 0.4),
    );
    final img = image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: img == null
            ? placeholder
            : Image.network(
                EventImageApiService.thumbnailUrl(img.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

Future<Map<int, EventImageModel>> loadCoversFor(Iterable<int> eventIds) async {
  final wanted = eventIds.toSet();
  final covers = <int, EventImageModel>{};
  if (wanted.isEmpty) return covers;
  try {
    final images = await EventImageApiService.getAllEventImages();
    for (final image in images) {
      if (!wanted.contains(image.eventId)) continue;
      if (image.isThumbnail || !covers.containsKey(image.eventId)) {
        covers[image.eventId] = image;
      }
    }
  } catch (_) {}
  return covers;
}
