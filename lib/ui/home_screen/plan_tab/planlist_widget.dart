
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/db/plan.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/slot_edit_dialog.dart';


class SlotWidget extends ConsumerWidget {
  final String slotName;
  final bool isNow;
  final int index;

  const SlotWidget({
    super.key,
    required this.index,
    required this.slotName,
    required this.isNow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 直接在build中查询，避免额外的provider
    final plan = ref.watch(
      planListProvider.select<Plan?>((state) {
        return state.when<Plan?>(
          data: (plans) {
            if (plans.isEmpty) return null;
            try {
              return plans.firstWhere((p) => p.slotName == slotName);
            } catch (e) {
              return null;
            }
          },
          loading: () => null,
          error: (_, __) => null,
        );
      }),
    );

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => SlotEditDialog(plan, slotName),
        );
      },
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          side: isNow
              ? BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1,
                ) // 当前时间槽的边框
              : BorderSide.none, // 非当前时间槽无边框
          borderRadius: BorderRadius.circular(24),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(slotName, style: theme.textTheme.bodyMedium),
              const Spacer(), // 时间槽与计划内容之间的间距
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final content = plan?.content ?? '';
                    return Text(content, style: theme.textTheme.bodyMedium);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimeSlotsWidget extends ConsumerWidget {
  final double itemHeight;
  final int displayItemCount;

  const TimeSlotsWidget({
    super.key,
    required this.itemHeight,
    required this.displayItemCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeSlots = ref.watch(timeSlotsProvider);
    final notifier = ref.read(timeSlotsProvider.notifier);
    final currentIndex = notifier.findCurrentTimeSlotIndex();
    // final asyncPlansNotifier = ref.read(asyncPlansProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scrollPosition = currentIndex * itemHeight;
      notifier.scrollTo(scrollPosition);
    });

    return ListView.builder(
      controller: ref.read(timeSlotsProvider.notifier).scrollController,
      itemCount: timeSlots.length,
      itemExtent: itemHeight,
      itemBuilder: (context, index) {
        // 最后三个 item 使用空内容
        if (index >= timeSlots.length - 3) {
          return const SizedBox.shrink(); // 空容器，不占用空间但保持 itemExtent 高度
        }

        // 获取当前时间槽的时间字符串
        final slotName = timeSlots[index];

        return SlotWidget(
          index: index,
          slotName: slotName,
          isNow: currentIndex == index,
        );
      },
    );
  }
}

class TimeSlotsPageWidget extends ConsumerWidget {
  final double itemHeight;
  final int displayItemCount;
  final List<Kid> kidlist;
  final PageController controller;
  final PageController avatarController;
  const TimeSlotsPageWidget({
    super.key,
    required this.itemHeight,
    required this.kidlist,
    required this.displayItemCount,
    required this.controller,
    required this.avatarController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: kidlist.length,
      controller: controller,
      onPageChanged: (index) {
        ref.read(selectedKidIndexProvider.notifier).selectKidIndex(index);
        if (avatarController.hasClients) {
          avatarController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      itemBuilder: (context, index) {
        return TimeSlotsWidget(
          itemHeight: itemHeight,
          displayItemCount: displayItemCount,
        );
      },
    );
  }
}
