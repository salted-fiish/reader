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
              "content": '''你是一个专业的中文文学分析专家。请用中文分析文本中的人物关系，并以JSON格式返回。
要求：
1. 识别主要人物和次要人物
2. 分析人物之间的关系
3. 所有内容必须用中文回复
4. 返回格式如下：
{
  "characters": [
    {
      "name": "人物中文名称",
      "importance": "主要/次要",
      "description": "人物简要描述（中文）"
    }
  ],
  "relationships": [
    {
      "from": "人物1",
      "to": "人物2",
      "type": "关系类型",
      "description": "关系描述（中文）"
    }
  ]
}'''
            },
            {
              "role": "user",
              "content": "请用中文分析以下文本中的人物关系：\n\n$content"
            }
          ],
          "temperature": 0.7
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = responseData["choices"][0]["message"]["content"];
        debugPrint('API响应: $content');
        return jsonDecode(content);
      } else {
        debugPrint('API请求失败: ${utf8.decode(response.bodyBytes)}');
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('发生错误: $e');
      throw Exception('请求失败: $e');
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
              "content": '''你是一个专业的中文文学分析专家。请分析提供的文本内容，判断是否为知名文学作品，并分析人物关系。
要求：
1. 判断文本是否为知名文学作品（如名著、知名小说等）
2. 如果是知名作品，请识别这是哪部作品，当前阅读到了哪个情节
3. 分析当前情节之前的主要人物关系
4. 所有内容必须用中文回复
5. 返回格式如下：
{
  "is_famous_work": true/false,
  "book_info": {
    "title": "作品名称",
    "author": "作者",
    "current_plot": "当前阅读到的情节描述"
  },
  "characters": [
    {
      "name": "人物中文名称",
      "importance": "主要/次要",
      "description": "人物简要描述（中文）"
    }
  ],
  "relationships": [
    {
      "from": "人物1",
      "to": "人物2",
      "type": "关系类型",
      "description": "关系描述（中文）"
    }
  ]
}'''
            },
            {
              "role": "user",
              "content": "请分析以下文本内容，判断是否为知名文学作品，并分析人物关系。当前阅读进度约为${(progress * 100).toInt()}%：\n\n$content"
            }
          ],
          "temperature": 0.7
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final content = responseData["choices"][0]["message"]["content"];
        debugPrint('API响应: $content');
        return jsonDecode(content);
      } else {
        debugPrint('API请求失败: ${utf8.decode(response.bodyBytes)}');
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('发生错误: $e');
      throw Exception('请求失败: $e');
    }
  }
}
