import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
        hobbies: [
          HobbyEntry(name: "Painting", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Creativity', icon: Icons.lightbulb_outline),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.brush),
            PeerReviewAxisModel.fromIconData(label: 'Color Theory', icon: Icons.palette_outlined),
          ]),
          HobbyEntry(name: "Drawing", axes: [
            PeerReviewAxisModel.fromIconData(label: 'flutter', icon: Icons.grid_view),
            PeerReviewAxisModel.fromIconData(label: 'Line Work', icon: Icons.gesture),
            PeerReviewAxisModel.fromIconData(label: 'Shading', icon: Icons.gradient),
          ]),
          HobbyEntry(name: "Photography", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Composition', icon: Icons.center_focus_strong),
            PeerReviewAxisModel.fromIconData(label: 'Lighting', icon: Icons.wb_sunny),
            PeerReviewAxisModel.fromIconData(label: 'Editing', icon: Icons.tune),
          ]),
          HobbyEntry(name: "Calligraphy", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Letter Form', icon: Icons.text_fields),
            PeerReviewAxisModel.fromIconData(label: 'Consistency', icon: Icons.compare_arrows),
            PeerReviewAxisModel.fromIconData(label: 'Ink Control', icon: Icons.edit),
          ]),
        ],
      ),
      CategoryModel(
        id: "music_performing",
        name: "Music & Performing",
        description: "Create with sound and movement",
        icon: "🎵",
        hobbies: [
          HobbyEntry(name: "Guitar", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Rhythm', icon: Icons.music_note),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.touch_app),
            PeerReviewAxisModel.fromIconData(label: 'Musicality', icon: Icons.hearing),
          ]),
          HobbyEntry(name: "Piano", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.piano),
            PeerReviewAxisModel.fromIconData(label: 'Expression', icon: Icons.sentiment_satisfied_alt),
            PeerReviewAxisModel.fromIconData(label: 'Sight Reading', icon: Icons.visibility),
          ]),
          HobbyEntry(name: "Singing", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Pitch', icon: Icons.graphic_eq),
            PeerReviewAxisModel.fromIconData(label: 'Tone', icon: Icons.mic),
            PeerReviewAxisModel.fromIconData(label: 'Breath Control', icon: Icons.air),
          ]),
          HobbyEntry(name: "Dance", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Choreography', icon: Icons.directions_run),
            PeerReviewAxisModel.fromIconData(label: 'Expression', icon: Icons.mood),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.accessibility_new),
          ]),
        ],
      ),
      CategoryModel(
        id: "lifestyle_wellness",
        name: "Lifestyle & Wellness",
        description: "Improve your mind and body",
        icon: "🧘",
        hobbies: [
          HobbyEntry(name: "Yoga", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Alignment', icon: Icons.straighten),
            PeerReviewAxisModel.fromIconData(label: 'Flexibility', icon: Icons.accessibility),
            PeerReviewAxisModel.fromIconData(label: 'Mindfulness', icon: Icons.self_improvement),
          ]),
          HobbyEntry(name: "Fitness/Gym", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Form', icon: Icons.fitness_center),
            PeerReviewAxisModel.fromIconData(label: 'Intensity', icon: Icons.trending_up),
            PeerReviewAxisModel.fromIconData(label: 'Consistency', icon: Icons.loop),
          ]),
          HobbyEntry(name: "Meditation", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Focus', icon: Icons.center_focus_strong),
            PeerReviewAxisModel.fromIconData(label: 'Duration', icon: Icons.timer),
            PeerReviewAxisModel.fromIconData(label: 'Mindfulness', icon: Icons.spa),
          ]),
          HobbyEntry(name: "Cooking", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Taste', icon: Icons.restaurant),
            PeerReviewAxisModel.fromIconData(label: 'Presentation', icon: Icons.dinner_dining),
            PeerReviewAxisModel.fromIconData(label: 'Technique', icon: Icons.kitchen),
          ]),
        ],
      ),
      CategoryModel(
        id: "skill_strategy",
        name: "Skill & Strategy",
        description: "Challenge your mind",
        icon: "🧠",
        hobbies: [
          HobbyEntry(name: "Coding", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Code Quality', icon: Icons.code),
            PeerReviewAxisModel.fromIconData(label: 'Efficiency', icon: Icons.speed),
            PeerReviewAxisModel.fromIconData(label: 'Readability', icon: Icons.article),
          ]),
          HobbyEntry(name: "Chess", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Strategy', icon: Icons.psychology),
            PeerReviewAxisModel.fromIconData(label: 'Tactics', icon: Icons.bolt),
            PeerReviewAxisModel.fromIconData(label: 'Endgame', icon: Icons.flag),
          ]),
          HobbyEntry(name: "Language", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Vocabulary', icon: Icons.menu_book),
            PeerReviewAxisModel.fromIconData(label: 'Grammar', icon: Icons.checklist),
            PeerReviewAxisModel.fromIconData(label: 'Pronunciation', icon: Icons.record_voice_over),
          ]),
          HobbyEntry(name: "Public Speaking", axes: [
            PeerReviewAxisModel.fromIconData(label: 'Clarity', icon: Icons.record_voice_over),
            PeerReviewAxisModel.fromIconData(label: 'Engagement', icon: Icons.group),
            PeerReviewAxisModel.fromIconData(label: 'Structure', icon: Icons.account_tree),
          ]),
        ],
      ),
    ];
  }
}
