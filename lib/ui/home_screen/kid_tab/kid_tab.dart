import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/providers/home_providers.dart' as home_providers;
import 'package:gowhymo/ui/home_screen/kid_tab/components/counter_card.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/components/link_card.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/components/kid_avatar.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/components/focus_timer_dialog.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/providers/kid_tab_providers.dart';

// 奖励常量
class RewardConstants {
  static const int maxTimeMinutes = 120;
  static const int defaultIncrement = 1;
  static const int maxMoneyStars = 999;
  static const double avatarSizeRatio = 1/5;
  static const double avatarIconSizeRatio = 1/10;
}

// 获取当前选中的孩子
final selectedKidProvider = Provider<Kid?>((ref) {
  final kidsAsync = ref.watch(home_providers.kidListProvider);
  final selectedIndex = ref.watch(home_providers.selectedKidIndexProvider);
  if (kidsAsync is AsyncData<List<Kid>> && 
      selectedIndex >= 0 && 
      selectedIndex < kidsAsync.value.length) {
    return kidsAsync.value[selectedIndex];
  }
  return null;
});

class KidTab extends ConsumerWidget {
  const KidTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kidsAsync = ref.watch(home_providers.kidListProvider);
    return kidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(home_providers.kidListProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (kids) => _KidTabContent(kids: kids),
    );
  }
}

class _KidTabContent extends ConsumerStatefulWidget {
  const _KidTabContent({required this.kids});
  final List<Kid> kids;

  @override
  ConsumerState<_KidTabContent> createState() => _KidTabContentState();
}

class _KidTabContentState extends ConsumerState<_KidTabContent> {
  late PageController _pageController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(home_providers.selectedKidIndexProvider),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 更新孩子元数据的通用方法
  Future<void> _updateKidMetadata(
    WidgetRef ref,
    int kidId,
    String key,
    int currentValue,
    int increment,
    int maxValue,
  ) async {
    if (_isLoading) return;
    
    final newValue = currentValue + increment;
    if (newValue < 0 || newValue > maxValue) return;

    setState(() => _isLoading = true);
    try {
      final currentMetadata = ref.read(kidMetadataProvider(kidId)) ?? {};
      final newMetadata = Map<String, dynamic>.from(currentMetadata);
      newMetadata[key] = newValue;
      await updateKidMetadata(ref, kidId, newMetadata);
      
      // 显示成功反馈
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新成功'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kids = widget.kids;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    
    if (kids.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '还没有添加孩子',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: height * RewardConstants.avatarSizeRatio,
                height: height * RewardConstants.avatarSizeRatio,
                child: FloatingActionButton.large(
                  shape: const CircleBorder(),
                  heroTag: 'addKidFab',
                  onPressed: () {
                    context.push('/add_kid');
                  },
                  child: Icon(
                    Icons.person_add,
                    color: Colors.white.withAlpha(200),
                    size: height * RewardConstants.avatarIconSizeRatio,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedKid = ref.watch(selectedKidProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedKid?.name ?? '孩子管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push('/add_kid');
            },
            tooltip: '添加孩子',
          ),
          IconButton(
            icon: const Icon(Icons.cloud_off),
            onPressed: () {
              // 离线模式功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已切换到离线模式')),
              );
            },
            tooltip: '离线模式',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SizedBox.expand(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                itemCount: kids.length,
                onPageChanged: (index) async {
                  try {
                    await ref
                        .read(home_providers.selectedKidIndexProvider.notifier)
                        .selectKidIndex(index);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('切换失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context, index) {
                  final kid = kids[index];
                  return SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: height * RewardConstants.avatarSizeRatio,
                              height: height * RewardConstants.avatarSizeRatio,
                              child: Hero(
                                tag: 'kid-avatar-${kid.id}',
                                child: getKidAvatar(kid, context),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Consumer(
                              builder: (context, ref, child) {
                                final currentTimeStars = ref.watch(timeStarsProvider(kid.id));
                                return CounterCard(
                                  icon: Icons.timer_outlined,
                                  color: colorScheme.primary,
                                  value: currentTimeStars,
                                  unit: '分钟',
                                  maxValue: RewardConstants.maxTimeMinutes,
                                  onIncrement: () => _updateKidMetadata(
                                    ref,
                                    kid.id,
                                    'timeStars',
                                    currentTimeStars,
                                    RewardConstants.defaultIncrement,
                                    RewardConstants.maxTimeMinutes,
                                  ),
                                  onDecrement: () => _updateKidMetadata(
                                    ref,
                                    kid.id,
                                    'timeStars',
                                    currentTimeStars,
                                    -RewardConstants.defaultIncrement,
                                    RewardConstants.maxTimeMinutes,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),
                            Consumer(
                              builder: (context, ref, child) {
                                final currentMoneyStars = ref.watch(moneyStarsProvider(kid.id));
                                return LinkCard(
                                  icon: Icons.star_rounded,
                                  color: Colors.amber,
                                  value: currentMoneyStars,
                                  maxValue: RewardConstants.maxMoneyStars,
                                  onIncrement: () => _updateKidMetadata(
                                    ref,
                                    kid.id,
                                    'moneyStars',
                                    currentMoneyStars,
                                    RewardConstants.defaultIncrement,
                                    RewardConstants.maxMoneyStars,
                                  ),
                                  onDecrement: () => _updateKidMetadata(
                                    ref,
                                    kid.id,
                                    'moneyStars',
                                    currentMoneyStars,
                                    -RewardConstants.defaultIncrement,
                                    RewardConstants.maxMoneyStars,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            // 专注学习按钮
                            FilledButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => FocusTimerDialog(
                                    kidId: kid.id,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.psychology),
                              label: const Text('专注学习'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(200, 48),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 查看专注记录按钮
                            OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => FocusSessionHistoryDialog(
                                    kidId: kid.id,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history),
                              label: const Text('学习记录'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 加载指示器
          if (_isLoading) Container(
            color: Colors.black.withAlpha(100),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}
