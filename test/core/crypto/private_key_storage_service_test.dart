import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_storage_service.dart';

void main() {
  group('PrivateKeyStorageService', () {
    test('imports key file into app settings directory', () async {
      final Directory tempRoot = await Directory.systemTemp.createTemp(
        'private-key-storage-test-',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final File sourceFile = File('${tempRoot.path}\\source.seed');
      await sourceFile.writeAsString('  test-private-key-seed  ');

      final service = PrivateKeyStorageService(
        documentsDirectoryResolver: () async => tempRoot,
      );

      final File storedFile = await service.importKeyFile(sourceFile);

      expect(
        storedFile.path,
        '${tempRoot.path}\\settings\\license_private_key.seed',
      );
      expect(await storedFile.readAsString(), 'test-private-key-seed');
      expect(await service.hasStoredKey(), isTrue);
    });

    test('clears imported key file', () async {
      final Directory tempRoot = await Directory.systemTemp.createTemp(
        'private-key-storage-clear-test-',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final File sourceFile = File('${tempRoot.path}\\source.seed');
      await sourceFile.writeAsString('seed-value');

      final service = PrivateKeyStorageService(
        documentsDirectoryResolver: () async => tempRoot,
      );

      await service.importKeyFile(sourceFile);
      await service.clearStoredKey();

      expect(await service.getStoredKeyFile(), isNull);
      expect(await service.hasStoredKey(), isFalse);
    });
  });
}
