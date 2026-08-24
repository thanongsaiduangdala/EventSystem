import 'package:flutter/material.dart';
import 'wishlist_info_form.dart';
import 'account_category_info_form.dart';

class WishAndCategoryControllerPage extends StatefulWidget {
  const WishAndCategoryControllerPage({super.key});

  @override
  State<WishAndCategoryControllerPage> createState() =>
      _WishAndCategoryControllerPageState();
}

class _WishAndCategoryControllerPageState
    extends State<WishAndCategoryControllerPage> {
  final GlobalKey<WishlistInfoFormState> _wishlistFormKey = GlobalKey();
  final GlobalKey<AccountCategoryInfoFormState> _categoryFormKey = GlobalKey();
  int _selectedIndexId = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _body() {
    switch (_selectedIndexId) {
      case 0:
        return WishlistInfoForm(key: _wishlistFormKey);
      case 1:
        return AccountCategoryInfoForm(key: _categoryFormKey);
      default:
        return const Center();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndexId = index;
    });
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black87,
      unselectedItemColor: Colors.grey,
      selectedItemColor: Colors.white,
      currentIndex: _selectedIndexId,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: "Wishlist",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.star),
          label: "Categories",
        ),
      ],
    );
  }
}
