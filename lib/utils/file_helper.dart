import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static FileHelper? _instance;
  static FileHelper get instance => _instance ??= FileHelper._();
  FileHelper._();

  Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<String> saveFile({
    required File sourceFile,
    String? subDir,
    String? fileName,
    bool overwrite = false,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();

      String targetDirPath = appDocDir.path;
      if (subDir != null && subDir.isNotEmpty) {
        targetDirPath = path.join(appDocDir.path, subDir);
      }

      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final targetFileName = fileName ?? path.basename(sourceFile.path);
      final targetPath = path.join(targetDirPath, targetFileName);

      final targetFile = File(targetPath);
      if (await targetFile.exists() && !overwrite) {
        final fileNameWithoutExt = path.basenameWithoutExtension(
          targetFileName,
        );
        final fileExt = path.extension(targetFileName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uniqueFileName = '${fileNameWithoutExt}_$timestamp$fileExt';
        final uniqueTargetPath = path.join(targetDirPath, uniqueFileName);

        await sourceFile.copy(uniqueTargetPath);

        return subDir != null
            ? path.join(subDir, uniqueFileName)
            : uniqueFileName;
      }

      await sourceFile.copy(targetPath);

      return subDir != null
          ? path.join(subDir, targetFileName)
          : targetFileName;
    } catch (e) {
      throw Exception('保存文件失败: $e');
    }
  }

  Future<String> getFullPath(String relativePath) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return path.join(appDocDir.path, relativePath);
  }

  Future<File> getFile(String relativePath) async {
    final fullPath = await getFullPath(relativePath);
    return File(fullPath);
  }

  Future<bool> fileExists(String relativePath) async {
    try {
      final file = await getFile(relativePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteFile(String relativePath) async {
    try {
      final file = await getFile(relativePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('删除文件失败: $e');
    }
  }

  Future<int> getFileSize(String relativePath) async {
    try {
      final file = await getFile(relativePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static String generateUniqueFileName({
    String prefix = 'file',
    String extension = '',
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp$extension';
  }

  Future<String> saveAvatarFile({
    required File sourceFile,
    bool overwrite = false,
  }) async {
    return saveFile(
      sourceFile: sourceFile,
      subDir: 'avatars',
      overwrite: overwrite,
    );
  }

  Future<File> getAvatarFile(String relativePath) async {
    return getFile(relativePath);
  }

  Future<void> cleanOldFiles(String subDir, {int daysToKeep = 30}) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(path.join(appDocDir.path, subDir));

      if (!await targetDir.exists()) {
        return;
      }

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: daysToKeep));

      await for (final entity in targetDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  static ImageProvider? loadImageFromFile(File file) {
    if (!file.existsSync()) {
      return null;
    }
    return FileImage(file);
  }

  static Future<ImageProvider?> loadImageFromRelativePath(
    String relativePath,
  ) async {
    try {
      final instance = FileHelper.instance;
      final file = await instance.getFile(relativePath);
      if (await file.exists()) {
        return FileImage(file);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }
}
