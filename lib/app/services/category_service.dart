import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch all categories from Firestore
  /// Falls back to hardcoded data if Firestore fails
  Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _db.collection('categories').get();
      
      if (snapshot.docs.isEmpty) {
        print("--- INFO: No categories found in Firestore, using fallback data ---");
        return _getHardcodedCategories();
      }

        return snapshot.docs
          .map((doc) => CategoryModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print("--- ERROR: Failed to fetch categories from Firestore: $e ---");
      print("--- FALLBACK: Using hardcoded categories ---");
      return _getHardcodedCategories();
    }
  }

  /// Hardcoded fallback categories
  List<CategoryModel> _getHardcodedCategories() {
    return [
      CategoryModel(
        id: "creative_arts",
        name: "Creative Arts",
        description: "Express your artistic side",
        icon: "🎨",
        hobbies: ["Painting", "Drawing", "Photography", "Calligraphy"],
      ),
      CategoryModel(
        id: "music_performing",
        name: "Music & Performing",
        description: "Create with sound and movement",
        icon: "🎵",
        hobbies: ["Guitar", "Piano", "Singing", "Dance"],
      ),
      CategoryModel(
        id: "lifestyle_wellness",
        name: "Lifestyle & Wellness",
        description: "Improve your mind and body",
        icon: "🧘",
        hobbies: ["Yoga", "Fitness/Gym", "Meditation", "Cooking"],
      ),
      CategoryModel(
        id: "skill_strategy",
        name: "Skill & Strategy",
        description: "Challenge your mind",
        icon: "🧠",
        hobbies: ["Coding", "Chess", "Language", "Public Speaking"],
      ),
    ];
  }
}
