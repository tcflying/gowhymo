import 'dart:developer';

import 'package:chinese_lunar_calendar/chinese_lunar_calendar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/db/plan.dart';
import 'package:gowhymo/ui/home_screen/plan_tab/calendar_widget.dart';
import 'package:gowhymo/providers/settings_providers.dart';
import 'package:gowhymo/constants/app_constants.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final timeSlotsRangeProvider = NotifierProvider<TimeSlotsRangeNotifier, String>(
  () {
    return TimeSlotsRangeNotifier();
  },
);

class TimeSlotsRangeNotifier extends Notifier<String> {
  @override
  String build() => prefs.getString('timeSlotsRange') ?? '6:00-23:30';

  Future<void> updateTimeSlotsRange(String timeSlotsRange) async {
    if (state != timeSlotsRange) {
      state = timeSlotsRange;
      await prefs.setString('timeSlotsRange', timeSlotsRange);
    }
  }
}

final selectedTabIndexProvider =
    NotifierProvider<SelectedTabIndexNotifier, int>(() {
      return SelectedTabIndexNotifier();
    });

class SelectedTabIndexNotifier extends Notifier<int> {
  @override
  int build() => prefs.getInt('selectedTabIndex') ?? 0;

  Future<void> select(int index) async {
    state = index;
    if (index != 1) {
      await ref
          .read(themeModeProvider.notifier)
          .updateThemeMode(ThemeMode.dark);
    }
    await ref.read(isGreyModeProvider.notifier).updateGreyMode(false);
    await prefs.setInt('selectedTabIndex', index);
  }
}

final selectedKidIndexProvider =
    NotifierProvider<SelectedKidIndexNotifier, int>(() {
      return SelectedKidIndexNotifier();
    });

class SelectedKidIndexNotifier extends Notifier<int> {
  @override
  int build() => prefs.getInt('selectedKidIndex') ?? 0;

  Future<void> selectKidIndex(int index) async {
    if (index == state) return;
    state = index;
    await prefs.setInt('selectedKidIndex', index);

    if (index >= 0 && index < kidColors.length) {
      await ref.read(colorProvider.notifier).updateColor(kidColors[index]);
    } else {
      await ref.read(colorProvider.notifier).updateColor(Colors.redAccent);
    }
  }
}

final kidListProvider = AsyncNotifierProvider<KidListNotifier, List<Kid>>(
  () => KidListNotifier(),
);

class KidListNotifier extends AsyncNotifier<List<Kid>> {
  @override
  Future<List<Kid>> build() async {
    return _fetchKids();
  }

  Future<List<Kid>> _fetchKids() async {
    final kids = await KidDao.getAll();
    return kids;
  }

  Future<void> refreshKids() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchKids());
  }

  Future<void> addKid(Kid kid) async {
    state = const AsyncValue.loading();
    try {
      await KidDao.insertOrReplace(kid);
      await refreshKids();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateKid(String id, Kid kid) async {
    try {
      await KidDao.update(kid);
      state = AsyncData(
        state.value?.map((k) => k.id == kid.id ? kid : k).toList() ?? [],
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteKid(String id) async {
    state = const AsyncValue.loading();
    try {
      await KidDao.delete(int.parse(id));
      await refreshKids();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final timeStarsProvider = Provider.family<int?, int>((ref, kidId) {
  final kidsAsync = ref.watch(kidListProvider);
  if (kidsAsync is AsyncData<List<Kid>>) {
    try {
      final kid = kidsAsync.value.firstWhere((k) => k.id == kidId);
      return kid.metadata?['timeStars'];
    } catch (_) {
      return null;
    }
  }
  return null;
});

class TimeStarsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> updateTimeStars(int kidId, int newValue) async {
    final kidsAsync = ref.read(kidListProvider);
    if (kidsAsync is AsyncData<List<Kid>>) {
      final kids = kidsAsync.value;
      final kidIndex = kids.indexWhere((k) => k.id == kidId);
      if (kidIndex != -1) {
        final kid = kids[kidIndex];
        final newMetadata = Map<String, dynamic>.from(kid.metadata ?? {});
        newMetadata['timeStars'] = newValue;
        final updatedKid = kid.copyWith(metadata: newMetadata);
        await ref.read(kidListProvider.notifier).updateKid(
              kidId.toString(),
              updatedKid,
            );
      }
    }
  }
}

final timeStarsNotifierProvider =
    NotifierProvider<TimeStarsNotifier, void>(
  () => TimeStarsNotifier(),
);

class AppUpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    _fetchUpdateState();
    return UpdateState(
      newVersion: '',
      hasNewAppUpdate: false,
      isUpdateRequired: false,
      releaseNotes: '',
      downloadUrl: '',
    );
  }

  bool _isVersionGreater(String version1, String version2) {
    final v1 = version1.split('.').map(int.parse).toList();
    final v2 = version2.split('.').map(int.parse).toList();

    for (var i = 0; i < v1.length; i++) {
      if (v1[i] > v2[i]) return true;
      if (v1[i] < v2[i]) return false;
    }
    return false;
  }

  Future<Map<String, dynamic>> checkVersion() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$appServer/gowhymo/version',
        options: Options(
          headers: {'Authorization': 'Bearer is_app'},
          validateStatus: (status) => status! < 600,
        ),
      );
      log("version:${response.data}",name: 'providers/home_providers.dart');
      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to check version: ${e.message}');
    }
  }

  Future<bool> requestStoragePermission() async {
    final status = await ph.Permission.storage.request();
    return status.isGranted;
  }

  Future<void> _fetchUpdateState() async {
    try {
      final versionInfo = await checkVersion();
      final current = appVersion;
      final latest = versionInfo['latest_version'];
      final minRequired = versionInfo['min_required_version'];

      final updateState = UpdateState(
        newVersion: latest,
        hasNewAppUpdate: _isVersionGreater(latest, current),
        isUpdateRequired: _isVersionGreater(minRequired, current),
        releaseNotes: versionInfo['release_notes'] ?? '',
        downloadUrl: versionInfo['download_url'] ?? '',
      );

      state = updateState;
      log(
        '版本检查结果: $updateState',
        name: 'providers/home_providers.dart',
      );
    } catch (e, stackTrace) {
      log(
        '版本检查失败: $e',
        name: 'providers/home_providers.dart',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final wantUpdateNowProvider = NotifierProvider<WantUpdateNowNotifier, bool>(() {
  return WantUpdateNowNotifier();
});

class WantUpdateNowNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void updateWantUpdateNow(bool wantUpdateNow) {
    if (state != wantUpdateNow) {
      state = wantUpdateNow;
    }
  }
}

final updateStateProvider = NotifierProvider<AppUpdateNotifier, UpdateState>(
  () {
    return AppUpdateNotifier();
  },
);

@immutable
class UpdateState {
  final String newVersion;
  final bool hasNewAppUpdate;
  final bool isUpdateRequired;
  final String releaseNotes;
  final String downloadUrl;
  final bool isLoading;
  final String? error;

  const UpdateState({
    required this.newVersion,
    required this.hasNewAppUpdate,
    required this.isUpdateRequired,
    required this.releaseNotes,
    required this.downloadUrl,
    this.isLoading = false,
    this.error,
  });

  UpdateState copyWith({
    String? newVersion,
    bool? hasNewAppUpdate,
    bool? isUpdateRequired,
    String? releaseNotes,
    String? downloadUrl,
    bool? isLoading,
    String? error,
  }) {
    return UpdateState(
      newVersion: newVersion ?? this.newVersion,
      hasNewAppUpdate: hasNewAppUpdate ?? this.hasNewAppUpdate,
      isUpdateRequired: isUpdateRequired ?? this.isUpdateRequired,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final timeSlotsProvider = NotifierProvider<TimeSlotsNotifier, List<String>>(
  TimeSlotsNotifier.new,
);

class TimeSlotsNotifier extends Notifier<List<String>> {
  final ScrollController scrollController;
  TimeSlotsNotifier() : scrollController = ScrollController();
  late List<String> timeSlots;

  @override
  List<String> build() {
    final String range = ref.watch(timeSlotsRangeProvider)!;
    timeSlots = generateTimeSlots(range);
    return timeSlots;
  }

  List<String> generateTimeSlots(String range) {
    final parts = range.split('-');
    if (parts.length != 2) return [];

    final start = TimeOfDay(
      hour: int.parse(parts[0].split(':')[0]),
      minute: int.parse(parts[0].split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(parts[1].split(':')[0]),
      minute: int.parse(parts[1].split(':')[1]),
    );

    final slots = <String>[];
    var current = start;
    while (current.hour < end.hour ||
        (current.hour == end.hour && current.minute <= end.minute)) {
      slots.add(
        '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}',
      );
      current = TimeOfDay(
        hour: current.minute == 30 ? current.hour + 1 : current.hour,
        minute: current.minute == 30 ? 0 : 30,
      );
    }

    slots.add('');
    slots.add('');
    slots.add('');
    return slots;
  }

  void reset(double itemHeight) {
    final currentIndex = findCurrentTimeSlotIndex();
    final scrollPosition = currentIndex * itemHeight;
    scrollTo(scrollPosition);
  }

  void scrollTo(double offset) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  int findCurrentTimeSlotIndex() {
    final now = TimeOfDay.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (timeSlots.isEmpty) {
      return -1;
    }

    for (int i = 0; i < timeSlots.length; i++) {
      int comparison = timeSlots[i].compareTo(currentTime);
      if (comparison > 0) {
        return i - 1;
      } else if (comparison == 0) {
        return i;
      }
    }
    return timeSlots.length - 1;
  }
}

final planListProvider = AsyncNotifierProvider<PlanListNotifier, List<Plan>>(
  PlanListNotifier.new,
);

class PlanListNotifier extends AsyncNotifier<List<Plan>> {
  @override
  Future<List<Plan>> build() async {
    try {
      final date = ref.watch(calendarWeekStateProvider).selectedDate;
      final plans = await PlanDao.getByKidIdAndDate(101, date);
      return plans;
    } catch (e) {
      throw '获取计划失败: $e';
    }
  }

  Future<void> updatePlan(Plan updatedPlan) async {
    state = const AsyncValue.loading();
    try {
      await PlanDao.update(updatedPlan);

      state = await AsyncValue.guard(() async {
        final currentPlans = [...?state.value];
        final index = currentPlans.indexWhere(
          (p) => p.planId == updatedPlan.planId,
        );
        if (index != -1) {
          currentPlans[index] = updatedPlan;
        }
        return currentPlans;
      });
    } catch (e) {
      state = AsyncValue.error('更新失败: $e', StackTrace.current);
    }
  }

  Future<void> addPlan(Plan updatedPlan) async {
    state = const AsyncValue.loading();
    try {
      await PlanDao.insert(updatedPlan);

      state = await AsyncValue.guard(() async {
        final currentPlans = [...?state.value];
        currentPlans.add(updatedPlan);
        return currentPlans;
      });
    } catch (e) {
      state = AsyncValue.error('添加失败: $e', StackTrace.current);
    }
  }
}

final calendarWeekStateProvider =
    NotifierProvider<CalendarWeekNotifier, CalendarWeekState>(
      () => CalendarWeekNotifier(),
    );

class CalendarWeekNotifier extends Notifier<CalendarWeekState> {
  late final PageController pageController;

  @override
  CalendarWeekState build() {
    pageController = PageController(initialPage: 4);
    return _initialState();
  }

  static CalendarWeekState _initialState() {
    final now = DateTime.now();
    final thisWeekMonDay = now.subtract(Duration(days: now.weekday % 7));
    final dates = _generateWeekDates(thisWeekMonDay);
    final title = _getMonthRangeText(dates);
    return CalendarWeekState(
      now,
      _generateWeekDates(thisWeekMonDay),
      title,
      now,
    );
  }

  static String _getMonthRangeText(List<CalendarDate> weekDates) {
    final firstMonth = weekDates.first.date.month;
    final lastMonth = weekDates.last.date.month;
    final year = weekDates.first.date.year;

    if (firstMonth == lastMonth) {
      return '$year年$firstMonth月';
    } else {
      return '$year年$firstMonth月-$lastMonth月';
    }
  }

  static List<CalendarDate> _generateWeekDates(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday % 7));
    final weekDates = List.generate(
      7,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    return weekDates.map((day) {
      final lunar = LunarDate.fromDateTime(localTime: day);

      final isToday =
          day.day == DateTime.now().day &&
          day.month == DateTime.now().month &&
          day.year == DateTime.now().year;

      String lunarText = lunar.lunarDay.toString();

      if (lunar.lunarDay == 1) {
        lunarText = '${chineseMonth[lunar.lunarMonth.number]}月';
      } else {
        lunarText = chineseDay[lunar.lunarDay];
      }

      return CalendarDate(day.day, lunarText, isToday, day);
    }).toList();
  }

  Future<void> selected(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    final now = DateTime.now();
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.day;
    final isFuture = date.isAfter(now);

    if (isToday) {
      await ref
          .read(themeModeProvider.notifier)
          .updateThemeMode(ThemeMode.dark);
      await ref.read(isGreyModeProvider.notifier).updateGreyMode(false);
    } else if (isFuture) {
      await ref
          .read(themeModeProvider.notifier)
          .updateThemeMode(ThemeMode.light);
      await ref.read(isGreyModeProvider.notifier).updateGreyMode(false);
    } else {
      await ref
          .read(themeModeProvider.notifier)
          .updateThemeMode(ThemeMode.dark);
      await ref.read(isGreyModeProvider.notifier).updateGreyMode(true);
    }
  }

  Future<void> reset() async {
    if (pageController.hasClients) {
      await pageController.animateToPage(
        4,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    await selected(DateTime.now());
  }

  List<CalendarDate> getWeekDates(DateTime date) {
    return _generateWeekDates(date);
  }

  void updateWeek(DateTime targetDate) {
    final newWeekDates = _generateWeekDates(targetDate);
    final title = _getMonthRangeText(newWeekDates);
    state = state.copyWith(weekDates: newWeekDates, title: title);
  }
}
