import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/focus_session.dart';
import 'package:gowhymo/models/focus_session.dart';
import 'package:gowhymo/services/focus_reward_calculator.dart';
import 'package:uuid/uuid.dart';

/// 当前进行中的专注会话Provider
final currentFocusSessionProvider = NotifierProvider<CurrentFocusSessionNotifier, FocusSession?>(() {
  return CurrentFocusSessionNotifier();
});

class CurrentFocusSessionNotifier extends Notifier<FocusSession?> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  FocusSession? build() => null;

  /// 开始新的专注会话
  Future<void> startSession({
    required int kidId,
    required String content,
    required int estimatedMinutes,
    String? planId,
  }) async {
    // 检查是否已有进行中的会话
    final existingSession = await FocusSessionDao.getRunningSession(kidId);
    if (existingSession != null) {
      throw Exception('已有进行中的专注会话，请先完成或取消当前会话');
    }

    final now = DateTime.now();
    final session = FocusSession(
      id: const Uuid().v4(),
      kidId: kidId,
      planId: planId,
      content: content,
      estimatedMinutes: estimatedMinutes,
      startedAt: now,
      status: FocusSessionStatus.running,
      createdAt: now,
      updatedAt: now,
    );

    await FocusSessionDao.insert(session);
    this.state = session;
    _elapsedSeconds = 0;

    // 启动计时器
    _startTimer();

    log('专注会话开始: ${session.id}', name: 'focus_session_providers');
  }

  /// 暂停会话
  Future<void> pauseSession() async {
    if (state == null) return;

    _timer?.cancel();

    final updatedSession = state!.copyWith(
      status: FocusSessionStatus.paused,
      updatedAt: DateTime.now(),
    );

    await FocusSessionDao.update(updatedSession);
    this.state = updatedSession;

    log('专注会话暂停: ${state!.id}', name: 'focus_session_providers');
  }

  /// 恢复会话
  Future<void> resumeSession() async {
    if (state == null) return;

    final updatedSession = state!.copyWith(
      status: FocusSessionStatus.running,
      updatedAt: DateTime.now(),
    );

    await FocusSessionDao.update(updatedSession);
    this.state = updatedSession;

    _startTimer();

    log('专注会话恢复: ${state!.id}', name: 'focus_session_providers');
  }

  /// 完成会话
  Future<FocusRewardResult> completeSession(FocusQuality quality) async {
    if (state == null) throw Exception('没有进行中的会话');

    _timer?.cancel();

    final actualMinutes = (_elapsedSeconds / 60).ceil();

    // 计算奖励
    final rewardResult = FocusRewardCalculator.calculate(
      estimatedMinutes: state!.estimatedMinutes,
      actualMinutes: actualMinutes,
      quality: quality,
    );

    final now = DateTime.now();
    final completedSession = state!.copyWith(
      actualMinutes: actualMinutes,
      completedAt: now,
      quality: quality,
      status: FocusSessionStatus.completed,
      baseReward: rewardResult.baseReward,
      timeBonus: rewardResult.timeBonus,
      qualityMultiplier: rewardResult.qualityMultiplier,
      finalReward: rewardResult.finalReward,
      isAccurateEstimate: rewardResult.isAccurateEstimate,
      prophetBonus: rewardResult.prophetBonus,
      updatedAt: now,
    );

    await FocusSessionDao.update(completedSession);
    this.state = null;
    _elapsedSeconds = 0;

    log('专注会话完成: ${completedSession.id}, 奖励: ${rewardResult.finalReward}',
        name: 'focus_session_providers');

    return rewardResult;
  }

  /// 取消会话
  Future<void> cancelSession() async {
    if (state == null) return;

    _timer?.cancel();

    final cancelledSession = state!.copyWith(
      status: FocusSessionStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    await FocusSessionDao.update(cancelledSession);
    this.state = null;
    _elapsedSeconds = 0;

    log('专注会话取消: ${cancelledSession.id}', name: 'focus_session_providers');
  }

  /// 启动计时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
    });
  }

  /// 获取已用时间（秒）
  int get elapsedSeconds => _elapsedSeconds;

  /// 获取已用时间（分钟）
  int get elapsedMinutes => (_elapsedSeconds / 60).floor();
}

/// 已用时间流Provider
final elapsedTimeProvider = StreamProvider<int>((ref) {
  final session = ref.watch(currentFocusSessionProvider);
  if (session == null) return Stream.value(0);

  return Stream.periodic(const Duration(seconds: 1), (count) {
    final notifier = ref.read(currentFocusSessionProvider.notifier);
    return notifier.elapsedSeconds;
  });
});

/// 孩子的专注会话历史Provider
final focusSessionHistoryProvider = FutureProvider.family<List<FocusSession>, int>((ref, kidId) async {
  return await FocusSessionDao.getByKidId(kidId);
});

/// 今日专注会话Provider
final todayFocusSessionsProvider = FutureProvider.family<List<FocusSession>, int>((ref, kidId) async {
  return await FocusSessionDao.getTodayCompletedSessions(kidId);
});

/// 今日专注奖励总额Provider
final todayFocusRewardProvider = FutureProvider.family<int, int>((ref, kidId) async {
  return await FocusSessionDao.getTodayTotalReward(kidId);
});

/// 本周专注奖励总额Provider
final thisWeekFocusRewardProvider = FutureProvider.family<int, int>((ref, kidId) async {
  return await FocusSessionDao.getThisWeekTotalReward(kidId);
});

/// 专注会话统计Provider
final focusSessionStatisticsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, kidId) async {
  return await FocusSessionDao.getStatistics(kidId);
});

/// 预估时间建议Provider
final estimatedTimeSuggestionProvider = FutureProvider.family<Map<String, int>, EstimatedTimeSuggestionParams>((ref, params) async {
  final history = await FocusSessionDao.getHistoryForSuggestion(
    params.kidId,
    params.content,
  );

  return FocusRewardCalculator.getSuggestedTimeRange(params.content, history);
});

class EstimatedTimeSuggestionParams {
  final int kidId;
  final String content;

  const EstimatedTimeSuggestionParams({
    required this.kidId,
    required this.content,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EstimatedTimeSuggestionParams &&
        other.kidId == kidId &&
        other.content == content;
  }

  @override
  int get hashCode => kidId.hashCode ^ content.hashCode;
}

/// 预估时间验证Provider
final estimatedTimeValidationProvider = Provider.family<String?, int>((ref, minutes) {
  return FocusRewardCalculator.validateEstimatedMinutes(minutes);
});

/// 奖励预览Provider（用于在开始前预览可能的奖励）
final rewardPreviewProvider = Provider.family<FocusRewardResult?, RewardPreviewParams>((ref, params) {
  if (params.estimatedMinutes <= 0) return null;

  // 模拟几种可能的完成情况
  // 这里可以展示一个范围或平均预期
  return FocusRewardCalculator.calculate(
    estimatedMinutes: params.estimatedMinutes,
    actualMinutes: params.estimatedMinutes, // 假设准时完成
    quality: FocusQuality.good,
  );
});

class RewardPreviewParams {
  final int estimatedMinutes;

  const RewardPreviewParams({required this.estimatedMinutes});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RewardPreviewParams && other.estimatedMinutes == estimatedMinutes;
  }

  @override
  int get hashCode => estimatedMinutes.hashCode;
}

/// 专注会话状态管理Notifier（用于列表刷新）
final focusSessionListProvider = AsyncNotifierProvider.family<FocusSessionListNotifier, List<FocusSession>, int>(
  (kidId) => FocusSessionListNotifier(kidId),
);

class FocusSessionListNotifier extends AsyncNotifier<List<FocusSession>> {
  final int kidId;

  FocusSessionListNotifier(this.kidId);

  @override
  Future<List<FocusSession>> build() async {
    return await FocusSessionDao.getByKidId(kidId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<void> deleteSession(String sessionId) async {
    await FocusSessionDao.delete(sessionId);
    ref.invalidateSelf();
  }
}
