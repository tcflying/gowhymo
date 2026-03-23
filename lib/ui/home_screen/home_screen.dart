import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/ui/home_screen/feedback_tab/feedback_tab.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/kid_tab.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/plan_tab.dart';
// import 'package:gowhymo/ui/home_screen/kid_tab/kid_tab.dart.bak';
// import 'package:gowhymo/ui/home_screen/plan_tab/plan_tab.dart.bak';
import 'package:gowhymo/ui/update_dialog.dart';
import 'package:gowhymo/providers/settings_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // log("homescreen build", name: 'ui/home_screen/home_screen.dart');
    ref.watch(userNotifierProvider.future).then((value) {
      if (value != null) {}
    });

    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final kidsAsync = ref.watch(kidListProvider);
    return kidsAsync.when(
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) {
        log(
          "homescreen get kidsAsync err:${err.toString()}",
          name: 'ui/home_screen/home_screen.dart',
        );
        return Scaffold(body: Center(child: Text('homeScreen:$err')));
      },
      data: (kids) {
        // log("kids.length:${kids.length}", name: 'ui/home_screen/home_screen.dart');
        // log("homescreen inner consummer build", name: 'ui/home_screen/home_screen.dart');
        final tabs = <Widget>[
          const KidTab(),
          PlanTab(kids),
          const FeedbackTab(),
        ];
        return Scaffold(
          body: tabs[selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) async {
              await ref.read(selectedTabIndexProvider.notifier).select(index);
              final updateState = ref.read(updateStateProvider);
              if (updateState.hasNewAppUpdate) {
                if (updateState.isUpdateRequired) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: !updateState.isUpdateRequired,
                      builder: (context) => const UpdateDialog(),
                    );
                  }
                } else if (ref.read(wantUpdateNowProvider)) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: !updateState.isUpdateRequired,
                      builder: (context) => const UpdateDialog(),
                    );
                  }
                }
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: '孩子',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: '计划',
              ),
              NavigationDestination(
                icon: Icon(Icons.extension_outlined),
                selectedIcon: Icon(Icons.extension),
                label: '功能',
              ),
              NavigationDestination(
                icon: Icon(Icons.feedback_outlined),
                selectedIcon: Icon(Icons.feedback),
                label: '交互',
              ),
            ],
          ),
        );
      },
    );
  }
}
