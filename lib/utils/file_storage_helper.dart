import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class FileStorageHelper {
  /// 获取应用程序的永久存储目录
  static Future<Directory> getAppDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final booksDirectory = Directory('${directory.path}/books');
    
    // 确保目录存在
    if (!await booksDirectory.exists()) {
      await booksDirectory.create(recursive: true);
    }
    
    return booksDirectory;
  }
  
  /// 将文件复制到应用的永久存储目录
  static Future<String> copyFileToAppStorage(File sourceFile, {String? customFileName}) async {
    try {
      final fileName = customFileName ?? sourceFile.path.split('/').last;
      final appDir = await getAppDocumentsDirectory();
      final targetPath = '${appDir.path}/$fileName';
      
      // 检查目标文件是否已存在
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        // 如果文件已存在，返回现有文件路径
        return targetPath;
      }
      
      // 复制文件到永久存储目录
      final newFile = await sourceFile.copy(targetPath);
      return newFile.path;
    } catch (e) {
      debugPrint('复制文件到应用存储失败: $e');
      rethrow;
    }
  }
  
  /// 生成不重复的文件名
  static Future<String> generateUniqueFileName(String originalFileName, List<String> existingPaths) async {
    // 分离文件名和扩展名
    final lastDotIndex = originalFileName.lastIndexOf('.');
    if (lastDotIndex == -1) {
      return originalFileName; // 没有扩展名
    }
    
    final fileNameWithoutExt = originalFileName.substring(0, lastDotIndex);
    final fileExt = originalFileName.substring(lastDotIndex);
    
    // 检查是否有同名文件
    bool hasDuplicate = existingPaths.any((path) => 
      path.split('/').last == originalFileName
    );
    
    if (!hasDuplicate) {
      return originalFileName;
    }
    
    // 生成带后缀的文件名
    int suffix = 1;
    String newFileName;
    bool isUnique;
    
    do {
      newFileName = '$fileNameWithoutExt($suffix)$fileExt';
      isUnique = !existingPaths.any((path) => 
        path.split('/').last == newFileName
      );
      suffix++;
    } while (!isUnique);
    
    return newFileName;
  }
  
  /// 检查文件是否在应用的永久存储目录中
  static Future<bool> isFileInAppStorage(String filePath) async {
    final appDir = await getAppDocumentsDirectory();
    return filePath.startsWith(appDir.path);
  }
} 