class CategoryModel {
  final int id;
  final String name;
  final String iconPath;

  CategoryModel({required this.id, required this.name, required this.iconPath});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['CategoryID'] as int,
      name: json['CategoryName']?.toString() ?? '',
      iconPath: json['CategoryIconPath']?.toString() ?? '',
    );
  }
}

/// A link between an Event and a Category (the `eventcategoryinfo` join table).
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
}
