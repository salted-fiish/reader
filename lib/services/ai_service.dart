import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  static const String _apiUrl = "https://api.openai.com/v1/chat/completions";
  static const String _apiKey = "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";

  // 估算每个请求的token消耗
  static const int _characterAnalysisTokens = 1500;
  static const int _textSummaryTokens = 2000;

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
        
        // 更新AI使用统计
        await _updateAIUsageStats(characterAnalysis: 1, tokenUsed: _characterAnalysisTokens);
        
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
        
        // 更新AI使用统计
        await _updateAIUsageStats(characterAnalysis: 1, tokenUsed: _characterAnalysisTokens);
        
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
  
  // 新增：对文本内容进行摘要
  static Future<Map<String, dynamic>> summarizeText(String content, {String bookTitle = "", double progress = 0.0}) async {
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
              "content": '''You are a professional literary summarizer. Please provide a concise summary of the provided text content.
Requirements:
1. Summarize the key events, plot points, and character developments
2. Focus on the most important elements of the story up to this point
3. All content must be in English
4. Return in the following JSON format:
{
  "title": "Book title or 'Unknown' if not provided",
  "current_plot_point": "Brief description of the current point in the story",
  "summary": "Comprehensive summary of the story so far",
  "key_events": [
    "Key event 1",
    "Key event 2",
    "Key event 3"
  ],
  "main_characters": [
    "Character 1",
    "Character 2",
    "Character 3"
  ]
}'''
            },
            {
              "role": "user",
              "content": "Please summarize the following text content from ${bookTitle.isEmpty ? 'a book' : '"$bookTitle"'}. Current reading progress is approximately ${(progress * 100).toInt()}%:\n\n$content"
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
        
        // 更新AI使用统计
        await _updateAIUsageStats(textSummary: 1, tokenUsed: _textSummaryTokens);
        
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
  
  // 更新AI使用量统计数据
  static Future<void> _updateAIUsageStats({int characterAnalysis = 0, int textSummary = 0, int tokenUsed = 0}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 从SharedPreferences加载AI使用量统计数据
      int characterAnalysisCount = prefs.getInt('ai_character_analysis_count') ?? 12;
      int textSummaryCount = prefs.getInt('ai_text_summary_count') ?? 8;
      int totalAIRequests = prefs.getInt('ai_total_requests') ?? 20;
      int remainingTokens = prefs.getInt('ai_remaining_tokens') ?? 75000;
      int totalTokens = prefs.getInt('ai_total_tokens') ?? 100000;
      
      // 更新统计数据
      characterAnalysisCount += characterAnalysis;
      textSummaryCount += textSummary;
      totalAIRequests += (characterAnalysis + textSummary);
      remainingTokens = (remainingTokens - tokenUsed).clamp(0, totalTokens);
      
      // 保存更新后的数据
      await prefs.setInt('ai_character_analysis_count', characterAnalysisCount);
      await prefs.setInt('ai_text_summary_count', textSummaryCount);
      await prefs.setInt('ai_total_requests', totalAIRequests);
      await prefs.setInt('ai_remaining_tokens', remainingTokens);
      await prefs.setInt('ai_total_tokens', totalTokens);
      
      debugPrint('AI使用统计已更新: 人物分析=$characterAnalysisCount, 文本摘要=$textSummaryCount, 总请求=$totalAIRequests, 剩余Token=$remainingTokens');
    } catch (e) {
      debugPrint('更新AI使用统计失败: $e');
    }
  }
}
