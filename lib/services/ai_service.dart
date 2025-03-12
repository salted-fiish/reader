import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIService {
  static const String _apiUrl = "https://api.openai.com/v1/chat/completions";
  static const String _apiKey = "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";

  static Future<Map<String, dynamic>> analyzeCharacterRelationships(String content) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json; charset=utf-8"
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "system",
              "content": '''You are a professional literary analysis expert. Please analyze the character relationships in the text and return in JSON format.
Requirements:
1. Identify main and supporting characters
2. Analyze relationships between characters
3. All content must be in English
4. Return in the following format:
{
  "characters": [
    {
      "name": "Character Name",
      "importance": "Main/Supporting",
      "description": "Brief character description"
    }
  ],
  "relationships": [
    {
      "from": "Character1",
      "to": "Character2",
      "type": "Relationship Type",
      "description": "Relationship description"
    }
  ]
}'''
            },
            {
              "role": "user",
              "content": "Please analyze the character relationships in the following text:\n\n$content"
            }
          ],
          "temperature": 0.7
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = responseData["choices"][0]["message"]["content"];
        debugPrint('API response: $content');
        return jsonDecode(content);
      } else {
        debugPrint('API request failed: ${utf8.decode(response.bodyBytes)}');
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error occurred: $e');
      throw Exception('Request failed: $e');
    }
  }
  
  // 新增：识别文本是否为名著并分析当前阅读位置的人物关系
  static Future<Map<String, dynamic>> analyzeBookAndCharacters(String content, {double progress = 0.0}) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json; charset=utf-8"
        },
        body: jsonEncode({
          "model": "gpt-3.5-turbo",
          "messages": [
            {
              "role": "system",
              "content": '''You are a professional literary analysis expert. Please analyze the provided text content, determine if it is a well-known literary work, and analyze character relationships.
Requirements:
1. Determine if the text is a well-known literary work (such as classics, famous novels, etc.)
2. If it is a famous work, please identify which work it is and which plot point the reader has reached
3. Analyze the main character relationships up to the current plot point
4. All content must be in English
5. Return in the following format:
{
  "is_famous_work": true/false,
  "book_info": {
    "title": "Work Title",
    "author": "Author",
    "current_plot": "Description of the current plot point"
  },
  "characters": [
    {
      "name": "Character Name",
      "importance": "Main/Supporting",
      "description": "Brief character description"
    }
  ],
  "relationships": [
    {
      "from": "Character1",
      "to": "Character2",
      "type": "Relationship Type",
      "description": "Relationship description"
    }
  ]
}'''
            },
            {
              "role": "user",
              "content": "Please analyze the following text content, determine if it is a well-known literary work, and analyze character relationships. Current reading progress is approximately ${(progress * 100).toInt()}%:\n\n$content"
            }
          ],
          "temperature": 0.7
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = responseData["choices"][0]["message"]["content"];
        debugPrint('API response: $content');
        return jsonDecode(content);
      } else {
        debugPrint('API request failed: ${utf8.decode(response.bodyBytes)}');
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error occurred: $e');
      throw Exception('Request failed: $e');
    }
  }
}
