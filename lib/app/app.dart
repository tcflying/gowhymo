import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gowhymo/providers/settings_providers.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(isGreyModeProvider);
    ref.read(colorProvider);
    ref.read(themeModeProvider);

    final userAsync = ref.watch(userNotifierProvider);

    return userAsync.when(
      data: (user) {
        final router = ref.read(routeProvider);
        return MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
          ],
          locale: const Locale('zh'),
          theme: ref.watch(themeDataProvider),
        );
      },
      error: (error, stackTrace) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('应用初始化失败,请重新关闭后再运行: $error'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          locale: const Locale('zh'),
          theme: ref.watch(themeDataProvider),
        );
      },
      loading: () {
        return MaterialApp(
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          locale: const Locale('zh'),
          theme: ref.watch(themeDataProvider),
        );
      },
    );
  }
}
