import 'package:flutter/material.dart';
import 'package:ticket_com/DeveloperPage/account_controller_page.dart';
import 'package:ticket_com/DeveloperPage/attendee_controller_page.dart';
import 'package:ticket_com/DeveloperPage/organizer_controller_page.dart';
import './EventController_Page.dart';
import './event_info_form.dart';
import './ticket_type_form.dart';
import './sponsor_controller_page.dart';
import './wish_and_category_controller_page.dart';

class MainPageDashboard extends StatefulWidget {
  const MainPageDashboard({super.key});

  @override
  State<MainPageDashboard> createState() => _MainPageDashboardState();
}

class _MainPageDashboardState extends State<MainPageDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<EventInfoFormState> _eventFormKey = GlobalKey();
  final GlobalKey<TicketTypeFormState> _ticketTypeFormKey = GlobalKey();

  int _selectedIndex = 0;
  int _eventNavIndex = 0;

  final List<String> _titles = const [
    'Event',
    'Account',
    'Organization',
    'Attendee',
    'Sponsor',
    'Wishlist & Categories',
  ];

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  /// Closes the drawer, then leaves the dashboard, returning to whatever
  /// page pushed MainPageDashboard onto the navigator stack (e.g. your
  /// mainpage.dart). If MainPageDashboard is the current root route (nothing
  /// to pop back to), this just closes the drawer.
  void _exitDashboard() {
    Navigator.pop(context); // close the drawer
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // leave the dashboard
    }
  }

  Widget _currentBody() {
    switch (_selectedIndex) {
      case 0:
        return EventControllerBody(
          selectedNavIndex: _eventNavIndex,
          eventFormKey: _eventFormKey,
          ticketTypeFormKey: _ticketTypeFormKey,
        );
      case 1:
        return AccountControllerPage();
      case 2:
        return OrganizerControllerPage();
      case 3:
        return AttendeeControllerPage();
      case 4:
        return SponsorControllerPage();
      case 5:
        return const WishAndCategoryControllerPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _currentNavBar() {
    switch (_selectedIndex) {
      case 0:
        return EventControllerNavBar(
          selectedIndex: _eventNavIndex,
          onItemSelected: (index) {
            setState(() {
              _eventNavIndex = index;
            });
          },
        );
      case 1:
        return null;
      case 2:
        return null;
      case 3:
        return null;
      case 4:
        return null;
      case 5:
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      key: _scaffoldKey,
      appBar: _appbar(),
      body: _currentBody(),
      bottomNavigationBar: _currentNavBar(),
      drawer: _drawer(),
    );
  }

  PreferredSizeWidget _appbar() {
    return AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        _titles[_selectedIndex],
        style: const TextStyle(color: Colors.white),
      ),
      actions: _selectedIndex == 0
          ? [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  if (_eventNavIndex == 1) {
                    _ticketTypeFormKey.currentState?.reloadEvents();
                  } else {
                    _eventFormKey.currentState?.reloadOrganizers();
                  }
                },
              ),
            ]
          : null,
    );
  }

  Widget _drawer() {
    return Drawer(
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1E1E1E)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF424242),
                  child: Icon(Icons.person, color: Colors.white70, size: 32),
                ),
                SizedBox(width: 12),
                Text(
                  'Setting option',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Colors.white70),
            title: const Text('Event', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 0,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(0),
          ),
          ListTile(
            leading: const Icon(
              Icons.account_box_outlined,
              color: Colors.white70,
            ),
            title: const Text('Account', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 1,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(1),
          ),
          ListTile(
            leading: const Icon(Icons.business, color: Colors.white70),
            title: const Text(
              'Organization',
              style: TextStyle(color: Colors.white),
            ),
            selected: _selectedIndex == 2,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(2),
          ),
          ListTile(
            leading: const Icon(Icons.groups_3_outlined, color: Colors.white70),
            title: const Text(
              'Attendee',
              style: TextStyle(color: Colors.white),
            ),
            selected: _selectedIndex == 3,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(3),
          ),
          ListTile(
            leading: const Icon(
              Icons.handshake_outlined,
              color: Colors.white70,
            ),
            title: const Text('Sponsor', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 4,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(4),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline, color: Colors.white70),
            title: const Text(
              'Wishlist & Categories',
              style: TextStyle(color: Colors.white),
            ),
            selected: _selectedIndex == 5,
            selectedTileColor: Colors.white10,
            onTap: () => _selectPage(5),
          ),
          const Divider(color: Colors.white24, height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Exit', style: TextStyle(color: Colors.white)),
            onTap: _exitDashboard,
          ),
        ],
      ),
    );
  }
}

class AccountBody extends StatelessWidget {
  const AccountBody({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Account content', style: TextStyle(color: Colors.white)),
    );
  }
}

class OrganizationBody extends StatelessWidget {
  const OrganizationBody({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Organization content',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

class AttendeeBody extends StatelessWidget {
  const AttendeeBody({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Attendee content', style: TextStyle(color: Colors.white)),
    );
  }
}

class AttendeeNavBar extends StatelessWidget {
  const AttendeeNavBar({super.key});
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.black87,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'List'),
        BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Scan'),
      ],
    );
  }
}


class SponsorNavBar extends StatelessWidget {
  const SponsorNavBar({super.key});
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.black87,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'List'),
        BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Info'),
      ],
    );
  }
}