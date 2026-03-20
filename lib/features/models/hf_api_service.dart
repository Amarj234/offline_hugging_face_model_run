import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class HFModelInfo {
  final String id;
  final String author;
  final String lastModified;
  final int downloads;
  final int likes;
  final List<String> tags;
  final String? description;

  HFModelInfo({
    required this.id,
    required this.author,
    required this.lastModified,
    required this.downloads,
    required this.likes,
    required this.tags,
    this.description,
  });

  factory HFModelInfo.fromJson(Map<String, dynamic> json) {
    return HFModelInfo(
      id: json['id'] as String,
      author: json['author'] as String,
      lastModified: json['lastModified'] as String,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      description: json['description'] as String?,
    );
  }

  String get shortId => id.contains('/') ? id.split('/').last : id;
  String get name => shortId.replaceAll('-', ' ').replaceAll('_', ' ');
}

class HFAPIService {
  Future<List<HFModelInfo>> searchGGUFModels({String query = ''}) async {
    final searchQuery = query.isEmpty ? AppConstants.hfGgufSearchQuery : '$query ${AppConstants.hfGgufSearchQuery}';
    final url = Uri.parse('${AppConstants.hfModelsUrl}?search=$searchQuery&full=true&limit=20&sort=downloads&direction=-1');
    
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => HFModelInfo.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load models from Hugging Face');
    }
  }

  Future<List<String>> getModelFiles(String modelId) async {
    final url = Uri.parse('${AppConstants.hfApiBaseUrl}/models/$modelId/tree/main');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .where((file) => (file['path'] as String).endsWith('.gguf'))
          .map((file) => file['path'] as String)
          .toList();
    } else {
      throw Exception('Failed to load model files');
    }
  }
}
