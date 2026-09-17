/// Shared models for categoryinfo and eventcategoryinfo.
///
/// Both category_api_service.dart and the forms (event_category_form.dart,
/// account_category_info_form.dart) reference these types, so they live in
/// one place to avoid duplicate-class import conflicts.

class CategoryModel {
  final int id;
  final String name;
  final String? iconPath;

  CategoryModel({required this.id, required this.name, this.iconPath});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['CategoryID'] as int,
      name: json['CategoryName'] as String,
      iconPath: json['CategoryIconPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'CategoryID': id,
        'CategoryName': name,
        'CategoryIconPath': iconPath,
      };
}

class EventCategoryModel {
  final int id;
  final int eventId;
  final int categoryId;

  EventCategoryModel({
    required this.id,
    required this.eventId,
    required this.categoryId,
  });

  factory EventCategoryModel.fromJson(Map<String, dynamic> json) {
    return EventCategoryModel(
      id: json['EventCategoryID'] as int,
      eventId: json['EventID'] as int,
      categoryId: json['CategoryID'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'EventCategoryID': id,
        'EventID': eventId,
        'CategoryID': categoryId,
      };
}
