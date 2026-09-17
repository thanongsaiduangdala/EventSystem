import 'package:flutter/material.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_image_api_service.dart';

const Color _kPurple = Color(0xFF7C4DFF);
const Color _kTextDark = Color(0xFF212121);
const Color _kTextGrey = Color(0xFF757575);

/// Wide half-image / half-details event card used by the "Near You" section.
/// Give it a fixed width from its parent (e.g. inside a horizontal ListView).
class NearbyEventCard extends StatelessWidget {
  const NearbyEventCard({
    super.key,
    required this.event,
    this.image,
    required this.attend,
    this.organizerName,
    this.onTap,
    this.saved = false,
    this.onSaveTap,
  });

  final EventModel event;
  final EventImageModel? image;
  final int attend;
  final String? organizerName;
  final VoidCallback? onTap;
  final bool saved;
  final VoidCallback? onSaveTap;

  @override
  Widget build(BuildContext context) {
    final organizer = organizerName;
    String initial = '?';
    if (organizer != null && organizer.trim().isNotEmpty) {
      initial = organizer.trim().characters.first.toUpperCase();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 158,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _eventImage(),
                  Container(color: const Color(0x66000000)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _wishButton(),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      event.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _detailRow(Icons.place_outlined, event.address),
                    const SizedBox(height: 3),
                    _detailRow(Icons.calendar_today, _formatFullDate(event.start)),
                    const SizedBox(height: 3),
                    _detailRow(
                      Icons.schedule,
                      _formatTimeRange(event.start, event.end),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (organizer != null)
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: _kPurple,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    organizer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, size: 13, color: _kPurple),
                            const SizedBox(width: 3),
                            Text(
                              attend.toString(),
                              style: const TextStyle(
                                color: _kPurple,
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

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _kTextGrey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatFullDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';

  String _formatTimeRange(DateTime start, DateTime end) =>
      '${_two(start.hour)}:${_two(start.minute)}'
      ' - ${_two(end.hour)}:${_two(end.minute)}';
}