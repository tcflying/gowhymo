import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/db/user.dart';
import 'package:gowhymo/ui/lib.dart';
import 'package:gowhymo/providers/settings_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nickname = _nicknameController.text.trim();
      await createOrUpdateUser(nickname);
      ref.read(userNotifierProvider.notifier).refreshUser();
      if (mounted) {
        // 注册成功后跳转到主页
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('注册失败，请重试');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // 获取键盘高度
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true, // 自动调整底部内边距避免键盘遮挡
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0).copyWith(
              bottom: 24.0 + bottomPadding, // 动态调整底部padding
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 应用图标或 Logo - 使用主题色
                    Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primaryContainer,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.7),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/gowhymo.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      '没有孩子他妈，我们也能带好',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // 注册表单 - 移除白色卡片，直接显示
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 昵称输入框 - 暗色调风格
                          TextFormField(
                            controller: _nicknameController,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: '您的昵称',
                              hintText: '输入您的昵称',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: colorScheme.primary,
                                size: 28, // 增大图标尺寸适配大字体
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  inputBorderRadius,
                                ), // 减小圆角，更现代
                                borderSide: BorderSide(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 1, // 增加边框宽度
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  inputBorderRadius,
                                ),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 2, // 聚焦时更粗的边框
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 18, // 增大标签字体
                                fontWeight: FontWeight.w500,
                              ),
                              hintStyle: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 20, // 增大提示文字
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, // 增加水平内边距
                                vertical: 20, // 增加垂直内边距适配大字体
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入您的昵称';
                              }
                              if (value.trim().length < 2) {
                                return '昵称至少需要2个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 36), // 增加输入框与按钮间距
                          // 注册按钮 - 使用主题色，适配大字体输入框
                          SizedBox(
                            width: double.infinity, // 占满整行
                            height: 64, // 固定高度，与输入框协调
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    btnBorderRadius,
                                  ), // 与输入框圆角一致
                                ),
                                elevation: 12, // 更强的阴影
                                shadowColor: colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 28,
                                      width: 28,
                                      child: CircularProgressIndicator(
                                        color: colorScheme.onPrimary,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Text(
                                      '创建',
                                      style: TextStyle(
                                        fontSize: 22, // 增大字体
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2, // 增加字间距
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32), // 增加按钮与提示文字间距，确保足够空间
                          // 提示文字
                          Text(
                            '输入昵称即可开启带娃之旅',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 16, // 增大提示文字
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // 装饰性元素 - 科技感线条
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 1,
                          width: 80,
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.star, color: colorScheme.primary, size: 32),
                        const SizedBox(width: 16),
                        Container(
                          height: 1,
                          width: 80,
                          color: colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
