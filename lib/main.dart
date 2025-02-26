import 'package:flutter/material.dart';
import 'providers/theme_provider.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/all_books_screen.dart';
import 'screens/data_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        home: const MainScreen(),
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

  @override
  void initState() {
    super.initState();
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
              children: const [
                // 书架页面
                AllBooksScreen(),
                
                // 书桌页面
                BookshelfScreen(),
                
                // 数据页面
                DataScreen(),
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
