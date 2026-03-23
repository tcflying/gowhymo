import 'dart:developer';
import 'package:chinese_lunar_calendar/chinese_lunar_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/planlist_widget.dart';
import 'package:gowhymo/ui/lib.dart';

const List<String> chineseMonth = [
  '',
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '十一',
  '十二',
];
const List<String> chineseDay = [
  '',
  '初一',
  '初二',
  '初三',
  '初四',
  '初五',
  '初六',
  '初七',
  '初八',
  '初九',
  '初十',
  '十一',
  '十二',
  '十三',
  '十四',
  '十五',
  '十六',
  '十七',
  '十八',
  '十九',
  '廿',
  '廿一',
  '廿二',
  '廿三',
  '廿四',
  '廿五',
  '廿六',
  '廿七',
  '廿八',
  '廿九',
  '卅',
];

class CalendarDate {
  final int day;
  final String lunar;
  final bool isToday;
  final DateTime date;

  CalendarDate(this.day, this.lunar, this.isToday, this.date);
}

//日历状态包含，选中的日期，和当前周的日组成，因为存在跨月跨年的情况
class CalendarWeekState {
  //提供给外部显示月份等信息，比如title
  final List<CalendarDate> weekDates;
  final DateTime selectedDate;
  final String title;
  final DateTime today;

  CalendarWeekState(this.selectedDate, this.weekDates, this.title, this.today);
  CalendarWeekState copyWith({
    DateTime? selectedDate,
    List<CalendarDate>? weekDates,
    String? title,
    DateTime? today,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return CalendarWeekState(
      selectedDate ?? this.selectedDate,
      weekDates ?? this.weekDates,
      title ?? this.title,
      today ?? this.today,
    );
  }
}

class CalendarWeekWidget extends ConsumerWidget {
  const CalendarWeekWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // log("calendarwiget build");
    final now = DateTime.now();
    final nowWeekDay = now.subtract(Duration(days: now.weekday % 7));
    // 使用上下文中的主题，而不是创建新主题
    final theme = Theme.of(context);
    return
    // FlutterLogo();
    SizedBox(
      height: 88,
      child: PageView.builder(
        controller: ref.read(calendarWeekStateProvider.notifier).pageController,
        onPageChanged: (index) {
          final targetDate = nowWeekDay.add(Duration(days: 7 * (index - 4)));
          ref
              .read(calendarWeekStateProvider.notifier)
              .updateWeek(targetDate); // 触发周更新
        },
        itemCount: 9,
        itemBuilder: (context, index) {
          // 计算目标周日期 (index=4是当前周)
          final targetDate = nowWeekDay.add(Duration(days: 7 * (index - 4)));
          final weekDates = ref
              .read(calendarWeekStateProvider.notifier)
              .getWeekDates(targetDate);
          return Column(
            children: [
              // 星期标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  '日',
                  '一',
                  '二',
                  '三',
                  '四',
                  '五',
                  '六',
                ].map((day) => Text(day)).toList(),
              ),
              const SizedBox(height: 8),
              // 日期行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekDates.map((date) {
                  final calendarState = ref.watch(calendarWeekStateProvider);
                  final isSelected = date.date.isSameDate(
                    calendarState.selectedDate,
                  );
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(calendarWeekStateProvider.notifier)
                          .selected(date.date); // 触发选中更新
                    },
                    child: buildDayWithPlanLoading(
                      date,
                      theme,
                      isSelected,
                      ref,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget buildDay(bool isSelected, CalendarDate date, ThemeData theme) {
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
      border: date.isToday
          ? Border.all(color: theme.colorScheme.primary, width: 1)
          : null,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${date.day}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : date.isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          date.lunar,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : date.isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget buildDayWithPlanLoading(
  CalendarDate date,
  ThemeData theme,
  bool isSelected,
  WidgetRef ref,
) {
  if (isSelected) {
    final asyncPlans = ref.watch(planListProvider);
    return asyncPlans.when(
      data: (plans) => buildDay(isSelected, date, theme),
      loading: () => SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) {
        log('获取计划数据失败: $error');
        return buildDay(isSelected, date, theme);
      },
    );
  } else {
    return buildDay(isSelected, date, theme);
  }
}

extension DateTimeExtension on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
