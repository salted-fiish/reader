import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/file_storage_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_screen.dart';
import 'txt_viewer_screen.dart';
import 'epub_viewer_screen.dart';

enum BookType {
  pdf,
  txt,
  epub,
  mobi,
  unknown
}

// 自定义Book类，不依赖MobiProcessingService
class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String fileUrl;
  final String description;
  final String format; // pdf, epub, txt, mobi
  final int size; // 文件大小，单位为字节
  final String uploadDate;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.fileUrl,
    required this.description,
    required this.format,
    required this.size,
    required this.uploadDate,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      description: json['description'] ?? '',
      format: json['format'] ?? '',
      size: json['size'] ?? 0,
      uploadDate: json['uploadDate'] ?? '',
    );
  }
}

class AllBooksScreen extends StatefulWidget {
  final List<String>? bookPaths;
  final Map<String, double>? bookProgress;
  final Function(String)? onOpenBook;
  final Function(int, String)? onDeleteBook;

  const AllBooksScreen({
    super.key,
    this.bookPaths,
    this.bookProgress,
    this.onOpenBook,
    this.onDeleteBook,
  });

  @override
  State<AllBooksScreen> createState() => _AllBooksScreenState();
}

class _AllBooksScreenState extends State<AllBooksScreen> {
  // 服务器地址
  static const String baseUrl = 'http://52.77.224.172:5000';
  
  List<Book> _books = [];
  bool _isLoading = true;
  String _errorMessage = '';
  
  // 记录下载状态
  final Map<String, bool> _downloadingBooks = {};
  final Map<String, double> _downloadProgress = {};
  
  // 记录已下载的书籍
  final Map<String, String> _downloadedBooks = {};

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _loadDownloadedBooks();
    
    // 添加监听器，定期检查书籍文件是否存在
    _startFileExistenceChecker();
  }
  
  @override
  void dispose() {
    // 取消定时器
    _fileCheckerTimer?.cancel();
    super.dispose();
  }
  
  // 定时器引用
  Timer? _fileCheckerTimer;
  
  // 启动文件存在性检查器
  void _startFileExistenceChecker() {
    // 每30秒检查一次
    _fileCheckerTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkDownloadedFilesExistence();
    });
    
    // 立即执行一次检查
    _checkDownloadedFilesExistence();
  }
  
  // 检查已下载文件是否存在
  Future<void> _checkDownloadedFilesExistence() async {
    print('DEBUG: 开始检查已下载文件是否存在');
    bool needsUpdate = false;
    
    // 创建一个临时映射，避免在迭代过程中修改原映射
    final Map<String, String> tempMap = Map.from(_downloadedBooks);
    
    for (var entry in tempMap.entries) {
      final bookId = entry.key;
      final localPath = entry.value;
      
      final file = File(localPath);
      if (!file.existsSync()) {
        print('DEBUG: 文件不存在，需要清理记录: $localPath');
        _downloadedBooks.remove(bookId);
        needsUpdate = true;
        
        // 同时从pdf_paths中移除
        await _removeFromPdfPaths(localPath);
      }
    }
    
    if (needsUpdate) {
      print('DEBUG: 有文件不存在，更新下载记录');
      await _saveDownloadedBooks();
      
      // 如果界面已挂载，刷新UI
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  // 加载服务器上的书籍
  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final books = await _getBookList();
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载书籍失败: $e';
        _isLoading = false;
      });
    }
  }

  // 获取服务器上的书籍列表
  Future<List<Book>> _getBookList() async {
    // try {
    //   final response = await http.get(Uri.parse('$baseUrl/books'));
      
    //   if (response.statusCode == 200) {
    //     final List<dynamic> jsonList = json.decode(response.body);
    //     return jsonList.map((json) => Book.fromJson(json)).toList();
    //   } else {
    //     throw Exception('获取书籍列表失败: ${response.statusCode}');
    //   }
    // } catch (e) {
      // 如果服务器未实现此接口，返回模拟数据用于测试
      return _getMockBooks();
    // }
  }
  
  // 模拟数据，用于测试
  List<Book> _getMockBooks() {
    return [
      Book(
        id: '1',
        title: '三体',
        author: '刘慈欣',
        coverUrl: 'https://img9.doubanio.com/view/subject/s/public/s2768378.jpg',
        fileUrl: '$baseUrl/download/santi.epub',
        description: '文化大革命如火如荼进行的同时，军方探寻外星文明的绝秘计划"红岸工程"取得了突破性进展。但在按下发射键的那一刻，历经劫难的叶文洁没有意识到，她彻底改变了人类的命运。地球文明向宇宙发出的第一声啼鸣，以太阳为中心，以光速向宇宙深处飞驰……',
        format: 'epub',
        size: 2048000,
        uploadDate: '2023-05-15',
      ),
      Book(
        id: '2',
        title: '活着',
        author: '余华',
        coverUrl: 'https://img2.doubanio.com/view/subject/s/public/s29053580.jpg',
        fileUrl: '$baseUrl/download/huozhe.pdf',
        description: '《活着》是作家余华的代表作之一，讲述了农村人福贵悲惨的人生遭遇。福贵本是个阔少爷，可他嗜赌如命，终于赌光了家业，一贫如洗。他的父亲被他活活气死，母亲则在穷困中患了重病，福贵前去求药，却在途中被国民党抓去当壮丁。经过几番波折回到家里，才知道母亲早已去世，他的妻子家珍含辛茹苦地养大两个儿女。此后更加悲惨的命运一次又一次降临到福贵身上，他的女儿凤霞、儿子有庆、妻子家珍、女婿二喜、外孙苦根先后死去，最后只剩福贵和一头老牛相依为命，但老人依旧活着，仿佛比往日更加洒脱与坚强。',
        format: 'pdf',
        size: 3145728,
        uploadDate: '2023-06-20',
      ),
      Book(
        id: '3',
        title: '百年孤独',
        author: '加西亚·马尔克斯',
        coverUrl: 'https://img2.doubanio.com/view/subject/s/public/s6384944.jpg',
        fileUrl: '$baseUrl/download/bainiangudu.txt',
        description: '《百年孤独》是魔幻现实主义文学的代表作，描写了布恩迪亚家族七代人的传奇故事，以及加勒比海沿岸小镇马孔多的百年兴衰，反映了拉丁美洲一个世纪以来风云变幻的历史。作品融入神话传说、民间故事、宗教典故等神秘因素，巧妙地糅合了现实与虚幻，展现出一个瑰丽的想象世界，并借此反映了拉丁美洲的现实。',
        format: 'txt',
        size: 1048576,
        uploadDate: '2023-07-10',
      ),
      Book(
        id: '4',
        title: '围城',
        author: '钱钟书',
        coverUrl: 'https://img1.doubanio.com/view/subject/s/public/s1070222.jpg',
        fileUrl: '$baseUrl/download/weicheng.mobi',
        description: '《围城》是钱钟书所著的长篇小说，是中国现代文学史上的经典作品之一。小说描写了青年方鸿渐从国外留学回来后的生活经历，以及他与孙柔嘉、唐晓芙、赵辛楣等人的感情纠葛。小说借方鸿渐的婚姻生活，反映了当时社会的世态人情，对人性进行了深刻的剖析和批判。',
        format: 'mobi',
        size: 4194304,
        uploadDate: '2023-08-05',
      ),
      Book(
        id: '5',
        title: '平凡的世界',
        author: '路遥',
        coverUrl: 'https://img9.doubanio.com/view/subject/s/public/s1144911.jpg',
        fileUrl: '$baseUrl/download/pingfandeshijie.epub',
        description: '《平凡的世界》是中国作家路遥创作的一部全景式地表现中国当代城乡社会生活的长篇小说。全书共三部，描述了中国西北黄土高原上的普通人们，在大时代历史进程中所走过的艰难曲折的道路。',
        format: 'epub',
        size: 5242880,
        uploadDate: '2023-09-15',
      ),
    ];
  }
  
  // 加载已下载的书籍记录
  Future<void> _loadDownloadedBooks() async {
    print('DEBUG: 开始加载已下载的书籍记录');
    final prefs = await SharedPreferences.getInstance();
    final downloadedBooksJson = prefs.getString('downloaded_books') ?? '{}';
    print('DEBUG: 从SharedPreferences读取的JSON: $downloadedBooksJson');
    final Map<String, dynamic> downloadedBooksMap = json.decode(downloadedBooksJson);
    
    setState(() {
      _downloadedBooks.clear();
      downloadedBooksMap.forEach((key, value) {
        _downloadedBooks[key] = value.toString();
        print('DEBUG: 加载书籍记录 - ID: $key, 路径: $value');
      });
    });
    print('DEBUG: 已下载书籍记录加载完成，共 ${_downloadedBooks.length} 条记录');
  }
  
  // 保存已下载的书籍记录
  Future<void> _saveDownloadedBooks() async {
    print('DEBUG: 保存_downloadedBooks: ${_downloadedBooks.toString()}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloaded_books', json.encode(_downloadedBooks));
    print('DEBUG: _downloadedBooks已保存到SharedPreferences');
  }
  
  // 下载书籍文件
  Future<String?> _downloadBookFile(Book book, String localDirectory) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        print('DEBUG: 开始下载书籍: ${book.title}, ID: ${book.id}, 尝试次数: ${retryCount + 1}');
        // 检查是否已经有相同文件名的书籍
        final fileName = '${book.title}.${book.format}';
        final sanitizedFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final localPath = '$localDirectory/$sanitizedFileName';
        
        print('DEBUG: 生成本地路径: $localPath');
        
        // 如果文件已存在，先删除它
        final existingFile = File(localPath);
        if (existingFile.existsSync()) {
          print('DEBUG: 发现同名文件已存在，准备删除');
          await existingFile.delete();
          print('DEBUG: 同名文件删除成功');
        } else {
          print('DEBUG: 没有发现同名文件');
        }
        
        print('DEBUG: 准备发送HTTP请求: ${book.fileUrl}');
        
        // 使用超时设置，避免无限等待
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(book.fileUrl));
          final streamedResponse = await client.send(request).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('DEBUG: HTTP请求超时');
              client.close();
              throw TimeoutException('下载请求超时');
            },
          );
          
          print('DEBUG: HTTP请求完成，状态码: ${streamedResponse.statusCode}');
          
          if (streamedResponse.statusCode == 200) {
            print('DEBUG: 请求成功，准备写入文件');
            
            // 创建文件
            final file = File(localPath);
            
            // 使用临时文件先下载，下载完成后再重命名，避免下载中断导致文件损坏
            final tempFile = File('$localPath.temp');
            final sink = tempFile.openWrite();
            
            int totalBytes = streamedResponse.contentLength ?? 0;
            int receivedBytes = 0;
            
            print('DEBUG: 开始接收数据流，总大小: $totalBytes 字节');
            
            try {
              await for (var chunk in streamedResponse.stream) {
                sink.add(chunk);
                receivedBytes += chunk.length;
                
                // 更新下载进度
                if (totalBytes > 0) {
                  final progress = receivedBytes / totalBytes;
                  // 更新UI中的下载进度
                  if (mounted) {
                    setState(() {
                      _downloadProgress[book.id] = progress;
                    });
                  }
                }
                
                print('DEBUG: 已接收 $receivedBytes / $totalBytes 字节 (${totalBytes > 0 ? (receivedBytes / totalBytes * 100).toStringAsFixed(1) : "未知"}%)');
              }
              
              // 确保所有数据都写入文件
              await sink.flush();
              await sink.close();
              
              print('DEBUG: 数据流接收完成，检查临时文件');
              
              // 检查临时文件是否存在且大小正确
              if (tempFile.existsSync()) {
                final fileSize = await tempFile.length();
                print('DEBUG: 临时文件大小: $fileSize 字节');
                
                if (totalBytes > 0 && fileSize < totalBytes) {
                  print('DEBUG: 警告：文件大小不匹配，可能下载不完整');
                  throw Exception('文件下载不完整');
                }
                
                // 如果目标文件已存在，先删除
                if (file.existsSync()) {
                  await file.delete();
                }
                
                // 重命名临时文件为正式文件
                await tempFile.rename(localPath);
                print('DEBUG: 临时文件重命名为正式文件成功');
                
                return localPath;
              } else {
                print('DEBUG: 错误：临时文件不存在');
                throw Exception('临时文件不存在');
          }
        } catch (e) {
              // 确保关闭sink
              await sink.close();
              print('DEBUG: 数据流处理过程中出错: $e');
              
              // 检查是否已经下载了足够多的数据（99.9%以上）
              if (totalBytes > 0 && receivedBytes >= totalBytes * 0.999) {
                print('DEBUG: 虽然出现错误，但已下载99.9%以上的数据，视为下载成功');
                
                // 如果目标文件已存在，先删除
                if (file.existsSync()) {
                  await file.delete();
                }
                
                // 检查临时文件是否存在
                if (tempFile.existsSync()) {
                  // 重命名临时文件为正式文件
                  await tempFile.rename(localPath);
                  print('DEBUG: 临时文件重命名为正式文件成功');
                  return localPath;
                }
              }
              
              // 删除可能存在的临时文件
              if (tempFile.existsSync()) {
                await tempFile.delete();
                print('DEBUG: 已删除临时文件');
              }
              
              throw e;
            } finally {
              client.close();
            }
          } else {
            client.close();
            print('DEBUG: 请求失败，状态码: ${streamedResponse.statusCode}');
            throw Exception('下载书籍失败: ${streamedResponse.statusCode}');
          }
        } finally {
          client.close();
        }
      } catch (e) {
        print('DEBUG: 下载过程中出现异常: $e');
        retryCount++;
        
        if (retryCount < maxRetries) {
          print('DEBUG: 将在3秒后重试，剩余重试次数: ${maxRetries - retryCount}');
          await Future.delayed(const Duration(seconds: 3));
        } else {
          print('DEBUG: 已达到最大重试次数，放弃下载');
          throw Exception('下载书籍时出错: $e');
        }
      }
    }
    
    throw Exception('下载书籍失败，已达到最大重试次数');
  }
  
  // 打开已下载的书籍
  void _openDownloadedBook(Book book) {
    print('DEBUG: 尝试打开书籍: ${book.title}, ID: ${book.id}');
    final localPath = _downloadedBooks[book.id];
    print('DEBUG: 本地路径: $localPath');
    if (localPath == null) {
      print('DEBUG: 书籍未下载，在_downloadedBooks中找不到记录');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书籍未下载')),
      );
      return;
    }
    
    print('DEBUG: 找到本地路径: $localPath');
    final file = File(localPath);
    if (!file.existsSync()) {
      print('DEBUG: 文件不存在，需要清理记录');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书籍文件不存在，请重新下载')),
      );
      // 移除无效的下载记录
      _downloadedBooks.remove(book.id);
      _saveDownloadedBooks();
      print('DEBUG: 已从_downloadedBooks中移除记录');
      
      // 同时从pdf_paths中移除
      _removeFromPdfPaths(localPath);
      print('DEBUG: 已从pdf_paths中移除记录');
      return;
    }
    
    print('DEBUG: 文件存在，准备打开');
    // 如果有外部打开回调，使用回调
    if (widget.onOpenBook != null) {
      print('DEBUG: 使用外部回调打开书籍');
      widget.onOpenBook!(localPath);
      return;
    }
    
    // 否则根据文件格式打开不同的阅读器
    print('DEBUG: 根据格式选择阅读器: ${book.format}');
    Widget viewer;
    switch (book.format) {
      case 'pdf':
        viewer = PDFViewerScreen(
          pdfPath: localPath,
          onProgressChanged: (progress) async {
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$localPath', progress);
          },
        );
        break;
      case 'txt':
        viewer = TxtViewerScreen(
          txtPath: localPath,
          onProgressChanged: (progress) async {
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$localPath', progress);
          },
        );
        break;
      case 'epub':
        viewer = EpubViewerScreen(
          epubPath: localPath,
          onProgressChanged: (progress) async {
            // 保存阅读进度
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('progress_$localPath', progress);
          },
        );
        break;
      default:
        print('DEBUG: 不支持的文件格式: ${book.format}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持的文件格式: ${book.format}')),
        );
        return;
    }
    
    print('DEBUG: 打开阅读器');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => viewer),
    );
  }
  
  // 下载书籍
  Future<void> _downloadBook(Book book) async {
    print('DEBUG: 开始_downloadBook流程: ${book.title}, ID: ${book.id}');
    // 如果已经在下载中，不重复下载
    if (_downloadingBooks[book.id] == true) {
      print('DEBUG: 书籍正在下载中，跳过');
      return;
    }
    
    // 检查是否已经下载过但文件不存在
    if (_downloadedBooks.containsKey(book.id)) {
      print('DEBUG: 发现书籍在_downloadedBooks中有记录');
      final existingPath = _downloadedBooks[book.id];
      print('DEBUG: 现有路径: $existingPath');
      
      if (existingPath != null && !File(existingPath).existsSync()) {
        print('DEBUG: 文件不存在，清理记录');
        // 移除无效的下载记录
        _downloadedBooks.remove(book.id);
        await _saveDownloadedBooks();
        print('DEBUG: 已从_downloadedBooks中移除记录');
        
        // 同时从pdf_paths中移除
        await _removeFromPdfPaths(existingPath);
        print('DEBUG: 已从pdf_paths中移除记录');
      } else if (existingPath != null && File(existingPath).existsSync()) {
        print('DEBUG: 文件已存在，可以直接打开');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${book.title} 已下载，可以直接阅读')),
        );
        return;
      }
    } else {
      print('DEBUG: 书籍在_downloadedBooks中没有记录');
    }
    
    print('DEBUG: 设置下载状态');
    setState(() {
      _downloadingBooks[book.id] = true;
      _downloadProgress[book.id] = 0.0;
    });
    
    try {
      print('DEBUG: 获取应用文档目录');
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        print('DEBUG: 创建books目录');
        await booksDir.create(recursive: true);
      }
      
      print('DEBUG: 调用_downloadBookFile下载书籍');
      // 下载书籍
      String localPath;
      try {
        final result = await _downloadBookFile(book, booksDir.path);
        if (result == null) {
          throw Exception('下载返回null路径');
        }
        localPath = result;
        print('DEBUG: 下载完成，本地路径: $localPath');
      } catch (e) {
        print('DEBUG: _downloadBookFile抛出异常: $e');
        // 重新抛出异常，让外层catch捕获
        rethrow;
      }
      
      // 检查文件是否真的存在
      final downloadedFile = File(localPath);
      if (!downloadedFile.existsSync()) {
        print('DEBUG: 警告：下载完成但文件不存在！');
        throw Exception('下载完成但文件不存在');
      }
      
      print('DEBUG: 更新下载状态');
      // 更新下载状态
      setState(() {
        _downloadingBooks[book.id] = false;
        _downloadedBooks[book.id] = localPath;
      });
      
      print('DEBUG: 保存下载记录到SharedPreferences');
      // 保存下载记录
      await _saveDownloadedBooks();
      
      print('DEBUG: 将书籍添加到pdf_paths');
      // 将下载的书籍添加到应用的书籍列表中
      final prefs = await SharedPreferences.getInstance();
      List<String> paths = prefs.getStringList('pdf_paths') ?? [];
      if (!paths.contains(localPath)) {
        print('DEBUG: 添加新路径到pdf_paths');
        paths.add(localPath);
        await prefs.setStringList('pdf_paths', paths);
        // 初始化进度
        await prefs.setDouble('progress_$localPath', 0.0);
        print('DEBUG: 初始化阅读进度');
      } else {
        print('DEBUG: 路径已存在于pdf_paths中');
      }
      
      // 显示下载成功提示
      if (mounted) {
        print('DEBUG: 显示下载成功提示');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${book.title} 下载成功，已添加到您的书桌')),
        );
      }
    } catch (e) {
      print('DEBUG: 下载过程中出现异常: $e');
      // 更新下载状态
      setState(() {
        _downloadingBooks[book.id] = false;
      });
      
      // 显示错误提示
      if (mounted) {
        // 根据错误类型提供更具体的错误信息
        String errorMessage = '下载失败';
        
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Connection closed') ||
            e.toString().contains('Connection reset') ||
            e.toString().contains('Connection refused')) {
          errorMessage = '网络连接错误，请检查您的网络连接';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = '下载超时，请稍后重试';
        } else if (e.toString().contains('404')) {
          errorMessage = '文件不存在，请联系管理员';
        } else if (e.toString().contains('403')) {
          errorMessage = '没有权限下载此文件';
        } else {
          errorMessage = '下载失败: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      
      // 清理可能存在的部分下载文件
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDir.path}/books');
        final fileName = '${book.title}.${book.format}';
        final sanitizedFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final localPath = '${booksDir.path}/$sanitizedFileName';
        
        // 检查并删除可能存在的文件和临时文件
        final file = File(localPath);
        if (file.existsSync()) {
          await file.delete();
          print('DEBUG: 已删除部分下载的文件: $localPath');
        }
        
        final tempFile = File('$localPath.temp');
        if (tempFile.existsSync()) {
          await tempFile.delete();
          print('DEBUG: 已删除临时文件: $localPath.temp');
        }
      } catch (cleanupError) {
        print('DEBUG: 清理文件时出错: $cleanupError');
      }
    }
  }
  
  // 从pdf_paths中移除指定路径
  Future<void> _removeFromPdfPaths(String path) async {
    print('DEBUG: 开始从pdf_paths中移除路径: $path');
    final prefs = await SharedPreferences.getInstance();
    List<String> paths = prefs.getStringList('pdf_paths') ?? [];
    print('DEBUG: 当前pdf_paths: $paths');
    
    if (paths.contains(path)) {
      print('DEBUG: 找到路径，准备移除');
      paths.remove(path);
      await prefs.setStringList('pdf_paths', paths);
      print('DEBUG: 路径已从pdf_paths中移除');
      
      // 同时移除相关的进度记录
      await prefs.remove('progress_$path');
      print('DEBUG: 相关进度记录已移除');
    } else {
      print('DEBUG: 路径不在pdf_paths中');
    }
  }
  
  // 显示书籍详情
  void _showBookDetails(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return BookDetailSheet(
            book: book,
            scrollController: scrollController,
            isDownloaded: _downloadedBooks.containsKey(book.id),
            isDownloading: _downloadingBooks[book.id] == true,
            downloadProgress: _downloadProgress[book.id] ?? 0.0,
            onDownload: () => _downloadBook(book),
            onOpen: () => _openDownloadedBook(book),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        // appBar: AppBar(
        //   title: const Text('在线书库', style: TextStyle(color: Color(0xFF2D3A3A))),
        //   backgroundColor: Colors.white,
        //   elevation: 0,
        //   iconTheme: const IconThemeData(color: Color(0xFF2D3A3A)),
        //   actions: [
        //     IconButton(
        //       icon: const Icon(Icons.refresh),
        //       onPressed: _loadBooks,
        //     ),
        //   ],
        // ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        // appBar: AppBar(
        //   title: const Text('在线书库', style: TextStyle(color: Color(0xFF2D3A3A))),
        //   backgroundColor: Colors.white,
        //   elevation: 0,
        //   iconTheme: const IconThemeData(color: Color(0xFF2D3A3A)),
        //   actions: [
        //     IconButton(
        //       icon: const Icon(Icons.refresh),
        //       onPressed: _loadBooks,
        //     ),
        //   ],
        // ),
        body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadBooks,
                child: const Text('重试'),
                        ),
                      ],
                    ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   title: const Text('在线书库', style: TextStyle(color: Color(0xFF2D3A3A))),
      //   backgroundColor: Colors.white,
      //   elevation: 0,
      //   iconTheme: const IconThemeData(color: Color(0xFF2D3A3A)),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: _loadBooks,
      //     ),
      //   ],
      // ),
      body: _books.isEmpty
          ? const Center(
              child: Text(
                '没有可用的书籍',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
            padding: const EdgeInsets.all(16),
              itemCount: _books.length,
            itemBuilder: (context, index) {
                final book = _books[index];
                final isDownloaded = _downloadedBooks.containsKey(book.id);
                final isDownloading = _downloadingBooks[book.id] == true;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showBookDetails(book),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 书籍封面
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: book.coverUrl,
                              width: 80,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 80,
                                height: 120,
                          color: Colors.grey[300],
                                child: const Icon(
                                  Icons.book,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 书籍信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.author,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  book.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                    decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        book.format.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(book.size / 1024 / 1024).toStringAsFixed(1)}MB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isDownloaded)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.book, size: 16),
                                        label: const Text('阅读'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2D3A3A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 0,
                                          ),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        onPressed: () => _openDownloadedBook(book),
                                      )
                                    else if (isDownloading)
                                      SizedBox(
                                        width: 80,
                                        height: 32,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: _downloadProgress[book.id],
                                              strokeWidth: 2,
                                            ),
                                            Text(
                                              '${((_downloadProgress[book.id] ?? 0) * 100).toInt()}%',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('下载'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2D3A3A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 0,
                                          ),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        onPressed: () => _downloadBook(book),
                                      ),
                                  ],
                                ),
                              ],
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class BookDetailSheet extends StatelessWidget {
  final Book book;
  final ScrollController scrollController;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  const BookDetailSheet({
    super.key,
    required this.book,
    required this.scrollController,
    required this.isDownloaded,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // 书籍标题和作者
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 书籍封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: book.coverUrl,
                  width: 120,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              
              // 书籍信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            book.format.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(book.size / 1024 / 1024).toStringAsFixed(1)}MB',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '上传日期: ${book.uploadDate}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 下载/阅读按钮
          SizedBox(
            width: double.infinity,
            child: isDownloaded
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.book),
                    label: const Text('开始阅读'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D3A3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onOpen,
                  )
                : isDownloading
                    ? ElevatedButton.icon(
                        icon: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        label: Text('下载中 ${(downloadProgress * 100).toInt()}%'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: null,
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('下载'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3A3A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: onDownload,
                      ),
          ),
          
          const SizedBox(height: 24),
          
          // 书籍简介
          const Text(
            '内容简介',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Text(
                book.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
          ),
        ),
      ],
      ),
    );
  }
} 