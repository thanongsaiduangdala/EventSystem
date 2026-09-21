import 'package:flutter/material.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';

/// Compact event card used in the horizontal home-page rows and the
/// "See all" list page. Requires a fixed width from its parent (e.g. wrapped
/// in a SizedBoox inside a horizontal ListView).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.image,
    required this.attend,
    this.onTap,
    this.saved = false,
    this.onSaveTap,
    this.bought = false,
  });

  final EventModel event;
  final EventImageModel? image;
  final int attend;
  final VoidCallback? onTap;
  final bool saved;
  final VoidCallback? onSaveTap;
  final bool bought;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: _eventImage(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _pinkBadge(_formatDayMonth(event.start)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _wishButton(),
                ),
                if (bought)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _boughtBadge(),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF212121),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 13,
                              color: Color(0xFF9E9E9E),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF757575),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people,
                            size: 13,
                            color: Color(0xFF7C4DFF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attend.toString(),
                            style: const TextStyle(
                              color: Color(0xFF7C4DFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventImage() {
    if (image == null) return _placeholderImage();
    final url = EventImageApiService.thumbnailUrl(image!.imagePath);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholderImage(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholderImage();
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: const Icon(
        Icons.event,
        color: Color(0xFFBDBDBD),
        size: 36,
      ),
    );
  }

  Widget _pinkBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.pinkAccent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _wishButton() {
    return GestureDetector(
      onTap: onSaveTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          size: 15,
          color: saved ? const Color(0xFFEC407A) : Colors.black87,
        ),
      ),
    );
  }

  Widget _boughtBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2E9E5B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 11),
          SizedBox(width: 3),
          Text(
            'Bought',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDayMonth(DateTime d) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}