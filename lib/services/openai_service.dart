import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:gowhymo/db/study_english.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  final Dio _dio;
  final String apiKey;

  OpenAIService({required this.apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ));

  Future<List<EnglishWord>> fetchWordInfo(List<String> words) async {
    try {
      final prompt = _buildPrompt(words);
      
      final response = await _dio.post(
        '/chat/completions',
        data: {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful assistant that provides English word information.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.3,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        return _parseResponse(content, words);
      } else {
        throw Exception('Failed to fetch word info: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching word info: $e');
    }
  }

  String _buildPrompt(List<String> words) {
    final wordList = words.join(', ');
    return '''
Please provide the following information for each English word: $wordList

For each word, return in this exact JSON format:
{
  "word": "apple",
  "phonetic": "/ˈæpl/",
  "definition": "n. 苹果",
  "example": "I like to eat apples."
}

Return all words as a JSON array. Only return the JSON array, no other text.
''';
  }

  List<EnglishWord> _parseResponse(String content, List<String> words) {
    try {
      final jsonStr = content.trim();
      final List<dynamic> jsonData = json.decode(jsonStr);
      
      return jsonData.map((item) {
        return EnglishWord(
          id: 0,
          kidId: 0,
          word: item['word'] as String,
          phonetic: item['phonetic'] as String?,
          definition: item['definition'] as String,
          example: item['example'] as String?,
          spelling: item['spelling'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to parse OpenAI response: $e');
    }
  }

  Future<EnglishWord> fetchSingleWordInfo(String word) async {
    final words = await fetchWordInfo([word]);
    if (words.isEmpty) {
      throw Exception('No word info returned');
    }
    return words.first;
  }
}
