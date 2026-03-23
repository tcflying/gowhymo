import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/models/focus_session.dart';
import 'package:gowhymo/providers/focus_session_providers.dart';
import 'package:gowhymo/services/focus_reward_calculator.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/providers/kid_tab_providers.dart';

/// 专注学习计时器对话框
class FocusTimerDialog extends ConsumerStatefulWidget {
  final int kidId;
  final String? planId;
  final String? initialContent;

  const FocusTimerDialog({
    super.key,
    required this.kidId,
    this.planId,
    this.initialContent,
  });

  @override
  ConsumerState<FocusTimerDialog> createState() => _FocusTimerDialogState();
}

class _FocusTimerDialogState extends ConsumerState<FocusTimerDialog> {
  final _contentController = TextEditingController();
  final _estimatedMinutesController = TextEditingController();
  bool _showQualitySelection = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _contentController.text = widget.initialContent!;
    }
    _estimatedMinutesController.text = '20'; // 默认20分钟
  }

  @override
  void dispose() {
    _contentController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startSession() {
    final content = _contentController.text.trim();
    final estimatedMinutes = int.tryParse(_estimatedMinutesController.text) ?? 0;

    if (content.isEmpty) {
      setState(() => _errorMessage = '请输入学习内容');
      return;
    }

    final validationError = FocusRewardCalculator.validateEstimatedMinutes(estimatedMinutes);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() => _errorMessage = null);

    ref.read(currentFocusSessionProvider.notifier).startSession(
      kidId: widget.kidId,
      content: content,
      estimatedMinutes: estimatedMinutes,
      planId: widget.planId,
    );
  }

  void _completeSession(FocusQuality quality) async {
    try {
      final result = await ref.read(currentFocusSessionProvider.notifier).completeSession(quality);

      // 自动将奖励添加到孩子的时间星中
      if (result.finalReward > 0) {
        final currentTimeStars = ref.read(timeStarsProvider(widget.kidId));
        final newMetadata = <String, dynamic>{
          'timeStars': currentTimeStars + result.finalReward,
        };
        await updateKidMetadata(ref, widget.kidId, newMetadata);
      }

      if (mounted) {
        Navigator.pop(context);
        _showRewardDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('完成失败: $e')),
        );
      }
    }
  }

  void _showRewardDialog(FocusRewardResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('恭喜完成！'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '+${result.finalReward}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '已添加到时间星',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ExpansionTile(
                title: Text('查看计算详情'),
                leading: Icon(Icons.info_outline),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      result.calculationDetail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('太棒了！'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(currentFocusSessionProvider);
    final elapsedTimeAsync = ref.watch(elapsedTimeProvider);

    return AlertDialog(
      title: Text(currentSession == null ? '开始专注学习' : '专注学习中'),
      content: currentSession == null
          ? _buildStartForm()
          : elapsedTimeAsync.when(
              data: (elapsedSeconds) => _buildTimerView(currentSession, elapsedSeconds),
              loading: () => Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('计时器错误')),
            ),
      actions: currentSession == null
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消'),
              ),
              FilledButton(
                onPressed: _startSession,
                child: Text('开始'),
              ),
            ]
          : _buildTimerActions(currentSession),
    );
  }

  Widget _buildStartForm() {
    final estimatedMinutes = int.tryParse(_estimatedMinutesController.text) ?? 0;
    final previewResult = estimatedMinutes > 0
        ? FocusRewardCalculator.calculate(
            estimatedMinutes: estimatedMinutes,
            actualMinutes: estimatedMinutes,
            quality: FocusQuality.good,
          )
        : null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: '学习内容',
              hintText: '例如：数学作业第3页',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.book),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _estimatedMinutesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '预估时间（分钟）',
              hintText: '5-120分钟',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timer),
              helperText: '预估越准确，可能获得预言家奖励！',
            ),
            onChanged: (value) => setState(() {}),
          ),
          if (previewResult != null) ...[
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 奖励预览（准时完成+良好质量）',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('底薪: ${previewResult.baseReward} 星'),
                    if (previewResult.isAccurateEstimate)
                      Text('预言家奖励: +${previewResult.prophetBonus} 星'),
                    Text(
                      '预计获得: ${previewResult.finalReward} 星',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerView(FocusSession session, int elapsedSeconds) {
    final elapsedMinutes = (elapsedSeconds / 60).ceil();
    final remainingMinutes = session.estimatedMinutes - elapsedMinutes;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            session.content,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: remainingMinutes >= 0
                  ? Colors.green.withAlpha(30)
                  : Colors.red.withAlpha(30),
              border: Border.all(
                color: remainingMinutes >= 0 ? Colors.green : Colors.red,
                width: 4,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _formatDuration(elapsedSeconds),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  remainingMinutes >= 0
                      ? '剩余 $remainingMinutes 分钟'
                      : '超时 ${-remainingMinutes} 分钟',
                  style: TextStyle(
                    color: remainingMinutes >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text('预估时间: ${session.estimatedMinutes} 分钟'),
          if (_showQualitySelection) ...[
            SizedBox(height: 24),
            Text(
              '请选择完成质量：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildQualitySelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildQualitySelector() {
    final qualities = [
      (FocusQuality.excellent, Colors.green, Icons.star),
      (FocusQuality.good, Colors.blue, Icons.thumb_up),
      (FocusQuality.fair, Colors.orange, Icons.check_circle),
      (FocusQuality.poor, Colors.red, Icons.refresh),
    ];

    return Column(
      children: qualities.map((item) {
        final (quality, color, icon) = item;
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () => _completeSession(quality),
            icon: Icon(icon, color: color),
            label: Text(QualityMultiplierConfig.getDescription(quality)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              minimumSize: Size(double.infinity, 48),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildTimerActions(FocusSession session) {
    if (_showQualitySelection) {
      return [
        TextButton(
          onPressed: () => setState(() => _showQualitySelection = false),
          child: Text('返回'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('确认取消？'),
              content: Text('取消后将不会获得任何奖励'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('继续学习'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(currentFocusSessionProvider.notifier).cancelSession();
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('确认取消'),
                ),
              ],
            ),
          );
        },
        child: Text('取消', style: TextStyle(color: Colors.red)),
      ),
      FilledButton(
        onPressed: () => setState(() => _showQualitySelection = true),
        child: Text('完成'),
      ),
    ];
  }
}

/// 专注学习历史记录对话框
class FocusSessionHistoryDialog extends ConsumerWidget {
  final int kidId;

  const FocusSessionHistoryDialog({super.key, required this.kidId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(focusSessionHistoryProvider(kidId));

    return AlertDialog(
      title: Text('专注学习记录'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: sessionsAsync.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('加载失败: $err')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(child: Text('暂无专注学习记录'));
            }

            return ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(context, session);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, FocusSession session) {
    final isCompleted = session.status == FocusSessionStatus.completed;

    Color statusColor;
    String statusText;
    switch (session.status) {
      case FocusSessionStatus.completed:
        statusColor = Colors.green;
        statusText = '已完成';
      case FocusSessionStatus.cancelled:
        statusColor = Colors.grey;
        statusText = '已取消';
      case FocusSessionStatus.running:
        statusColor = Colors.blue;
        statusText = '进行中';
      case FocusSessionStatus.paused:
        statusColor = Colors.orange;
        statusText = '已暂停';
      default:
        statusColor = Colors.grey;
        statusText = '待开始';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(50),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.timer,
            color: statusColor,
          ),
        ),
        title: Text(session.content),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预估: ${session.estimatedMinutes}分钟'),
            if (session.actualMinutes != null)
              Text('实际: ${session.actualMinutes}分钟'),
            if (isCompleted && session.finalReward != null)
              Text(
                '获得 ${session.finalReward} 星',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Chip(
          label: Text(statusText),
          backgroundColor: statusColor.withAlpha(50),
          labelStyle: TextStyle(color: statusColor, fontSize: 12),
        ),
      ),
    );
  }
}
