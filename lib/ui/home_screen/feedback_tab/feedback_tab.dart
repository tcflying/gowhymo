import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gowhymo/db/lib.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedbackTab extends ConsumerWidget {
  const FeedbackTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('test')),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // log('SharedPreferences 已清空');
              },
              child: const Text('清除prefs'),
            ),
            ElevatedButton(
              onPressed: () async {
                await closeDatabase();
                await delDatabase();
              },
              child: const Text('清除数据库用户'),
            ),
            ElevatedButton(
              onPressed: () async {
                
              },
              child: const Text('重启app'),
            ),
          ],
        ),
      ),
    );
  }
}
