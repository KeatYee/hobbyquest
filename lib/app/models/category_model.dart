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
  // `docId` is optional and, when provided, will be used as the canonical
  // identifier for the category (Firestore document id). This keeps the
  // source-of-truth in Firestore rather than relying on an `id` field inside
  // the document data.
  factory CategoryModel.fromJson(Map<String, dynamic> json, String docId) {
    return CategoryModel(
      id: docId,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
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
