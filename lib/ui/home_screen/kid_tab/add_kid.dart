import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gowhymo/constants/app_constants.dart';
import 'package:gowhymo/db/kid.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/providers/settings_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:random_avatar/random_avatar.dart';

// 在文件顶部添加导入
import 'package:image_cropper/image_cropper.dart';

class AddKidScreen extends ConsumerStatefulWidget {
  const AddKidScreen({super.key});

  @override
  ConsumerState<AddKidScreen> createState() => _AddKidScreenState();
}

class _AddKidScreenState extends ConsumerState<AddKidScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  // 新增：头像状态管理

  AvatarType _avatarType = AvatarType.none;
  File? _selectedImage;
  String? _randomAvatarSeed;
  bool isLoading = false;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          maxWidth: 500, // 设置最大宽度
          maxHeight: 500, // 设置最大高度
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 设置宽高比为 1:1
          compressFormat: ImageCompressFormat.png, // 设置输出格式为 PNG
          compressQuality: 100, // 设置压缩质量为 100%
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '裁剪头像',
              // toolbarColor: ref.read(themeProvider).primaryColor,
              // toolbarWidgetColor: ref.read(themeProvider).colorScheme.inversePrimary,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: '裁剪头像'),
          ],
        );

        if (croppedFile != null && mounted) {
          setState(() {
            _selectedImage = File(croppedFile.path);
            _avatarType = AvatarType.imageFile;
          });
        }
      }
    } catch (e) {
      // 捕获并处理异常，避免应用崩溃
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片处理失败: ${e.toString()}')),
        );
      }
    }
  }

  // 新增：生成随机头像
  void _generateRandomAvatar() async {
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        // 使用时间戳作为随机种子，确保每次生成不同头像
        _randomAvatarSeed = DateTime.now().millisecondsSinceEpoch.toString();
        _avatarType = AvatarType.randomAvatar;
      });
    }
  }

  // 新增：构建头像显示组件
  Widget _buildAvatarContent() {
    switch (_avatarType) {
      case AvatarType.imageFile:
        return ClipOval(
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        );
      case AvatarType.randomAvatar:
        return ClipOval(
          child: RandomAvatar(
            _randomAvatarSeed!,
            width: double.infinity,
          ),
        );
      default:
        return Icon(
          Icons.camera_alt,
          size: MediaQuery.sizeOf(context).height / 10,
        );
    }
  }

  bool checkInput() {
    if (_avatarType == AvatarType.none) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择或生成头像')));
      return false;
    }

    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入昵称')));
      return false;
    }
    return true;
  }

  Future<int?> _createKid() async {
    // 首先检查输入
    if (!checkInput()) {
      return null;
    }

    // 设置加载状态
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final now = DateTime.now();
      String? avatarImageData;

      if (_avatarType == AvatarType.imageFile) {
        // 读取文件并转为 base64
        final bytes = await _selectedImage!.readAsBytes();
        avatarImageData = base64Encode(bytes);
      } else if (_avatarType == AvatarType.randomAvatar) {
        // 对于随机头像，保存SVG字符串
        avatarImageData = RandomAvatarString(_randomAvatarSeed!);
      } else {
        throw Exception('未知的头像类型');
      }

      final currentUser = await ref.read(userNotifierProvider.future);

      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前用户不存在')));
        }
        return null;
      }

      final kid = Kid(
        id: 0, // 插入时ID为0，数据库会自动生成
        name: _nicknameController.text,
        birthDate: null,
        gender: null,
        avatarType: _avatarType,
        avatarImageData: avatarImageData,
        description: null,
        createdBy: currentUser.id,
        createdAt: now,
        updatedAt: now,
        metadata: null,
      );

      // 使用本地数据库保存孩子数据
      final id = await KidDao.insert(kid);

      // log("create kid id: $id", name: 'ui/home_screen/kid_tab/add_kid.dart');

      // 刷新孩子列表
      ref.read(kidListProvider.notifier).refreshKids();

      // 成功创建后返回上一页
      if (id != null && context.mounted) {
        context.pop();
      }

      return id;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return null;
    } finally {
      // 重置加载状态
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // log("addKidScreen build", name: 'ui/home_screen/kid_tab/add_kid.dart');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加对象'),
        actions: [
          IconButton(icon: const Icon(Icons.cloud_off), onPressed: () async {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).height / 5,
              height: MediaQuery.sizeOf(context).height / 5,
              child: FloatingActionButton(
                shape: const CircleBorder(),
                heroTag: 'addKidFab',
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 12,
                onPressed: () {
                  _pickImage(); // 点击仍然可以重新选择图片
                },
                child: _buildAvatarContent(), // 使用新的头像显示组件
              ),
            ),
            // const SizedBox(height: 20),
            // Row(
            //   // 以下按钮区域居中对齐
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     ElevatedButton.icon(
            //       onPressed: () {
            //         _generateRandomAvatar(); // 调用生成随机头像方法
            //       },
            //       icon: const Icon(Icons.casino),
            //       label: const Text('随机生成头像'),
            //     ),
            //     const SizedBox(width: 20),
            //     ElevatedButton.icon(
            //       onPressed: () async {
            //         _pickImage();
            //       },
            //       icon: const Icon(Icons.image),
            //       label: const Text('图库选择头像'),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 40),
            TextFormField(
              controller: _nicknameController,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: '孩子昵称',
                hintText: '输入孩子昵称',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: colorScheme.primary,
                  size: 28, // 增大图标尺寸适配大字体
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    inputBorderRadius,
                  ), // 减小圆角，更现代
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    width: 1, // 增加边框宽度
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(inputBorderRadius),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2, // 聚焦时更粗的边框
                  ),
                ),
                labelStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 18, // 增大标签字体
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 20, // 增大提示文字
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24, // 增加水平内边距
                  vertical: 20, // 增加垂直内边距适配大字体
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入孩子昵称';
                }
                if (value.trim().length < 2) {
                  return '孩子昵称至少需要2个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 64, // 固定高度，与输入框协调
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _createKid(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      inputBorderRadius,
                    ), // 与输入框圆角一致
                  ),
                  elevation: 12, // 更强的阴影
                  shadowColor: colorScheme.primary.withValues(alpha: 0.6),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 22, // 增大字体
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2, // 增加字间距
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }
}
