import 'dart:convert';

/// 专注学习会话质量评级
enum FocusQuality {
  excellent, // 优秀 - 全对、字迹工整
  good,      // 良好 - 基本正确
  fair,      // 合格 - 有错题需订正
  poor,      // 不合格 - 字迹潦草需重写
}

/// 专注学习会话状态
enum FocusSessionStatus {
  pending,    // 待开始
  running,    // 进行中
  paused,     // 已暂停
  completed,  // 已完成
  cancelled,  // 已取消
}

/// 专注学习会话模型
/// 用于记录孩子的专注学习过程和奖励计算
class FocusSession {
  final String id;
  final int kidId;
  final String? planId; // 关联的计划ID
  final String content; // 学习内容描述

  // 时间相关
  final int estimatedMinutes; // 预估时间（分钟）
  final int? actualMinutes;   // 实际用时（分钟）
  final DateTime? startedAt;
  final DateTime? completedAt;

  // 质量和状态
  final FocusQuality? quality;
  final FocusSessionStatus status;

  // 奖励计算结果
  final int? baseReward;      // 底薪奖励
  final int? timeBonus;       // 时间提成
  final double? qualityMultiplier; // 质量系数
  final int? finalReward;     // 最终奖励

  // 预言家奖励
  final bool? isAccurateEstimate; // 预估准确度是否在±10%内
  final int? prophetBonus;    // 预言家奖励

  final DateTime createdAt;
  final DateTime updatedAt;

  const FocusSession({
    required this.id,
    required this.kidId,
    this.planId,
    required this.content,
    required this.estimatedMinutes,
    this.actualMinutes,
    this.startedAt,
    this.completedAt,
    this.quality,
    this.status = FocusSessionStatus.pending,
    this.baseReward,
    this.timeBonus,
    this.qualityMultiplier,
    this.finalReward,
    this.isAccurateEstimate,
    this.prophetBonus,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON序列化
  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      kidId: json['kid_id'] as int,
      planId: json['plan_id'] as String?,
      content: json['content'] as String,
      estimatedMinutes: json['estimated_minutes'] as int,
      actualMinutes: json['actual_minutes'] as int?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      quality: json['quality'] != null
          ? FocusQuality.values.byName(json['quality'] as String)
          : null,
      status: FocusSessionStatus.values.byName(json['status'] as String),
      baseReward: json['base_reward'] as int?,
      timeBonus: json['time_bonus'] as int?,
      qualityMultiplier: json['quality_multiplier'] != null
          ? (json['quality_multiplier'] as num).toDouble()
          : null,
      finalReward: json['final_reward'] as int?,
      isAccurateEstimate: json['is_accurate_estimate'] as bool?,
      prophetBonus: json['prophet_bonus'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kid_id': kidId,
      'plan_id': planId,
      'content': content,
      'estimated_minutes': estimatedMinutes,
      'actual_minutes': actualMinutes,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'quality': quality?.name,
      'status': status.name,
      'base_reward': baseReward,
      'time_bonus': timeBonus,
      'quality_multiplier': qualityMultiplier,
      'final_reward': finalReward,
      'is_accurate_estimate': isAccurateEstimate,
      'prophet_bonus': prophetBonus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJsonString() => json.encode(toJson());

  factory FocusSession.fromJsonString(String jsonString) {
    return FocusSession.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  // copyWith方法
  FocusSession copyWith({
    String? id,
    int? kidId,
    String? planId,
    String? content,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? startedAt,
    DateTime? completedAt,
    FocusQuality? quality,
    FocusSessionStatus? status,
    int? baseReward,
    int? timeBonus,
    double? qualityMultiplier,
    int? finalReward,
    bool? isAccurateEstimate,
    int? prophetBonus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      kidId: kidId ?? this.kidId,
      planId: planId ?? this.planId,
      content: content ?? this.content,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      baseReward: baseReward ?? this.baseReward,
      timeBonus: timeBonus ?? this.timeBonus,
      qualityMultiplier: qualityMultiplier ?? this.qualityMultiplier,
      finalReward: finalReward ?? this.finalReward,
      isAccurateEstimate: isAccurateEstimate ?? this.isAccurateEstimate,
      prophetBonus: prophetBonus ?? this.prophetBonus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 质量系数配置
class QualityMultiplierConfig {
  static const double excellent = 1.2; // 优秀 - 奖励加成20%
  static const double good = 1.0;      // 良好 - 无加成
  static const double fair = 0.8;      // 合格 - 减少20%
  static const double poor = 0.0;      // 不合格 - 取消奖励

  static double getMultiplier(FocusQuality quality) {
    switch (quality) {
      case FocusQuality.excellent:
        return excellent;
      case FocusQuality.good:
        return good;
      case FocusQuality.fair:
        return fair;
      case FocusQuality.poor:
        return poor;
    }
  }

  static String getDescription(FocusQuality quality) {
    switch (quality) {
      case FocusQuality.excellent:
        return '优秀（全对、字迹工整）';
      case FocusQuality.good:
        return '良好（基本正确）';
      case FocusQuality.fair:
        return '合格（有错题需订正）';
      case FocusQuality.poor:
        return '不合格（字迹潦草需重写）';
    }
  }
}

/// 奖励计算配置
class RewardCalculationConfig {
  // 底薪比例：预估时间的一半
  static const double baseRewardRatio = 0.5;

  // 时间提成系数：节约时间的0.5倍
  static const double timeBonusRatio = 0.5;

  // 预言家奖励：预估准确度在±10%内
  static const double prophetAccuracyThreshold = 0.1;
  static const int prophetBonusAmount = 5;

  // 超时惩罚配置
  static const int overtimePenaltyStartMinutes = 1; // 超时1分钟开始扣
  static const int overtimePenaltyPerMinute = 1;    // 每分钟扣1星
  static const int overtimePenaltyMaxMinutes = 5;   // 最多扣5分钟
  static const int overtimeCompletionReward = 2;    // 超时完成辛苦费

  // 最大预估时间限制（防止虚报）
  static const int maxEstimatedMinutes = 120;
  static const int minEstimatedMinutes = 5;
}
