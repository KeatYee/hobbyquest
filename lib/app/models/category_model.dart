class CategoryModel {
  final String id;           // Unique identifier
  final String name;         // e.g., "Music", "Art", "Sports"
  final String description;  // e.g., "Learn an instrument"
  final String icon;         // Icon name or emoji
  final List<String> hobbies; // List of hobbies under this category

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.hobbies,
  });

  // Factory to create from Firestore JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      hobbies: List<String>.from(json['hobbies'] ?? []),
    );
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'hobbies': hobbies,
    };
  }
}
