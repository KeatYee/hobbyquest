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

  IconData get icon =>
      IconData(iconCodePoint, fontFamily: iconFontFamily ?? 'MaterialIcons');

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
  final String id;
  final String name;
  final String description;
  final int iconCodePoint;
  final String? iconFontFamily;
  final List<HobbyEntry> hobbies;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.hobbies,
  });

  /// Returns the Material [IconData] for this category's icon.
  IconData get icon =>
      IconData(iconCodePoint, fontFamily: iconFontFamily ?? 'MaterialIcons');

  /// Convenience getter for hobby name strings.
  List<String> get hobbyNames => hobbies.map((h) => h.name).toList();

  /// Returns the review axes for a specific hobby (case-insensitive lookup).
  /// Returns an empty list if no axes are defined for that hobby.
  List<PeerReviewAxisModel> getAxisForHobby(String hobby) {
    final direct = hobbies.where((h) => h.name == hobby);
    if (direct.isNotEmpty) return direct.first.axes;
    final match = hobbies.where((h) => h.name.toLowerCase() == hobby.toLowerCase());
    return match.isNotEmpty ? match.first.axes : [];
  }

  /// Creates a copy with optionally updated fields.
  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    int? iconCodePoint,
    String? iconFontFamily,
    List<HobbyEntry>? hobbies,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
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
      iconCodePoint: _readIconCodePoint(json),
      iconFontFamily: json['iconFontFamily'] as String?,
      hobbies: parsedHobbies,
    );
  }

  /// Reads [iconCodePoint] from Firestore data, falling back to a mapping
  /// from the old emoji [icon] field, and ultimately to [Icons.palette].
  static int _readIconCodePoint(Map<String, dynamic> json) {
    final codePoint = json['iconCodePoint'];
    if (codePoint is num) return codePoint.toInt();

    final oldIcon = json['icon'] as String?;
    if (oldIcon != null && oldIcon.isNotEmpty) {
      switch (oldIcon) {
        case '🎨':
          return Icons.palette.codePoint;
        case '🎭':
        case '🎵':
          return Icons.music_note.codePoint;
        case '🧘':
          return Icons.self_improvement.codePoint;
        case '♟️':
        case '🧠':
          return Icons.psychology.codePoint;
      }
    }

    return Icons.palette.codePoint;
  }

  /// Converts to JSON for Firestore.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'iconCodePoint': iconCodePoint,
      if (iconFontFamily != null) 'iconFontFamily': iconFontFamily,
      'hobbies': hobbies.map((h) => h.toJson()).toList(),
    };
  }

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, hobbies: ${hobbyNames.join(", ")})';
}


