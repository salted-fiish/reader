import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFirstLaunch = true;
  bool _isFromSettings = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 创建淡入/淡出动画
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // **启动淡入动画**
    _animationController.forward();

    // 检查是否从设置页面进入
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNavigationSource();
    });
  }

  void _checkNavigationSource() {
    // 检查是否是从设置页面进入
    final NavigatorState navigator = Navigator.of(context);
    _isFromSettings = navigator.canPop();

    if (!_isFromSettings) {
      // 检查是否是首次启动
      _checkFirstLaunch();

      // **2.5秒后触发淡出动画，并在动画结束后跳转**
      _navigationTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _startFadeOutAnimation();
        }
      });
    }
  }

  void _startFadeOutAnimation() {
    // **开始淡出动画**
    _animationController.reverse().then((_) {
      if (mounted) {
        // **动画完成后进行导航**
        Navigator.pushReplacementNamed(
          context, 
          _isFirstLaunch ? '/' : '/home',
        );
      }
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isFromSettings
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3A3A)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                '启动页面预览',
                style: TextStyle(color: Color(0xFF2D3A3A)),
              ),
            )
          : null,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // **使用图片替换原来的 Icon**
            // FadeTransition(
            //   opacity: _animation,
            //   child: Container(
            //     width: 120,
            //     height: 120,
            //     decoration: BoxDecoration(
            //       borderRadius: BorderRadius.circular(20),
            //     ),
            //     child: ClipRRect(
            //       borderRadius: BorderRadius.circular(20),
            //       child: Image.asset(
            //         'assets/icon.png', // 这里替换成你的图片路径
            //         fit: BoxFit.cover, // 让图片填充整个区域
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(height: 30),
            // **应用名称淡入+淡出**
            FadeTransition(
              opacity: _animation,
              child: const Text(
                '这可能是最优雅的阅读app',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3A3A),
                ),
              ),
            ),
            const SizedBox(height: 50),
            if (_isFromSettings) ...[
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  // **重播动画**
                  _animationController.reset();
                  _animationController.forward();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3A3A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('重播动画'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
