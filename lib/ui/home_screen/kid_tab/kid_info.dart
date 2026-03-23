import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart' as home_providers;
import 'package:gowhymo/ui/home_screen/kid_tab/components/kid_avatar.dart';
import 'package:gowhymo/ui/home_screen/kid_tab/providers/kid_tab_providers.dart';

class KidInfoScreen extends ConsumerWidget {
  const KidInfoScreen({super.key, required this.kidId});
  
  final int kidId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kidsAsync = ref.watch(home_providers.kidListProvider);
    
    return kidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (kids) {
        final kid = kids.firstWhere((k) => k.id == kidId, orElse: () => throw Exception('Kid not found'));
        return Scaffold(
          appBar: AppBar(
            title: Text(kid.name),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 头部信息卡片
              _buildHeaderCard(context, kid),
              const SizedBox(height: 20),
              
              // 基本信息卡片
              _buildInfoCard(context, kid),
              const SizedBox(height: 20),
              
              // 统计信息卡片
              _buildStatsCard(context, ref, kid),
              const SizedBox(height: 20),
              
              // 操作按钮
              _buildActionButtons(context, ref, kid),
            ],
          ),
        );
      },
    );
  }

  // 头部信息卡片
  Widget _buildHeaderCard(BuildContext context, Kid kid) {
    return SizedBox(
      height: (MediaQuery.sizeOf(context).width - 32) / 2 + 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              height: 180,
              margin: const EdgeInsets.only(top: 60),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    kid.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${kid.birthDate != null ? '${kid.birthDate!.year}年${kid.birthDate!.month}月${kid.birthDate!.day}日' : '未设置生日'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          // 叠在上面的 Avatar
          Positioned(
            top: 0,
            child: SizedBox(
              width: 120,
              height: 120,
              child: getKidAvatar(kid, context),
            ),
          ),
        ],
      ),
    );
  }

  // 基本信息卡片
  Widget _buildInfoCard(BuildContext context, Kid kid) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _infoRow(context, '性别', kid.gender ?? '未设置'),
            _infoRow(context, '创建时间', '${kid.createdAt.year}年${kid.createdAt.month}月${kid.createdAt.day}日'),
            _infoRow(context, '描述', kid.description ?? '无描述'),
          ],
        ),
      ),
    );
  }

  // 统计信息卡片
  Widget _buildStatsCard(BuildContext context, WidgetRef ref, Kid kid) {
    final timeStars = ref.watch(timeStarsProvider(kid.id));
    final moneyStars = ref.watch(moneyStarsProvider(kid.id));
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '统计信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _infoRow(context, '时间星', '$timeStars 分钟'),
            _infoRow(context, '金钱星', '$moneyStars 个'),
          ],
        ),
      ),
    );
  }

  // 操作按钮
  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Kid kid) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // 编辑孩子信息
              context.push('/edit_kid', extra: kid);
            },
            icon: const Icon(Icons.edit),
            label: const Text('编辑信息'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              // 删除孩子
              await ref.read(home_providers.kidListProvider.notifier).deleteKid(kid.id.toString());
              context.pop();
            },
            icon: const Icon(Icons.delete),
            label: const Text('删除孩子'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  // 信息行
  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
