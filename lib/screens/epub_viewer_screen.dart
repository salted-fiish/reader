import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:gbk_codec/gbk_codec.dart';

class EpubViewerScreen extends StatefulWidget {
  final String epubPath;
  final Function(double) onProgressChanged;

  const EpubViewerScreen({
    super.key, 
    required this.epubPath,
    required this.onProgressChanged,
  });

  @override
  State<EpubViewerScreen> createState() => _EpubViewerScreenState();
}

class _EpubViewerScreenState extends State<EpubViewerScreen> {
  late EpubParser _parser;
  bool _isLoading = true;
  int _currentChapter = 0;
  final ScrollController _scrollController = ScrollController();
  Map<int, double> _chapterScrollPositions = {};
  bool _showMenu = false;  // 添加菜单显示状态控制

  @override
  void initState() {
    super.initState();
    print("🚀 初始化EpubViewerScreen");
    _scrollController.addListener(_handleScroll);
    _loadEpub();
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      _chapterScrollPositions[_currentChapter] = _scrollController.offset;
      print("📜 滚动位置更新: 章节$_currentChapter, 位置: ${_scrollController.offset}");
      _savePosition();
    }
  }

  Future<void> _loadEpub() async {
    print("📚 开始加载EPUB: ${widget.epubPath}");
    _parser = EpubParser(widget.epubPath);
    await _parser.parse();

    if (mounted) {
      print("📖 EPUB解析完成，章节数量: ${_parser.chapters.length}");
      setState(() {
        _isLoading = false;
      });
      await _loadLastPosition();
    }
  }

  /// **📌 加载上次阅读位置**
  Future<void> _loadLastPosition() async {
    print("🔍 开始加载上次阅读位置");
    final prefs = await SharedPreferences.getInstance();
    final lastChapter = prefs.getInt('${widget.epubPath}_chapter') ?? 0;
    final scrollPositionsStr = prefs.getString('${widget.epubPath}_scroll_positions');
    
    print("💾 存储的章节位置: $lastChapter");
    print("💾 存储的滚动位置数据: $scrollPositionsStr");
    
    if (scrollPositionsStr != null) {
      try {
        final Map<String, dynamic> positions = json.decode(scrollPositionsStr);
        _chapterScrollPositions.clear();  // 清除旧数据
        positions.forEach((key, value) {
          _chapterScrollPositions[int.parse(key)] = (value as num).toDouble();
        });
        print("📍 解析的滚动位置Map: $_chapterScrollPositions");
      } catch (e, stackTrace) {
        print("⚠️ 解析滚动位置数据失败: $e");
        print("调用栈: $stackTrace");
      }
    }

    if (mounted) {
      setState(() {
        _currentChapter = lastChapter;
      });

      // 延长等待时间，确保HTML内容完全加载
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          print("📱 准备恢复滚动位置: $savedPosition");
          try {
            _scrollController.jumpTo(savedPosition);
            print("✅ 滚动位置恢复成功");
          } catch (e) {
            print("❌ 滚动位置恢复失败: $e");
          }
        } else {
          print("⚠️ ScrollController未就绪");
        }
      });
    }
  }

  /// **📌 保存阅读进度**
  Future<void> _savePosition() async {
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${widget.epubPath}_chapter', _currentChapter);
      
      if (_scrollController.hasClients) {
        // 将Map转换为可序列化的格式
        final Map<String, dynamic> serializableMap = {};
        _chapterScrollPositions.forEach((key, value) {
          serializableMap[key.toString()] = value;
        });
        
        final scrollPositionsStr = json.encode(serializableMap);
        await prefs.setString('${widget.epubPath}_scroll_positions', scrollPositionsStr);
        print("💾 保存进度成功 - 章节: $_currentChapter, 位置Map: $serializableMap");
      }
    } catch (e, stackTrace) {
      print("❌ 保存进度失败: $e");
      print("调用栈: $stackTrace");
    }
  }

  void _previousChapter() {
    if (_currentChapter > 0) {
      setState(() {
        _currentChapter--;
        widget.onProgressChanged(_currentChapter / _parser.chapters.length);
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          _scrollController.jumpTo(savedPosition);
        }
      });
    }
  }

  void _nextChapter() {
    if (_currentChapter < _parser.chapters.length - 1) {
      setState(() {
        _currentChapter++;
        widget.onProgressChanged(_currentChapter / _parser.chapters.length);
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final savedPosition = _chapterScrollPositions[_currentChapter] ?? 0.0;
          _scrollController.jumpTo(savedPosition);
        }
      });
    }
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_parser.chapters.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('无法加载电子书内容')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,  // 内容延伸到AppBar下方
      appBar: _showMenu ? AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.9),
        title: Text(_parser.chapters[_currentChapter].title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      body: GestureDetector(
        onTap: _toggleMenu,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Html(
            data: _parser.chapters[_currentChapter].content,
            style: {
              "body": Style(
                fontSize: FontSize(18),
              ),
            },
          ),
        ),
      ),
      bottomNavigationBar: _showMenu ? Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomAppBarTheme.color?.withOpacity(0.9),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: _showChapterList,
                  tooltip: '章节列表',
                ),
                Text(
                  '${_currentChapter + 1}/${_parser.chapters.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.menu_book),
                  onPressed: () {
                    // 这里可以添加其他阅读设置，比如字体大小、背景色等
                  },
                  tooltip: '阅读设置',
                ),
              ],
            ),
          ),
        ),
      ) : null,
    );
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _parser.chapters.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_parser.chapters[index].title),
            onTap: () {
              setState(() {
                _currentChapter = index;
                widget.onProgressChanged(_currentChapter / _parser.chapters.length);
              });
              _savePosition();
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _savePosition();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }
}

class EpubParser {
  final String epubPath;
  late Archive archive;
  late String contentOpfPath;
  List<EpubChapter> chapters = [];
  Map<String, String> _titleMap = {};

  EpubParser(this.epubPath);

  String _detectAndDecode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      try {
        return gbk.decode(bytes);
      } catch (e) {
        try {
          return latin1.decode(bytes);
        } catch (e) {
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
    }
  }

  Future<void> parse() async {
    try {
      final bytes = await File(epubPath).readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes);
      
      await _parseTocNcx();
      
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile != null) {
        final containerXml = _detectAndDecode(containerFile.content);
        final document = XmlDocument.parse(containerXml);
        contentOpfPath = document.findAllElements('rootfile')
            .first.getAttribute('full-path') ?? '';
      }

      final contentOpfFile = archive.findFile(contentOpfPath);
      if (contentOpfFile != null) {
        final contentOpf = _detectAndDecode(contentOpfFile.content);
        await _parseContentOpf(contentOpf);
      }
    } catch (e) {
      print('解析EPUB失败: $e');
    }
  }

  Future<void> _parseTocNcx() async {
    try {
      final tocFile = archive.findFile('OEBPS/toc.ncx') ?? 
                     archive.findFile('toc.ncx');
      
      if (tocFile != null) {
        final tocContent = _detectAndDecode(tocFile.content);
        final document = XmlDocument.parse(tocContent);
        
        for (final navPoint in document.findAllElements('navPoint')) {
          final contentSrc = navPoint.findElements('content').first.getAttribute('src') ?? '';
          final text = navPoint.findElements('text').first.text;
          if (contentSrc.isNotEmpty && text.isNotEmpty) {
            final href = contentSrc.split('#')[0];
            _titleMap[href] = text;
          }
        }
      }
    } catch (e) {
      print('解析目录失败: $e');
    }
  }

  Future<void> _parseContentOpf(String contentOpf) async {
    final document = XmlDocument.parse(contentOpf);
    final spine = document.findAllElements('spine').first;
    final manifest = document.findAllElements('manifest').first;

    for (final itemref in spine.findAllElements('itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref != null) {
        final manifestItem = manifest.findAllElements('item')
            .firstWhere((item) => item.getAttribute('id') == idref);
        
        final href = manifestItem.getAttribute('href') ?? '';
        final mediaType = manifestItem.getAttribute('media-type') ?? '';
        
        if (mediaType.contains('html')) {
          final chapterFile = archive.findFile(
            path.join(path.dirname(contentOpfPath), href)
          );
          
          if (chapterFile != null) {
            final content = _detectAndDecode(chapterFile.content);
            String title = _titleMap[href] ?? '';
            
            if (title.isEmpty) {
              try {
                final document = htmlparser.parse(content);
                final titleElement = document.querySelector('h1') ?? 
                                   document.querySelector('h2') ??
                                   document.querySelector('h3') ??
                                   document.querySelector('title');
                if (titleElement != null) {
                  title = titleElement.text.trim();
                }
              } catch (e) {
                print('解析章节标题失败: $e');
              }
            }
            
            if (title.isEmpty) {
              title = '第${chapters.length + 1}章';
            }
            
            chapters.add(EpubChapter(href, content, title));
          }
        }
      }
    }
  }
}

class EpubChapter {
  final String href;
  final String content;
  final String title;
  
  EpubChapter(this.href, this.content, this.title);
}
