import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class ImgBBService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Future<String> uploadImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final result = await _functions.httpsCallable('uploadUserImage').call({
      'imageBase64': base64Encode(bytes),
      'contentType': _contentTypeFor(imagePath),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final url = data['url']?.toString().trim() ?? '';
    if (url.isEmpty) throw Exception('Image upload returned no URL');
    return url;
  }

  String _contentTypeFor(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
