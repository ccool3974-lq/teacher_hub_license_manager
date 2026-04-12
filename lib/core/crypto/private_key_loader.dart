import 'dart:convert';
import 'dart:io';

import 'package:teacher_hub_license_manager/core/crypto/private_key_storage_service.dart';

class PrivateKeyLoader {
  PrivateKeyLoader({
    PrivateKeyStorageService? storageService,
  }) : _storageService = storageService ?? PrivateKeyStorageService();

  static const String seedEnvKey = 'TEACHER_HUB_LICENSE_PRIVATE_KEY_SEED';
  static const String fileEnvKey = 'TEACHER_HUB_LICENSE_PRIVATE_KEY_FILE';

  final PrivateKeyStorageService _storageService;

  Future<List<int>> loadPrivateKeySeed() async {
    final String? inlineSeed = _trimToNull(Platform.environment[seedEnvKey]);
    if (inlineSeed != null) {
      return _parseSeed(inlineSeed);
    }

    final String? filePath = _trimToNull(Platform.environment[fileEnvKey]);
    if (filePath != null) {
      final File file = File(filePath);
      if (!await file.exists()) {
        throw StateError('未找到私钥文件：$filePath');
      }
      final String content = await file.readAsString();
      return _parseSeed(content);
    }

    final File? storedFile = await _storageService.getStoredKeyFile();
    if (storedFile != null) {
      final String content = await storedFile.readAsString();
      return _parseSeed(content);
    }

    throw StateError(
      '未配置授权私钥。请设置环境变量 '
      '$seedEnvKey 或 $fileEnvKey，'
      '或在程序中导入私钥文件。',
    );
  }

  List<int> _parseSeed(String rawValue) {
    final String normalized = rawValue.trim();
    if (normalized.isEmpty) {
      throw StateError('私钥种子为空。');
    }

    final String hexCandidate =
        normalized.replaceAll(RegExp(r'\s+'), '').replaceFirst('0x', '');
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexCandidate)) {
      return List<int>.generate(
        32,
        (int index) =>
            int.parse(hexCandidate.substring(index * 2, index * 2 + 2), radix: 16),
        growable: false,
      );
    }

    try {
      final List<int> decoded =
          base64Url.decode(base64Url.normalize(normalized));
      if (decoded.length == 32) {
        return decoded;
      }
    } catch (_) {
      // Fall through to final error.
    }

    throw StateError('私钥种子格式无效，应为 32 字节 hex 或 base64url。');
  }

  String? _trimToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
