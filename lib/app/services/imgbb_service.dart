import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ImgBBService {
  String get _apiKey {
    final key = dotenv.env['IMGBB_API_KEY'] ?? dotenv.env['IMGBB_KEY'] ?? '';
    return key.trim();
  }

  Future<String> uploadImage(String imagePath) async {
    if (_apiKey.isEmpty) {
      throw Exception('ImgBB API key is not configured');
    }

    final uri = Uri.https('api.imgbb.com', '/1/upload', {'key': _apiKey});
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      throw Exception('ImgBB upload failed: ${streamedResponse.statusCode}');
    }

    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final data = decoded['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('ImgBB returned an unexpected response');
    }

    final directUrl = _extractDirectUrl(data);
    if (directUrl.isEmpty) {
      throw Exception('ImgBB did not return a direct image URL');
    }

    return directUrl;
  }

  String _extractDirectUrl(Map<String, dynamic> data) {
    final image = data['image'];
    if (image is Map<String, dynamic>) {
      final imageUrl = image['url'] as String?;
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        return imageUrl.trim();
      }
    }

    final directUrl = data['url'] as String?;
    if (directUrl != null && directUrl.trim().isNotEmpty) {
      return directUrl.trim();
    }

    final displayUrl = data['display_url'] as String?;
    if (displayUrl != null && displayUrl.trim().isNotEmpty) {
      return displayUrl.trim();
    }

    return '';
  }
}