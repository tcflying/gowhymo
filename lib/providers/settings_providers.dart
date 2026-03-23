import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/db/user.dart';
import 'package:gowhymo/ui/home_screen/home_screen.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/add_kid.dart';
import 'package:gowhymo/ui/register_screen.dart';
import 'package:gowhymo/app/theme.dart';
import 'package:gowhymo/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences prefs;

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
    state = themeMode;
    await prefs.setBool('isDarkThemeMode', themeMode == ThemeMode.dark);
  }
}

final userNotifierProvider = AsyncNotifierProvider<UserNotifier, User?>(() {
  return UserNotifier();
});

class UserNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
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
      final userAsync = ref.watch(userNotifierProvider);

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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
});
