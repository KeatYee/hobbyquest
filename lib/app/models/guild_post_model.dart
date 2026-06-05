import 'package:cloud_firestore/cloud_firestore.dart';

class GuildPostModel {
  final String id;
  final String userId;
  final String hobby;
  final String categoryId;
  final String title;
  final String body;
  final String imageUrl;
  final int likes;
  final int replies;
  final DateTime? createdAt;

  const GuildPostModel({
    required this.id,
    required this.userId,
    required this.hobby,
    required this.categoryId,
    required this.title,
    required this.body,
    this.imageUrl = '',
    required this.likes,
    required this.replies,
    this.createdAt,
  });

  factory GuildPostModel.fromJson(Map<String, dynamic> json, String docId) {
    return GuildPostModel(
      id: docId,
      userId: json['userId'] as String? ?? (json['user_id'] as String? ?? (json['author'] as String? ?? 'Unknown')),
      hobby: json['hobby'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? (json['category_id'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? (json['content'] as String? ?? ''),
      imageUrl: json['imageUrl'] as String? ?? '',
      likes: _readInt(json['likes']) ?? 0,
      replies: _readInt(json['replies']) ?? 0,
      createdAt: _readDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'hobby': hobby,
      'categoryId': categoryId,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'likes': likes,
      'replies': replies,
      'createdAt': createdAt,
    };
  }

  GuildPostModel copyWith({
    String? id,
    String? userId,
    String? hobby,
    String? categoryId,
    String? title,
    String? body,
    String? imageUrl,
    int? likes,
    int? replies,
    DateTime? createdAt,
  }) {
    return GuildPostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hobby: hobby ?? this.hobby,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}
