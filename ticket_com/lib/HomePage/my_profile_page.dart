import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ticket_com/EngLoStyle/eng_lao_style.dart';
import 'package:ticket_com/LogSignPage/MainLoginSignUp.dart';
import 'package:ticket_com/services/account_api_service.dart';
import 'package:ticket_com/services/account_category_api_service.dart';
import 'package:ticket_com/services/auth_service.dart';
import 'package:ticket_com/services/category_api_service.dart';
import 'package:ticket_com/services/event_api_service.dart';
import 'package:ticket_com/services/event_organizer_api_service.dart'
    show EventOrganizerApiService;
import 'package:ticket_com/services/follow_api_service.dart';
import 'package:ticket_com/utils/category_colors.dart';
import 'package:ticket_com/utils/category_icons.dart';

const Color _kAccent = Color(0xFF5B4FE9);
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextGrey = Color(0xFF6B6B6B);
const Color _kLavender = Color(0xFFE8E6FA);

/// Full-screen "My Profile" page opened from the Home drawer. Shows the
/// signed-in account's avatar, name, an "About Me" blurb and their favorite
/// categories (interests), and lets the user edit name/phone + interests.
class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  Map<int, AccountCategoryModel> _myCategories = {};
  List<CategoryModel> _allCategories = [];
  bool _categoriesLoading = false;
  bool _categoriesError = false;
  bool _savingCategories = false;
  bool _uploadingPicture = false;
  List<EventOrganizer> _followedOrganizers = [];
  bool _followingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFollowedOrganizers();
  }

  UserSession? get _session => AuthService.currentSession;

  Future<void> _loadCategories() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _categoriesLoading = true;
      _categoriesError = false;
    });
    try {
      final all = await AccountCategoryApiService.getAllAccountCategories();
      final cats = await CategoryApiService.getAllCategories();
      if (!mounted) return;
      setState(() {
        _myCategories = {
          for (final c in all)
            if (c.accountId == session.accountId) c.categoryId: c,
        };
        _allCategories = cats;
        _categoriesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoriesLoading = false;
        _categoriesError = true;
      });
    }
  }

  CategoryModel? _categoryById(int id) {
    for (final c in _allCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _loadFollowedOrganizers() async {
    final session = _session;
    if (session == null) return;
    if (_followingLoading) return;
    setState(() => _followingLoading = true);
    try {
      final results = await Future.wait<Object>([
        FollowApiService.getFollowsByAccount(session.accountId),
        EventApiService.getAllOrganizers(),
      ]);
      final follows = results[0] as List<FollowModel>;
      final organizers = results[1] as List<EventOrganizer>;
      final byId = {for (final o in organizers) o.id: o};
      final followed = <EventOrganizer>[];
      for (final f in follows) {
        final organizer = byId[f.organizerId];
        if (organizer != null) followed.add(organizer);
      }
      if (!mounted) return;
      setState(() {
        _followedOrganizers = followed;
        _followingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _followingLoading = false);
    }
  }

  Future<void> _openFollowedOrganizers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _FollowedOrganizersPage(organizers: _followedOrganizers),
      ),
    );
    if (!mounted) return;
    _loadFollowedOrganizers();
  }

  Future<void> _editCategories() async {
    final session = _session;
    if (session == null) return;
    final l10n = l10nOf(context);

    final result = await showModalBottomSheet<_CategorySelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPickerSheet(
        allCategories: _allCategories,
        initialSelected: _myCategories.keys.toSet(),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _savingCategories = true);
    try {
      final current = Map<int, AccountCategoryModel>.of(_myCategories);
      for (final entry in current.entries) {
        if (!result.selectedIds.contains(entry.key)) {
          await AccountCategoryApiService.deleteAccountCategory(entry.value.id);
        }
      }
      for (final id in result.selectedIds) {
        if (!current.containsKey(id)) {
          await AccountCategoryApiService.addAccountCategory(
            accountId: session.accountId,
            categoryId: id,
          );
        }
      }
      await _loadCategories();
      if (!mounted) return;
      setState(() => _savingCategories = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.categoriesUpdated)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingCategories = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrongPleaseTryAgain)),
      );
    }
  }

  Future<void> _editProfile() async {
    final session = _session;
    if (session == null) return;
    final l10n = l10nOf(context);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(
        session: session,
        onSave: (first, last, phone) async {
          await AccountApiService.updateAccount(
            accountId: session.accountId,
            firstName: first,
            lastName: last,
            phoneNum: phone,
            email: session.email,
            statusId: session.statusId,
          );
          await AuthService.updateProfile(
            firstname: first,
            lastname: last,
            phoneNum: phone,
            email: session.email,
          );
        },
      ),
    );

    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
    }
  }

  Future<void> _changeProfilePicture() async {
    final session = _session;
    if (session == null) return;
    final l10n = l10nOf(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PictureSourceSheet(
        uploading: _uploadingPicture,
      ),
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
    } catch (_) {
      picked = null;
    }
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _uploadingPicture = true);
    try {
      await AuthService.updateProfilePicture(
        bytes: bytes,
        filename: picked.name.trim().isNotEmpty
            ? picked.name
            : 'profile_picture.jpg',
      );
      if (!mounted) return;
      setState(() => _uploadingPicture = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profilePictureUpdated)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingPicture = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrongPleaseTryAgain)),
      );
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Mainloginsignup()),
      (route) => false,
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _kTextDark,
      elevation: 0,
      title: Text(
        l10nOf(context).myProfile,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(context),
        body: session == null
            ? _guestView(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                children: [
                  _profileHeader(session),
                  const SizedBox(height: 18),
                  _editProfilePill(context),
                  const SizedBox(height: 30),
                  _personalInfoSection(context, session),
                  const SizedBox(height: 30),
                  _interestSection(context),
                  const SizedBox(height: 30),
                  _followedOrganizersSection(context),
                ],
              ),
      ),
    );
  }

  Widget _guestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined,
                color: _kTextGrey, size: 56),
            const SizedBox(height: 14),
            const Text(
              'Please log in to view your profile',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextGrey, fontSize: 14),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _goToLogin,
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text(
                'Sign In',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(UserSession session) {
    final initials = _initials(session);
    final name = '${session.firstname} ${session.lastname}'.trim();
    final picUrl = session.profileImageUrl;
    return Column(
      children: [
        GestureDetector(
          onTap: _uploadingPicture ? null : _changeProfilePicture,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 140,
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kAccent, Color(0xFF8E2DE2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: picUrl.isEmpty
                    ? (initials.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 52)
                        : Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ))
                    : Image.network(
                        picUrl,
                        fit: BoxFit.cover,
                        width: 140,
                        height: 140,
                        errorBuilder: (context, error, stack) => Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _uploadingPicture
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// One- or two-letter initials derived from the account name.
  String _initials(UserSession session) {
    final first = session.firstname.trim();
    final last = session.lastname.trim();
    if (first.isEmpty && last.isEmpty) return '';
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    return (f + l).toUpperCase();
  }

  Widget _personalInfoSection(BuildContext context, UserSession session) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.personalInfo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        _infoItem(l10n.firstName, session.firstname),
        const SizedBox(height: 14),
        _infoItem(l10n.lastName, session.lastname),
        const SizedBox(height: 14),
        _infoItem(l10n.phoneNumber, session.phoneNum),
        const SizedBox(height: 14),
        _infoItem(l10n.email, session.email),
        const SizedBox(height: 14),
        _infoItem(l10n.account, 'ID ${session.accountId}'),
      ],
    );
  }

  Widget _infoItem(String label, String value) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextGrey,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          display,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _interestSection(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.interest,
                style: const TextStyle(
                  color: _kTextDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              _interestChangeButton(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_categoriesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: _kAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_categoriesError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                const Text(
                  'Could not load categories',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _kTextGrey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadCategories,
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_myCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.noCategoriesSelected,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextGrey, fontSize: 13.5),
            ),
          )
        else
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _myCategories.entries)
                  _categoryChip(_categoryById(entry.key), entry.value),
              ],
            ),
          ),
      ],
    );
  }

  Widget _followedOrganizersSection(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.followedOrganizers,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kTextDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        if (_followingLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: _kAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_followedOrganizers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'You\'re not following any organizers yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextGrey, fontSize: 13.5),
            ),
          )
        else ...[
          for (final organizer in _followedOrganizers.take(3))
            _organizerTile(organizer),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _openFollowedOrganizers,
            icon: const Icon(Icons.grid_view_outlined, size: 18),
            label: Text('${l10n.seeAll} (${_followedOrganizers.length})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAccent,
              side: const BorderSide(color: _kAccent, width: 1.4),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _organizerTile(EventOrganizer organizer) {
    final name = organizer.name.trim();
    final summary = organizer.description?.trim().isNotEmpty == true
        ? organizer.description!.trim()
        : null;
    final initial =
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        children: [
          _organizerAvatar(organizer, initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kTextGrey,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.black26, size: 22),
        ],
      ),
    );
  }

  Widget _organizerAvatar(EventOrganizer organizer, String initial) {
    final logo = organizer.logoPath;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          EventOrganizerApiService.fullImageUrl(logo),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _organizerInitial(initial),
        ),
      );
    }
    return _organizerInitial(initial);
  }

  Widget _organizerInitial(String initial) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: _kAccent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _interestChangeButton() {
    return InkWell(
      onTap: _savingCategories ? null : _editCategories,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _kLavender,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _savingCategories
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kAccent,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: _kAccent, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'CHANGE',
                    style: TextStyle(
                      color: _kAccent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _categoryChip(CategoryModel? category, AccountCategoryModel favorite) {
    final name = category?.name ?? favorite.categoryName;
    final color = categoryColorFor(name);
    final icon = iconForKey(category?.iconPath ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editProfilePill(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: _editProfile,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(l10nOf(context).editProfile),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: const BorderSide(color: _kAccent, width: 1.6),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 13),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet form that edits the account's first name, last name and phone
/// number. Pops with `true` when the save succeeds.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.session, required this.onSave});

  final UserSession session;
  final Future<void> Function(String first, String last, String phone) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first = TextEditingController(
    text: widget.session.firstname,
  );
  late final TextEditingController _last = TextEditingController(
    text: widget.session.lastname,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.session.phoneNum,
  );
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = l10nOf(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _first.text.trim(),
        _last.text.trim(),
        _phone.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrongPleaseTryAgain)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.editProfile,
                  style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.firstName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.dontLeaveFirstNameEmpty
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.lastName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.dontLeaveLastNameEmpty
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumber,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return l10n.dontLeavePhoneEmpty;
                    if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                      return l10n.phoneMustBeNumbers;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextGrey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.cancel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                l10n.save,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySelection {
  const _CategorySelection(this.selectedIds);
  final Set<int> selectedIds;
}

/// Bottom sheet that lets the user pick the categories they're interested in.
/// Pops with a [_CategorySelection] when "Done" is tapped.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.allCategories,
    required this.initialSelected,
  });

  final List<CategoryModel> allCategories;
  final Set<int> initialSelected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Set<int> _selected = Set<int>.of(widget.initialSelected);

  void _toggle(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.editCategories,
                    style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _CategorySelection(_selected),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _kAccent,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: Text(l10n.done),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.selectCategoriesHint,
              style: const TextStyle(color: _kTextGrey, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0x14000000)),
          Expanded(
            child: widget.allCategories.isEmpty
                ? const Center(
                    child: Text(
                      'No categories available',
                      style: TextStyle(color: _kTextGrey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.allCategories.length,
                    itemBuilder: (context, index) {
                      final category = widget.allCategories[index];
                      final selected = _selected.contains(category.id);
                      final color = categoryColorFor(category.name);
                      return ListTile(
                        onTap: () => _toggle(category.id),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconForKey(category.iconPath ?? ''),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: const TextStyle(
                            color: _kTextDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected ? _kAccent : Colors.grey,
                          size: 22,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that asks where to take the profile picture from. Pops with
/// an [ImageSource] (camera or gallery) when one is chosen.
class _PictureSourceSheet extends StatelessWidget {
  const _PictureSourceSheet({this.uploading = false});

  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.changeProfilePicture,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _sourceOption(
              context,
              icon: Icons.photo_camera_outlined,
              label: l10n.takePhoto,
              source: ImageSource.camera,
            ),
            const SizedBox(height: 8),
            _sourceOption(
              context,
              icon: Icons.photo_library_outlined,
              label: l10n.chooseFromGallery,
              source: ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: uploading ? null : () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _kAccent, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: _kTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen list of every organizer the user follows, opened from the
/// "See All" button in the profile's followed-organizers section. Lets the
/// user unfollow organizers directly from the list.
class _FollowedOrganizersPage extends StatefulWidget {
  const _FollowedOrganizersPage({required this.organizers});

  final List<EventOrganizer> organizers;

  @override
  State<_FollowedOrganizersPage> createState() => _FollowedOrganizersPageState();
}

class _FollowedOrganizersPageState extends State<_FollowedOrganizersPage> {
  late final List<EventOrganizer> _organizers = List.of(widget.organizers);
  final Set<int> _unfollowing = {};

  UserSession? get _session => AuthService.currentSession;

  Future<void> _unfollow(EventOrganizer organizer) async {
    final session = _session;
    final l10n = l10nOf(context);
    if (session == null || _unfollowing.contains(organizer.id)) return;
    setState(() => _unfollowing.add(organizer.id));
    try {
      await FollowApiService.deleteFollow(
        accountId: session.accountId,
        organizerId: organizer.id,
      );
      if (!mounted) return;
      setState(() {
        _unfollowing.remove(organizer.id);
        _organizers.removeWhere((o) => o.id == organizer.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unfollowedOrganizer)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _unfollowing.remove(organizer.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrongPleaseTryAgain)),
      );
    }
  }

  Widget _avatar(EventOrganizer organizer, String initial) {
    final logo = organizer.logoPath;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          EventOrganizerApiService.fullImageUrl(logo),
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initial(initial),
        ),
      );
    }
    return _initial(initial);
  }

  Widget _initial(String initial) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: _kAccent,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kTextDark,
        elevation: 0,
        title: Text(
          l10n.followedOrganizers,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _organizers.isEmpty
          ? const Center(
              child: Text(
                'You\'re not following any organizers yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextGrey, fontSize: 14),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _organizers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final organizer = _organizers[index];
                final name = organizer.name.trim();
                final summary =
                    organizer.description?.trim().isNotEmpty == true
                        ? organizer.description!.trim()
                        : null;
                final initial =
                    name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Row(
                    children: [
                      _avatar(organizer, initial),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kTextDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (summary != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _kTextGrey,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _unfollowing.contains(organizer.id)
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kAccent,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _unfollow(organizer),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _kLavender,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check,
                                      color: _kAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.following,
                                      style: const TextStyle(
                                        color: _kAccent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}