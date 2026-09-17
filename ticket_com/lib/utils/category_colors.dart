import 'package:flutter/material.dart';

/// Category accent colors matching the reference map pins: Sports red,
/// Music purple, Food green, plus a gentle fallback palette.
const Color kCatSports = Color(0xFFE53935);
const Color kCatMusic = Color(0xFF8E2DE2);
const Color kCatFood = Color(0xFF43A047);
const Color kCatTeam = Color(0xFF00ACC1);
const Color kAccent = Color(0xFF5B4DFF);
const Color kPink = Color(0xFFEC407A);

/// Same named-category color scheme as the Home page's pill colors.
Color categoryColorFor(String name) {
  final k = name.toLowerCase().trim();
  const colors = <String, Color>{
    'food': Color(0xFF4FC3F7),
    'sports+': Color(0xFFD81B60),
    'sports': Color(0xFFEC407A),
    'pilot': Color(0xFF5C6BC0),
    'running': Color(0xFF1E88E5),
    'fitness': Color(0xFF26A69A),
    'culture': Color(0xFF8E44AD),
    'music': Color(0xFFFF7043),
    'festival': Color(0xFFFB8C00),
    'art': Color(0xFFAB47BC),
    'nature': Color(0xFF43A047),
    'adventure': Color(0xFF795548),
    'community': Color(0xFF00ACC1),
  };
  final known = colors[k];
  if (known != null) return known;
  const palette = [
    Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFFEC407A),
    Color(0xFFFF7043), Color(0xFF26C6DA),
  ];
  return palette[k.hashCode.abs() % palette.length];
}