// 主题模式管理（UI层变量）
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/db/user.dart';
import 'package:gowhymo/ui/home_screen/home_screen.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/add_kid.dart';
import 'package:gowhymo/ui/lib.dart';
import 'package:gowhymo/ui/register_screen.dart';
import 'package:gowhymo/theme/app_theme.dart';
import 'package:gowhymo/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowhymo/providers/settings_providers.dart' show prefs;

final colorProvider = NotifierProvider<ColorNotifier, Color>(() {
  return ColorNotifier();
});

class ColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    final currentColor = kidColorStringMapColor[prefs.getString('themeColor') ??
        'redAccent']!;
    return currentColor;
  }

  Future<void> updateColor(Color newThemeColor) async {
    if (state != newThemeColor) {
      state = newThemeColor;
      await prefs.setString('themeColor', kidColorMapString[newThemeColor]!);
    }
  }
}

final isGreyModeProvider = NotifierProvider<IsGreyModeNotifier, bool>(() {
  return IsGreyModeNotifier();
});

class IsGreyModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return prefs.getBool('isGreyMode') ?? false;
  }

  Future<void> updateGreyMode(bool isGreyMode) async {
    if (state != isGreyMode) {
      state = isGreyMode;
      await prefs.setBool('isGreyMode', isGreyMode);
    }
  }
}

final themeDataProvider = NotifierProvider<ThemeDataNotifier, ThemeData>(
  ThemeDataNotifier.new,
);

class ThemeDataNotifier extends Notifier<ThemeData> {
  @override
  ThemeData build() {
    final isGrey = ref.watch(isGreyModeProvider);
    final themeColor = ref.watch(colorProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ThemeData(
      useMaterial3: true,
      inputDecorationTheme: inputDecorationTheme,
      colorScheme: isGrey
          ? darkGrayScheme
          : ColorScheme.fromSeed(
              seedColor: themeColor,
              brightness: themeMode == ThemeMode.dark
                  ? Brightness.dark
                  : Brightness.light,
            ),
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return prefs.getBool('isDarkThemeMode') ?? true
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    // if (state != themeMode) {
    // log('updateThemeMode: $themeMode', name: 'ui/setting_providers.dart');
    state = themeMode;
    await prefs.setBool('isDarkThemeMode', themeMode == ThemeMode.dark);
    // }
  }
}

// final tokenProvider = NotifierProvider<TokenNotifier, String?>(() {
//   return TokenNotifier();
// });

// class TokenNotifier extends Notifier<String?> {
//   @override
//   String? build() => prefs.getString('token');

//   Future<void> updateToken(String token) async {
//     if (state != token) {
//       state = token;
//       prefs.setString('token', token);
//     }
//   }
// }

// 用户状态管理
final userNotifierProvider = AsyncNotifierProvider<UserNotifier, User?>(() {
  return UserNotifier();
});

class UserNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // 使用AsyncValue.guard处理可能的异常
    return await AsyncValue.guard(
      () => UserDao.getByLastLoginAt(),
    ).then((value) => value.value);
  }

  Future<void> refreshUser() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => UserDao.getByLastLoginAt());
  }

  Future<void> setUser(User user) async {
    state = AsyncValue.data(user);
  }

  Future<void> clearUser() async {
    state = const AsyncValue.data(null);
  }
}

final routeProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isRegisterPage = state.uri.toString() == '/register';
      // 使用ref.watch获取当前用户状态，而不是全局变量my
      final userAsync = ref.watch(userNotifierProvider);

      // log(
      //   "isRegisterPage: $isRegisterPage, user: ${userAsync.value}",
      //   name: 'ui/setting_providers.dart',
      // );

      // 只有在用户数据加载完成且用户为null时才重定向到注册页面
      if (userAsync.hasValue && userAsync.value == null && !isRegisterPage) {
        return '/register';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/add_kid',
        builder: (context, state) => const AddKidScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // GoRoute(
      //   path: '/login',
      //   builder: (context, state) => const LoginScreen(),
      // ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      // 用户登录后更新 login_at

      // GoRoute(
      //   path: '/kid_info',

      //   builder: (context, state) => const KidInfoScreen(),
      // ),
    ],
  );
});
