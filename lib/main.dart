import 'package:flutter/material.dart';
import 'providers/theme_provider.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/all_books_screen.dart';
import 'screens/data_screen.dart';
import 'screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'utils/file_storage_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 如果是第一次启动，或者强制显示欢迎页
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    });
    
    // 设置为非首次启动
    if (_isFirstLaunch) {
      await prefs.setBool('first_launch', false);
    }
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      isDarkMode: _isDarkMode,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        title: '阅读器',
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2C2C2C),      // 主要颜色：深灰色
            secondary: Color(0xFF4A4A4A),    // 次要颜色：中灰色
            surface: Colors.white,            // 表面颜色：白色
            background: Color(0xFFF5F5F5),    // 背景色：浅灰色
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2C2C2C),  // 改回深灰色
            foregroundColor: Colors.white,       // 改回白色
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1A1A1A),
            secondary: Color(0xFF2C2C2C),
            surface: Color(0xFF121212),
            background: Color(0xFF000000),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF121212),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF2C2C2C),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        initialRoute: _isFirstLaunch ? '/' : '/home',
        routes: {
          '/': (context) => const WelcomeScreen(),
          '/home': (context) => const MainScreen(),
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 默认显示书桌页面
  final PageController _pageController = PageController(initialPage: 1);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 添加书籍路径和进度的状态
  List<String> _bookPaths = [];
  Map<String, double> _bookProgress = {};

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }
  
  // 加载书籍数据
  Future<void> _loadBookData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> paths = prefs.getStringList('pdf_paths') ?? [];
    Map<String, double> progress = {};
    
    // 验证文件是否存在并迁移到应用存储目录
    List<String> validPaths = [];
    bool needsUpdate = false;
    
    for (var path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        // 检查文件是否在应用永久存储目录中
        bool isInAppStorage = await FileStorageHelper.isFileInAppStorage(path);
        
        if (isInAppStorage) {
          // 如果已经在永久存储目录中，直接使用规范化的路径
          final normalizedPath = file.absolute.path;
          validPaths.add(normalizedPath);
          progress[normalizedPath] = prefs.getDouble('progress_$path') ?? 0.0;
          
          if (normalizedPath != path) {
            // 更新进度信息的键
            final oldProgress = prefs.getDouble('progress_$path') ?? 0.0;
            await prefs.setDouble('progress_$normalizedPath', oldProgress);
            needsUpdate = true;
          }
        } else {
          // 如果不在永久存储目录中，需要迁移
          try {
            // 获取文件名
            final fileName = path.split('/').last;
            
            // 生成唯一文件名
            final uniqueFileName = await FileStorageHelper.generateUniqueFileName(
              fileName, 
              validPaths // 使用已验证的路径列表
            );
            
            // 复制到永久存储
            final newPath = await FileStorageHelper.copyFileToAppStorage(
              file,
              customFileName: uniqueFileName
            );
            
            validPaths.add(newPath);
            
            // 迁移进度信息
            final oldProgress = prefs.getDouble('progress_$path') ?? 0.0;
            progress[newPath] = oldProgress;
            await prefs.setDouble('progress_$newPath', oldProgress);
            
            needsUpdate = true;
            debugPrint('文件已迁移到应用存储: $path -> $newPath');
          } catch (e) {
            debugPrint('迁移文件失败: $path, 错误: $e');
            // 如果迁移失败，仍然保留原路径
            validPaths.add(path);
            progress[path] = prefs.getDouble('progress_$path') ?? 0.0;
          }
        }
      }
    }
    
    // 如果有更新，保存新的路径列表
    if (needsUpdate || validPaths.length != paths.length) {
      await prefs.setStringList('pdf_paths', validPaths);
    }
    
    if (mounted) {
      setState(() {
        _bookPaths = validPaths;
        _bookProgress = progress;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // 页面切换时刷新数据
    _loadBookData();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Column(
        children: [
          // 顶部安全区域
          SizedBox(height: MediaQuery.of(context).padding.top),
          
          // 顶部导航栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 三横线菜单按钮
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    // 显示抽屉菜单
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                
                const Spacer(),
                
                // 紧凑型分段控制器
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(0, '书架'),
                      _buildTabButton(1, '书桌'),
                      _buildTabButton(2, '数据'),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // 为了对称添加一个占位
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // 页面内容
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                // 书架页面 - 传递共享的书籍数据
                AllBooksScreen(
                  bookPaths: _bookPaths,
                  bookProgress: _bookProgress,
                ),
                
                // 书桌页面
                const BookshelfScreen(),
                
                // 数据页面
                const DataScreen(),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                '阅读器',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('设置'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.brightness_6),
                          title: const Text('深色模式'),
                          trailing: Switch(
                            value: Theme.of(context).brightness == Brightness.dark,
                            onChanged: (value) {
                              Navigator.pop(context);
                              // 这里需要实现切换主题的功能
                            },
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.slideshow),
                          title: const Text('查看欢迎页'),
                          onTap: () async {
                            Navigator.pop(context); // 关闭设置对话框
                            Navigator.pop(context); // 关闭抽屉菜单
                            
                            // 导航到欢迎页
                            Navigator.pushNamed(context, '/');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('清除所有数据'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清除'),
                    content: const Text('这将删除所有书籍和阅读进度，确定要继续吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  // 刷新页面
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('所有数据已清除')),
                    );
                    // 重新加载页面
                    setState(() {
                      _currentIndex = 1; // 重置为书桌页面
                      _pageController.jumpToPage(1);
                    });
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('关于'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('关于阅读器'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('阅读器 v1.0.0'),
                        SizedBox(height: 8),
                        Text('一个简洁的多格式阅读应用'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        width: 70,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
