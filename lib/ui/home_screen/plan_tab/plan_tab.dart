import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/components/kid_avatar.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/calendar_widget.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/planlist_widget.dart';
import 'package:gowhymo/ui/lib.dart';

class PlanTab extends ConsumerStatefulWidget {
  const PlanTab(this.kids, {super.key});
  final List<Kid> kids;

  @override
  ConsumerState<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends ConsumerState<PlanTab> {
  late PageController appbarAvatarController;
  late PageController planlistController;
  @override
  void initState() {
    super.initState();
    appbarAvatarController = PageController(
      initialPage: ref.read(selectedKidIndexProvider),
    );
    planlistController = PageController(
      initialPage: ref.read(selectedKidIndexProvider),
    );
  }

  @override
  void dispose() {
    appbarAvatarController.dispose();
    planlistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kids.isEmpty) {
      return Scaffold(body: Center(child: Text('kid列表为空')));
    }
    final size = MediaQuery.sizeOf(context);
    final screenHeight = size.height;
    final appBarHeight = 192;
    final bottomNavigationBarHeight = 80;
    final displayItemCount = 4;
    final availableHeight =
        screenHeight - appBarHeight - bottomNavigationBarHeight;
    final itemHeight = availableHeight / displayItemCount;

    // log("plantab build");

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leadingWidth: 80,
        leading: Consumer(
          builder: (context, ref, child) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: PageView.builder(
                scrollDirection: Axis.horizontal,
                controller: appbarAvatarController,
                itemCount: widget.kids.length,
                onPageChanged: (index) async {
                  await ref
                      .read(selectedKidIndexProvider.notifier)
                      .selectKidIndex(index);
                  if (planlistController.hasClients) {
                    planlistController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                itemBuilder: (context, index) {
                  final kid = widget.kids[index];
                  return GestureDetector(
                    onTap: () => {},
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: kidColors[index], width: 1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: getKidAvatar(kid, context),
                    ),
                  );
                },
              ),
            );
          },
        ),
        title: Consumer(
          builder: (context, ref, child) {
            return Text(ref.watch(calendarWeekStateProvider).title);
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Builder(
            builder: (context) {
              return CalendarWeekWidget();
            },
          ),
        ),
        actions: [IconButton(icon: Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          return TimeSlotsPageWidget(
            itemHeight: itemHeight,
            displayItemCount: displayItemCount,
            kidlist: widget.kids,
            controller: planlistController,
            avatarController: appbarAvatarController,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref.read(calendarWeekStateProvider.notifier).reset();
          ref.read(timeSlotsProvider.notifier).reset(itemHeight);
        },
        child: const Text('今'),
      ),
    );
  }
}
