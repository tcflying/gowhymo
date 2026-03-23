import 'package:gowhymo/models/focus_session.dart';

/// 专注学习奖励计算结果
class FocusRewardResult {
  final int baseReward;           // 底薪
  final int timeBonus;            // 时间提成
  final double qualityMultiplier; // 质量系数
  final int qualityAdjustedReward; // 质量调整后的奖励
  final bool isAccurateEstimate;  // 是否准确预估
  final int prophetBonus;         // 预言家奖励
  final int overtimePenalty;      // 超时惩罚
  final int finalReward;          // 最终奖励
  final String calculationDetail; // 计算详情说明

  const FocusRewardResult({
    required this.baseReward,
    required this.timeBonus,
    required this.qualityMultiplier,
    required this.qualityAdjustedReward,
    required this.isAccurateEstimate,
    required this.prophetBonus,
    required this.overtimePenalty,
    required this.finalReward,
    required this.calculationDetail,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseReward': baseReward,
      'timeBonus': timeBonus,
      'qualityMultiplier': qualityMultiplier,
      'qualityAdjustedReward': qualityAdjustedReward,
      'isAccurateEstimate': isAccurateEstimate,
      'prophetBonus': prophetBonus,
      'overtimePenalty': overtimePenalty,
      'finalReward': finalReward,
      'calculationDetail': calculationDetail,
    };
  }
}

/// 专注学习奖励计算器
/// 实现"底薪+提成+质量系数"的奖励算法
class FocusRewardCalculator {

  /// 计算专注学习奖励
  ///
  /// 参数:
  /// - [estimatedMinutes]: 预估时间（分钟）
  /// - [actualMinutes]: 实际用时（分钟）
  /// - [quality]: 完成质量
  ///
  /// 返回: [FocusRewardResult] 包含详细的奖励计算结果
  static FocusRewardResult calculate({
    required int estimatedMinutes,
    required int actualMinutes,
    required FocusQuality quality,
  }) {
    // 1. 计算底薪（预估时间的一半）
    final baseReward = (estimatedMinutes * RewardCalculationConfig.baseRewardRatio).round();

    // 2. 计算时间提成和超时惩罚
    int timeBonus = 0;
    int overtimePenalty = 0;
    bool isEarlyCompletion = actualMinutes < estimatedMinutes;
    bool isOvertime = actualMinutes > estimatedMinutes;

    if (isEarlyCompletion) {
      // 提早完成：获得节约时间的提成
      final savedMinutes = estimatedMinutes - actualMinutes;
      timeBonus = (savedMinutes * RewardCalculationConfig.timeBonusRatio).round();
    } else if (isOvertime) {
      // 超时：扣除底薪
      final overtimeMinutes = actualMinutes - estimatedMinutes;
      if (overtimeMinutes <= RewardCalculationConfig.overtimePenaltyMaxMinutes) {
        // 超时1-5分钟：每分钟扣1星
        overtimePenalty = overtimeMinutes * RewardCalculationConfig.overtimePenaltyPerMinute;
      } else {
        // 超时5分钟以上：底薪清零，给辛苦费
        overtimePenalty = baseReward - RewardCalculationConfig.overtimeCompletionReward;
      }
    }

    // 3. 获取质量系数
    final qualityMultiplier = QualityMultiplierConfig.getMultiplier(quality);

    // 4. 计算质量调整前的奖励
    final preQualityReward = baseReward + timeBonus - overtimePenalty;

    // 5. 应用质量系数
    final qualityAdjustedReward = (preQualityReward * qualityMultiplier).round();

    // 6. 检查预估准确度（±10%范围内）
    final accuracyRatio = (actualMinutes - estimatedMinutes).abs() / estimatedMinutes;
    final isAccurateEstimate = accuracyRatio <= RewardCalculationConfig.prophetAccuracyThreshold;
    final prophetBonus = isAccurateEstimate ? RewardCalculationConfig.prophetBonusAmount : 0;

    // 7. 计算最终奖励
    int finalReward = qualityAdjustedReward + prophetBonus;

    // 确保奖励不为负（最低为0）
    finalReward = finalReward < 0 ? 0 : finalReward;

    // 8. 生成计算详情说明
    final calculationDetail = _generateCalculationDetail(
      estimatedMinutes: estimatedMinutes,
      actualMinutes: actualMinutes,
      quality: quality,
      baseReward: baseReward,
      timeBonus: timeBonus,
      overtimePenalty: overtimePenalty,
      qualityMultiplier: qualityMultiplier,
      qualityAdjustedReward: qualityAdjustedReward,
      isAccurateEstimate: isAccurateEstimate,
      prophetBonus: prophetBonus,
      finalReward: finalReward,
    );

    return FocusRewardResult(
      baseReward: baseReward,
      timeBonus: timeBonus,
      qualityMultiplier: qualityMultiplier,
      qualityAdjustedReward: qualityAdjustedReward,
      isAccurateEstimate: isAccurateEstimate,
      prophetBonus: prophetBonus,
      overtimePenalty: overtimePenalty,
      finalReward: finalReward,
      calculationDetail: calculationDetail,
    );
  }

  /// 生成计算详情说明
  static String _generateCalculationDetail({
    required int estimatedMinutes,
    required int actualMinutes,
    required FocusQuality quality,
    required int baseReward,
    required int timeBonus,
    required int overtimePenalty,
    required double qualityMultiplier,
    required int qualityAdjustedReward,
    required bool isAccurateEstimate,
    required int prophetBonus,
    required int finalReward,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('📊 奖励计算详情');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('预估时间: $estimatedMinutes 分钟');
    buffer.writeln('实际用时: $actualMinutes 分钟');
    buffer.writeln('完成质量: ${QualityMultiplierConfig.getDescription(quality)}');
    buffer.writeln('');
    buffer.writeln('💰 底薪奖励: $baseReward 星');
    buffer.writeln('   (${estimatedMinutes} × ${(RewardCalculationConfig.baseRewardRatio * 100).round()}%)');
    buffer.writeln('');

    if (timeBonus > 0) {
      final savedMinutes = estimatedMinutes - actualMinutes;
      buffer.writeln('⚡ 时间提成: +$timeBonus 星');
      buffer.writeln('   (节约 ${savedMinutes}分钟 × ${RewardCalculationConfig.timeBonusRatio})');
      buffer.writeln('');
    }

    if (overtimePenalty > 0) {
      final overtimeMinutes = actualMinutes - estimatedMinutes;
      if (overtimeMinutes <= RewardCalculationConfig.overtimePenaltyMaxMinutes) {
        buffer.writeln('⏰ 超时惩罚: -$overtimePenalty 星');
        buffer.writeln('   (超时 ${overtimeMinutes}分钟 × ${RewardCalculationConfig.overtimePenaltyPerMinute})');
      } else {
        buffer.writeln('⏰ 超时惩罚: 底薪清零');
        buffer.writeln('   (超时 ${overtimeMinutes}分钟 > ${RewardCalculationConfig.overtimePenaltyMaxMinutes}分钟)');
        buffer.writeln('   辛苦费: ${RewardCalculationConfig.overtimeCompletionReward} 星');
      }
      buffer.writeln('');
    }

    buffer.writeln('🎯 质量系数: ${(qualityMultiplier * 100).round()}%');
    buffer.writeln('   (${baseReward + timeBonus - overtimePenalty} × ${qualityMultiplier})');
    buffer.writeln('   = $qualityAdjustedReward 星');
    buffer.writeln('');

    if (isAccurateEstimate) {
      buffer.writeln('🔮 预言家奖励: +$prophetBonus 星');
      buffer.writeln('   (预估准确度在±10%内)');
      buffer.writeln('');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🌟 最终奖励: $finalReward 星');

    return buffer.toString();
  }

  /// 验证预估时间是否合理
  /// 用于防止孩子虚报过高的预估时间
  static String? validateEstimatedMinutes(int minutes) {
    if (minutes < RewardCalculationConfig.minEstimatedMinutes) {
      return '预估时间不能少于 ${RewardCalculationConfig.minEstimatedMinutes} 分钟';
    }
    if (minutes > RewardCalculationConfig.maxEstimatedMinutes) {
      return '预估时间不能超过 ${RewardCalculationConfig.maxEstimatedMinutes} 分钟';
    }
    return null;
  }

  /// 获取建议的预估时间范围
  /// 基于历史数据给出建议
  static Map<String, int> getSuggestedTimeRange(String content, List<FocusSession> history) {
    // 过滤相同内容的历史记录
    final similarSessions = history.where(
      (s) => s.content.toLowerCase().contains(content.toLowerCase()) &&
             s.actualMinutes != null &&
             s.status == FocusSessionStatus.completed,
    ).toList();

    if (similarSessions.isEmpty) {
      return {'min': 10, 'suggested': 20, 'max': 45};
    }

    // 计算平均用时
    final actualTimes = similarSessions.map((s) => s.actualMinutes!).toList();
    actualTimes.sort();

    final avg = actualTimes.reduce((a, b) => a + b) ~/ actualTimes.length;
    final min = actualTimes.first;
    final max = actualTimes.last;

    return {
      'min': min,
      'suggested': avg,
      'max': max,
    };
  }
}

/// 奖励计算示例
class FocusRewardExamples {
  /// 示例1：提早完成 + 优秀质量
  static FocusRewardResult exampleEarlyCompletion() {
    return FocusRewardCalculator.calculate(
      estimatedMinutes: 20,
      actualMinutes: 12,
      quality: FocusQuality.excellent,
    );
  }

  /// 示例2：准时完成 + 良好质量
  static FocusRewardResult exampleOnTime() {
    return FocusRewardCalculator.calculate(
      estimatedMinutes: 20,
      actualMinutes: 20,
      quality: FocusQuality.good,
    );
  }

  /// 示例3：轻微超时 + 合格质量
  static FocusRewardResult exampleSlightOvertime() {
    return FocusRewardCalculator.calculate(
      estimatedMinutes: 20,
      actualMinutes: 23,
      quality: FocusQuality.fair,
    );
  }

  /// 示例4：严重超时 + 优秀质量
  static FocusRewardResult exampleSevereOvertime() {
    return FocusRewardCalculator.calculate(
      estimatedMinutes: 20,
      actualMinutes: 30,
      quality: FocusQuality.excellent,
    );
  }

  /// 示例5：准确预估（预言家奖励）
  static FocusRewardResult exampleAccurateEstimate() {
    return FocusRewardCalculator.calculate(
      estimatedMinutes: 20,
      actualMinutes: 19, // 在±10%范围内
      quality: FocusQuality.good,
    );
  }

  /// 打印所有示例
  static void printAllExamples() {
    final examples = [
      ('提早完成+优秀', exampleEarlyCompletion()),
      ('准时完成+良好', exampleOnTime()),
      ('轻微超时+合格', exampleSlightOvertime()),
      ('严重超时+优秀', exampleSevereOvertime()),
      ('准确预估', exampleAccurateEstimate()),
    ];

    for (final (name, result) in examples) {
      print('\n${'=' * 40}');
      print('示例: $name');
      print('${'=' * 40}');
      print(result.calculationDetail);
    }
  }
}
