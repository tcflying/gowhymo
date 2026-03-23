import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gowhymo/ui/home_screen/home_screen_providers.dart';
import 'package:gowhymo/ui/lib.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

enum DownloadStatus { idle, downloading, noPermission, downloadError }

class DownloadState {
  final DownloadStatus status;
  final double progress;

  const DownloadState({required this.status, this.progress = 0});
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  DownloadState? _downloadState;

  Future<String?> downloadAndInstall(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final storagePermission = await ph.Permission.storage.request().isGranted;
    final installPermission = await ph.Permission.requestInstallPackages
        .request()
        .isGranted;

    log(
      'storagePermission: $storagePermission, installPermission: $installPermission',
      name: 'ui/update_dialog.dart',
    );

    if (!storagePermission || !installPermission) {
      return 'permission_denied';
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final savePath = '${appDocDir.path}/gowhymo_$timestamp.apk';

      final headResponse = await dio.head(url);
      if (headResponse.statusCode != 200) {
        throw Exception('服务器上找不到安装包文件');
      }

      final contentLength = headResponse.headers['content-length']?.first;
      if (contentLength == null) {
        log('无法获取文件大小，继续下载...', name: 'ui/update_dialog.dart');
      }

      await dio.download(
        url,
        savePath,
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (count, total) {
          if (total > 0) {
            final value = count / total;
            onProgress(value);
          }
        },
      );

      final file = File(savePath);
      if (!await file.exists()) {
        throw Exception('下载的文件不存在');
      }

      final fileSize = await file.length();
      if (contentLength != null) {
        final expectedSize = int.parse(contentLength);
        if (fileSize != expectedSize) {
          throw Exception('文件大小不匹配，下载可能不完整');
        }
      }

      final bytes = await file.readAsBytes();
      if (bytes.length < 4) {
        throw Exception('文件太小，不是有效的APK文件');
      }

      if (bytes[0] != 0x50 ||
          bytes[1] != 0x4B ||
          bytes[2] != 0x03 ||
          bytes[3] != 0x04) {
        throw Exception('文件格式不正确，不是有效的APK文件');
      }

      if (Platform.isAndroid) {
        await OpenFile.open(savePath);
        Future.delayed(const Duration(minutes: 10), () async {
          if (await file.exists()) {
            await file.delete();
          }
        });
      }

      return null;
    } catch (e) {
      log('下载失败: $e', name: 'ui/update_dialog.dart');
      return e.toString();
    }
  }

  Future<bool> _performUpdate(String url) async {
    setState(() {
      _downloadState = const DownloadState(
        status: DownloadStatus.downloading,
        progress: 0,
      );
    });
    try {
      final error = await downloadAndInstall(
        url,
        onProgress: (progress) {
          setState(() {
            _downloadState = DownloadState(
              status: DownloadStatus.downloading,
              progress: progress,
            );
          });
        },
      );
      if (error == null) {
        setState(() {
          _downloadState = const DownloadState(status: DownloadStatus.idle);
        });
        return true;
      } else if (error == 'permission_denied') {
        setState(() {
          _downloadState = const DownloadState(
            status: DownloadStatus.noPermission,
          );
        });
        return false;
      } else {
        setState(() {
          _downloadState = const DownloadState(
            status: DownloadStatus.downloadError,
          );
        });
        return false;
      }
    } catch (e) {
      log('下载失败: $e', name: 'ui/update_dialog.dart');
      setState(() {
        _downloadState = const DownloadState(
          status: DownloadStatus.downloadError,
        );
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // log("update dialog build",name: 'ui/update_dialog.dart');
    final updateState = ref.watch(updateStateProvider);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        updateState.isUpdateRequired
            ? '强制更新'
            : '发现新版本${updateState.newVersion}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('更新内容:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(updateState.releaseNotes, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          if (_downloadState?.status == DownloadStatus.noPermission) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '权限不足',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text('''请授予以下权限：
• 存储权限：用于保存APK文件
• 安装应用权限：用于安装更新''', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await ph.openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('打开设置'),
                ),
              ],
            ),
          ] else if (_downloadState?.status ==
              DownloadStatus.downloadError) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下载失败',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text('无法下载更新文件，请检查网络连接后重试', style: theme.textTheme.bodySmall),
              ],
            ),
          ] else if (_downloadState?.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _downloadState?.progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '下载进度: ${((_downloadState!.progress * 100).toStringAsFixed(0))}%',
            ),
          ] else if (updateState.isUpdateRequired) ...[
            const SizedBox(height: 16),
            Text(
              '此更新包含重要安全修复，必须安装',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!updateState.isUpdateRequired)
          TextButton(
            onPressed: () {
              ref
                  .read(wantUpdateNowProvider.notifier)
                  .updateWantUpdateNow(false);
              if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            },
            child: const Text('下次更新'),
          ),
        FilledButton(
          onPressed: () async {
            if (_downloadState?.status != DownloadStatus.downloading) {
              final success = await _performUpdate(updateState.downloadUrl);
              if (!mounted) return;

              if (success) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              } else if (_downloadState?.status ==
                  DownloadStatus.noPermission) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('权限被拒绝，无法安装更新'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正在下载，请稍后'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          child: const Text('立即更新'),
        ),
      ],
    );
  }
}
