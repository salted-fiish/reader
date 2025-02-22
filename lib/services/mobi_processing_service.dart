import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MobiProcessingService {
  // 替换为您的服务器地址
  static const String baseUrl = 'http://52.77.224.172:5000';

  Future<String> uploadMobiFile(File file) async {
    try {
      // 创建multipart请求
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload-mobi'),
      );

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // 发送请求
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['processedFileUrl'];
      } else {
        throw Exception('上传失败: ${jsonResponse['message']}');
      }
    } catch (e) {
      throw Exception('处理MOBI文件时出错: $e');
    }
  }

  Future<void> downloadProcessedFile(String url, String localPath) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('下载失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('下载处理后的文件时出错: $e');
    }
  }
} 