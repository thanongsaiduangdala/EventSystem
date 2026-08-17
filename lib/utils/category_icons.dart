import 'package:flutter/material.dart';

/// One selectable icon: [key] is what gets stored in CategoryIconPath,
/// [label] is shown to the user and matched against search text.
class CategoryIconOption {
  final String key;
  final String label;
  final IconData icon;
  const CategoryIconOption(this.key, this.label, this.icon);
}

/// Add more entries here any time -- no backend change needed, the key is
/// just a string that gets stored/read from CategoryIconPath as-is.
const List<CategoryIconOption> categoryIconOptions = [
  CategoryIconOption('music', 'Music', Icons.music_note),
  CategoryIconOption('concert', 'Concert', Icons.mic),
  CategoryIconOption('piano', 'Piano', Icons.piano),
  CategoryIconOption('soccer', 'Soccer', Icons.sports_soccer),
  CategoryIconOption('basketball', 'Basketball', Icons.sports_basketball),
  CategoryIconOption('tennis', 'Tennis', Icons.sports_tennis),
  CategoryIconOption('volleyball', 'Volleyball', Icons.sports_volleyball),
  CategoryIconOption('esports', 'Esports', Icons.sports_esports),
  CategoryIconOption('fitness', 'Fitness', Icons.fitness_center),
  CategoryIconOption('yoga', 'Yoga', Icons.self_improvement),
  CategoryIconOption('art', 'Art', Icons.palette),
  CategoryIconOption('theater', 'Theater', Icons.theater_comedy),
  CategoryIconOption('movie', 'Movie', Icons.movie),
  CategoryIconOption('cinema', 'Cinema', Icons.local_movies),
  CategoryIconOption('food', 'Food', Icons.restaurant),
  CategoryIconOption('cafe', 'Cafe', Icons.local_cafe),
  CategoryIconOption('bakery', 'Bakery', Icons.cake),
  CategoryIconOption('business', 'Business', Icons.business_center),
  CategoryIconOption('networking', 'Networking', Icons.handshake),
  CategoryIconOption('community', 'Community', Icons.groups),
  CategoryIconOption('discussion', 'Discussion', Icons.forum),
  CategoryIconOption('tech', 'Tech', Icons.computer),
  CategoryIconOption('coding', 'Coding', Icons.laptop),
  CategoryIconOption('workshop', 'Workshop', Icons.build),
  CategoryIconOption('health', 'Health', Icons.health_and_safety),
  CategoryIconOption('medical', 'Medical', Icons.medical_services),
  CategoryIconOption('education', 'Education', Icons.school),
  CategoryIconOption('book', 'Book', Icons.menu_book),
  CategoryIconOption('charity', 'Charity', Icons.volunteer_activism),
  CategoryIconOption('travel', 'Travel', Icons.flight),
  CategoryIconOption('beach', 'Beach', Icons.beach_access),
  CategoryIconOption('festival', 'Festival', Icons.festival),
  CategoryIconOption('fashion', 'Fashion', Icons.checkroom),
  CategoryIconOption('gaming', 'Gaming', Icons.videogame_asset),
  CategoryIconOption('outdoor', 'Outdoor', Icons.terrain),
  CategoryIconOption('nature', 'Nature', Icons.park),
  CategoryIconOption('family', 'Family', Icons.family_restroom),
  CategoryIconOption('kids', 'Kids', Icons.child_care),
  CategoryIconOption('pets', 'Pets', Icons.pets),
  CategoryIconOption('comedy', 'Comedy', Icons.emoji_emotions),
  CategoryIconOption('photography', 'Photography', Icons.camera_alt),
  CategoryIconOption('literature', 'Literature', Icons.local_library),
  CategoryIconOption('science', 'Science', Icons.science),
  CategoryIconOption('startup', 'Startup', Icons.rocket_launch),
  CategoryIconOption('finance', 'Finance', Icons.attach_money),
  CategoryIconOption('automotive', 'Automotive', Icons.directions_car),
  CategoryIconOption('realestate', 'Real Estate', Icons.home_work),
  CategoryIconOption('celebration', 'Celebration', Icons.celebration),
  CategoryIconOption('awards', 'Awards', Icons.emoji_events),
  CategoryIconOption('nightlife', 'Nightlife', Icons.local_bar),
  CategoryIconOption('running', 'Running', Icons.directions_run),
  CategoryIconOption('sports', 'Sports', Icons.sports),
];

final Map<String, CategoryIconOption> _byKey = {
  for (final o in categoryIconOptions) o.key: o,
};

/// Looks up the icon for a stored key, falling back to a generic icon for
/// unknown/legacy values (e.g. an old URL string from before this existed).
IconData iconForKey(String key) => _byKey[key]?.icon ?? Icons.category_outlined;

/// Human-readable label for a stored key, falling back to the raw key.
String labelForKey(String key) => _byKey[key]?.label ?? key;
