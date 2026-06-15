import 'package:flutter/material.dart';

/// Represents a single rating axis used in Peer Review.
///
/// Each hobby has its own set of 3 axes. The icon is stored as a
/// Material icon codePoint so it can be serialized/deserialized.
class PeerReviewAxisModel {
  final String label;
  final int iconCodePoint;
  final String? iconFontFamily;

  const PeerReviewAxisModel({
    required this.label,
    required this.iconCodePoint,
    this.iconFontFamily,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);

  /// Creates a [PeerReviewAxisModel] from a Material [IconData],
  /// preserving both the code point and font family for correct rendering.
  factory PeerReviewAxisModel.fromIconData({
    required String label,
    required IconData icon,
  }) {
    return PeerReviewAxisModel(
      label: label,
      iconCodePoint: icon.codePoint,
      iconFontFamily: icon.fontFamily,
    );
  }

  factory PeerReviewAxisModel.fromJson(Map<String, dynamic> json) {
    return PeerReviewAxisModel(
      label: json['label'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.star_outline.codePoint,
      iconFontFamily: json['iconFontFamily'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'iconCodePoint': iconCodePoint,
      if (iconFontFamily != null) 'iconFontFamily': iconFontFamily,
    };
  }

  @override
  String toString() => 'PeerReviewAxisModel(label: $label)';
}

/// Represents a single hobby within a category, bundling its name
/// with its peer review axes in one structured entry.
class HobbyEntry {
  final String name;
  final List<PeerReviewAxisModel> axes;

  const HobbyEntry({required this.name, this.axes = const []});

  factory HobbyEntry.fromJson(Map<String, dynamic> json) {
    return HobbyEntry(
      name: json['name'] as String? ?? '',
      axes: (json['axes'] as List<dynamic>?)
              ?.map((a) => PeerReviewAxisModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (axes.isNotEmpty) 'axes': axes.map((a) => a.toJson()).toList(),
      };

  @override
  String toString() => 'HobbyEntry(name: $name)';
}

/// Represents a hobby category with its associated hobbies and
/// per-hobby peer review axis definitions.
///
/// Each hobby in [hobbies] is a [HobbyEntry] that bundles the hobby name
/// with its 3 review axes, instead of storing them in a separate map.
///
/// The canonical identifier is the Firestore document ID,
/// not the `id` field in the document data.
class CategoryModel {
  final String id;           // Firestore document ID (canonical identifier)
  final String name;         // e.g., "Creative Arts", "Music & Performing"
  final String description;  // e.g., "Express yourself visually"
  final String icon;         // Display emoji, e.g. "🎨", "🎭"
  final List<HobbyEntry> hobbies; // Hobbies with their review axes

  const CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.hobbies,
  });

  /// Convenience getter for hobby name strings.
  List<String> get hobbyNames => hobbies.map((h) => h.name).toList();

  /// Returns the review axes for a specific hobby (case-insensitive lookup).
  /// Returns an empty list if no axes are defined for that hobby.
  List<PeerReviewAxisModel> getAxisForHobby(String hobby) {
    // Direct match first
    final direct = hobbies.where((h) => h.name == hobby);
    if (direct.isNotEmpty) return direct.first.axes;
    // Case-insensitive fallback
    final match = hobbies.where((h) => h.name.toLowerCase() == hobby.toLowerCase());
    return match.isNotEmpty ? match.first.axes : [];
  }

  /// Creates a copy with optionally updated fields.
  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    List<HobbyEntry>? hobbies,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      hobbies: hobbies ?? this.hobbies,
    );
  }

  /// Creates a [CategoryModel] from Firestore document data.
  factory CategoryModel.fromJson(Map<String, dynamic> json, String docId) {
    final hobbiesRaw = json['hobbies'] as List<dynamic>? ?? [];
    final parsedHobbies = hobbiesRaw
        .map((e) => HobbyEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return CategoryModel(
      id: docId,
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      icon: json['icon'] as String? ?? '',
      hobbies: parsedHobbies,
    );
  }

  /// Converts to JSON for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'hobbies': hobbies.map((h) => h.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, hobbies: ${hobbyNames.join(", ")})';
}


