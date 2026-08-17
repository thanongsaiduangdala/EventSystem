import 'package:flutter/material.dart';
import 'package:reservation_system/DeveloperPage/Table/organizer_table_page.dart';
import 'package:reservation_system/EngLoStyle/eng_lao_style.dart';
import 'event_info_form.dart';
import 'ticket_type_form.dart';
import 'event_question_form.dart';
import 'event_image_form.dart';
import 'event_sponser_form.dart';

class EventControllerBody extends StatelessWidget {
  final int selectedNavIndex;
  final GlobalKey<EventInfoFormState>? eventFormKey;
  final GlobalKey<TicketTypeFormState>? ticketTypeFormKey;
  final GlobalKey<EventQuestionFormState>? eventQuestionFormKey;

  const EventControllerBody({
    super.key,
    this.selectedNavIndex = 0,
    this.eventFormKey,
    this.ticketTypeFormKey,
    this.eventQuestionFormKey,
  });

  @override
  Widget build(BuildContext context) {
    switch (selectedNavIndex) {
      case 0:
        return EventInfoForm(key: eventFormKey);
      case 1: // Ticket Type tab
        return TicketTypeForm(key: ticketTypeFormKey);
      case 2: // Event Question Info tab
        return EventQuestionForm(key: eventQuestionFormKey);
      case 4: // Event Image Info tab
        return const EventImageForm();
      case 5: // Event Sponsor Info tab
        return const EventSponserForm();
      case 7: // Event Organizer Info tab
        return const OrganizerTablePage();
      default:
        return const Center(
          child: Text('Coming soon', style: TextStyle(color: Colors.white)),
        );
    }
  }
}

class EventControllerNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const EventControllerNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<EventControllerNavBar> createState() => _EventControllerNavBarState();
}

class _EventControllerNavBarState extends State<EventControllerNavBar> {
  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.event_available_outlined,
        'label': l10nOf(context).eventinfo,
      },
      {'icon': Icons.book_online_outlined, 'label': l10nOf(context).tickettype},
      {
        'icon': Icons.question_mark_outlined,
        'label': l10nOf(context).eventquestioninfo,
      },
      {
        'icon': Icons.merge_type_outlined,
        'label': l10nOf(context).eventquestiontype,
      },
      {'icon': Icons.image_outlined, 'label': l10nOf(context).eventimageinfo},
      {
        'icon': Icons.handshake_outlined,
        'label': l10nOf(context).eventsponsorinfo,
      },
      {
        'icon': Icons.category_outlined,
        'label': l10nOf(context).eventcategoryinfo,
      },
      {
        'icon': Icons.business_outlined,
        'label': l10nOf(context).eventorganizerinfo,
      },
    ];

    return Container(
      color: Colors.black87,
      height: 72,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = widget.selectedIndex == index;
            return InkWell(
              onTap: () => widget.onItemSelected(index),
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      color: isSelected ? Colors.white : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[index]['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
