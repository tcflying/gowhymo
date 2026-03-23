import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart' as home_providers;

/// 获取单个 Kid 的 Provider
/// 使用 family 参数来区分不同的 kid
final kidProvider = Provider.family<Kid?, int>((ref, kidId) {
  final kidsAsync = ref.watch(home_providers.kidListProvider);
  if (kidsAsync is AsyncData<List<Kid>>) {
    try {
      return kidsAsync.value.firstWhere((k) => k.id == kidId);
    } catch (_) {
      return null;
    }
  }
  return null;
});

/// 获取单个 Kid 的 metadata 的 Provider
/// 这是细粒度的 provider，更新 metadata 不会触发整个列表重建
final kidMetadataProvider = Provider.family<Map<String, dynamic>?, int>((ref, kidId) {
  final kid = ref.watch(kidProvider(kidId));
  return kid?.metadata;
});

/// 获取单个 Kid 的 timeStars
final timeStarsProvider = Provider.family<int, int>((ref, kidId) {
  final metadata = ref.watch(kidMetadataProvider(kidId));
  return metadata?['timeStars'] ?? 0;
});

/// 获取单个 Kid 的 moneyStars
final moneyStarsProvider = Provider.family<int, int>((ref, kidId) {
  final metadata = ref.watch(kidMetadataProvider(kidId));
  return metadata?['moneyStars'] ?? 0;
});

/// 更新单个 Kid 的 metadata
/// 这个函数会更新数据库和 kidListProvider，但不会触发整个列表的重建
Future<void> updateKidMetadata(WidgetRef ref, int kidId, Map<String, dynamic> newMetadata) async {
  final kid = ref.read(kidProvider(kidId));
  if (kid == null) return;

  final updatedKid = kid.copyWith(metadata: newMetadata);
  
  // 先更新数据库
  await KidDao.update(updatedKid);
  
  // 直接更新 kidListProvider 的 state，避免触发 loading 状态
  final currentKids = ref.read(home_providers.kidListProvider);
  if (currentKids is AsyncData<List<Kid>>) {
    // 使用 updateKid 方法来更新
    await ref.read(home_providers.kidListProvider.notifier).updateKid(kidId.toString(), updatedKid);
  }
}