import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_generation_service.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

void main() {
  test('generation service creates signed structured license', () async {
    const List<int> seed = <int>[
      0x9d,
      0x61,
      0xb1,
      0x9d,
      0xef,
      0xfd,
      0x5a,
      0x60,
      0xba,
      0x84,
      0xaf,
      0x49,
      0x2e,
      0xcc,
      0x4c,
      0x44,
      0xc5,
      0x69,
      0x7b,
      0x32,
      0x69,
      0x19,
      0x70,
      0x3b,
      0xac,
      0x03,
      0x1c,
      0xae,
      0x7f,
      0x60,
      0xd5,
      0x7f,
    ];
    final LicenseGenerationService service = LicenseGenerationService(
      loadPrivateKeySeed: () async => seed,
      now: () => DateTime.utc(2026, 4, 2, 12, 0),
      random: Random(7),
    );

    final GeneratedLicense generated = await service.generate(
      bindName: 'Zhang',
      bindUserCode: 'T001',
      durationDays: 180,
      permanent: false,
    );

    expect(
      generated.rawLicense.startsWith('$licenseStructuredPrefix.'),
      isTrue,
    );
    expect(generated.rawLicense.startsWith('TTK3.'), isTrue);
    expect(generated.payload.bindName, 'Zhang');
    expect(generated.payload.bindUserCode, 'T001');
    expect(generated.payload.durationDays, 180);
    expect(generated.payload.permanent, isFalse);
    expect(
      generated.payload.activationDeadline,
      DateTime.utc(2026, 5, 2, 12, 0),
    );

    final List<String> segments = generated.rawLicense.split('.');
    expect(segments, hasLength(3));

    final LicensePayload decoded = LicenseCodec.decodePayloadSegment(
      segments[1],
    );
    expect(decoded.licenseId, generated.licenseId);
    expect(decoded.bindUserCode, 'T001');
    expect(decoded.toMap().containsKey('tier'), isFalse);
    expect(decoded.toMap().containsKey('features'), isFalse);

    final PublicKey publicKey = await (await Ed25519().newKeyPairFromSeed(
      seed,
    )).extractPublicKey();
    final Signature signature = Signature(
      base64Url.decode(base64Url.normalize(segments[2])),
      publicKey: publicKey,
    );
    final bool verified = await Ed25519().verify(
      utf8.encode(segments[1]),
      signature: signature,
    );
    expect(verified, isTrue);
  });

  test('generation service rejects activationDeadline before issuedAt', () {
    final LicenseGenerationService service = LicenseGenerationService(
      loadPrivateKeySeed: () async => List<int>.filled(32, 1),
      now: () => DateTime.utc(2026, 4, 2, 12, 0),
      random: Random(7),
    );

    expect(
      () => service.generate(
        bindName: 'Zhang',
        durationDays: 30,
        permanent: false,
        activationDeadline: DateTime.utc(2026, 4, 1, 12, 0),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'permanent license stores zero duration and keeps activationDeadline',
    () async {
      final DateTime activationDeadline = DateTime.utc(2026, 5, 2, 12, 0);
      final LicenseGenerationService service = LicenseGenerationService(
        loadPrivateKeySeed: () async => List<int>.filled(32, 1),
        now: () => DateTime.utc(2026, 4, 2, 12, 0),
        random: Random(7),
      );

      final GeneratedLicense generated = await service.generate(
        bindName: 'Zhang',
        durationDays: 0,
        permanent: true,
        activationDeadline: activationDeadline,
      );

      expect(generated.payload.permanent, isTrue);
      expect(generated.payload.durationDays, 0);
      expect(generated.payload.activationDeadline, activationDeadline);
    },
  );
}
