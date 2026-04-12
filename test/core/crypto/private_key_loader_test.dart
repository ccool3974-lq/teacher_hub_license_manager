import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_loader.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_storage_service.dart';

void main() {
  group('PrivateKeyLoader', () {
    test('loads key seed from stored key file when env is absent', () async {
      final Directory tempRoot = await Directory.systemTemp.createTemp(
        'private-key-loader-test-',
      );
      addTearDown(() async {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      });

      final File sourceFile = File('${tempRoot.path}\\source.seed');
      const String hexSeed =
          '9d61b19deffd5a60ba84af492ecc4c44c5697b326919703bac031cae7f60d57f';
      await sourceFile.writeAsString(hexSeed);

      final storageService = PrivateKeyStorageService(
        documentsDirectoryResolver: () async => tempRoot,
      );
      await storageService.importKeyFile(sourceFile);

      final loader = PrivateKeyLoader(storageService: storageService);
      final List<int> seed = await loader.loadPrivateKeySeed();

      expect(seed.length, 32);
      expect(seed.first, 0x9d);
      expect(seed.last, 0x7f);
    });
  });
}
