import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_loader.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

class GeneratedLicense {
  const GeneratedLicense({
    required this.licenseId,
    required this.payload,
    required this.signatureSegment,
    required this.rawLicense,
    required this.issuedAt,
  });

  final String licenseId;
  final LicensePayload payload;
  final String signatureSegment;
  final String rawLicense;
  final DateTime issuedAt;
}

class LicenseGenerationService {
  LicenseGenerationService({
    PrivateKeyLoader? privateKeyLoader,
    Future<List<int>> Function()? loadPrivateKeySeed,
    DateTime Function()? now,
    Random? random,
  }) : _privateKeyLoader = privateKeyLoader ?? PrivateKeyLoader(),
       _loadPrivateKeySeed = loadPrivateKeySeed,
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final PrivateKeyLoader _privateKeyLoader;
  final Future<List<int>> Function()? _loadPrivateKeySeed;
  final DateTime Function() _now;
  final Random _random;

  Future<GeneratedLicense> generate({
    required String appVersion,
    required String bindName,
    String? bindUserCode,
    required int durationDays,
    required bool permanent,
    DateTime? activationDeadline,
    String? licenseId,
  }) async {
    final String normalizedAppVersion = appVersion.trim();
    final String normalizedBindName = bindName.trim();
    final String? normalizedBindUserCode = _trimToNull(bindUserCode);
    if (normalizedAppVersion.isEmpty) {
      throw StateError('应用版本号不能为空。');
    }
    if (normalizedBindName.isEmpty) {
      throw StateError('绑定用户姓名不能为空。');
    }
    if (!permanent && durationDays <= 0) {
      throw StateError('非永久授权必须提供有效的天数。');
    }

    final DateTime issuedAt = _now().toUtc();
    final DateTime resolvedActivationDeadline =
        (activationDeadline?.toUtc() ?? issuedAt.add(const Duration(days: 30)));
    if (resolvedActivationDeadline.isBefore(issuedAt)) {
      throw StateError('首次激活截止日期不能早于发码时间。');
    }
    final String resolvedLicenseId = licenseId?.trim().isNotEmpty == true
        ? licenseId!.trim()
        : _generateLicenseId(issuedAt);

    final LicensePayload payload = LicensePayload(
      product: licenseProductName,
      appVersion: normalizedAppVersion,
      licenseId: resolvedLicenseId,
      bindName: normalizedBindName,
      bindUserCode: normalizedBindUserCode,
      durationDays: permanent ? 0 : durationDays,
      permanent: permanent,
      issuedAt: issuedAt,
      activationDeadline: resolvedActivationDeadline,
      nonce: _generateNonce(),
    );
    final LicensePayloadValidationResult validation =
        LicensePayloadValidator.validateForIssue(payload, issuedAt);
    if (!validation.isValid) {
      throw StateError(validation.errors.join('；'));
    }

    final String payloadSegment = LicenseCodec.encodePayloadSegment(payload);
    final List<int> seed =
        await (_loadPrivateKeySeed?.call() ??
            _privateKeyLoader.loadPrivateKeySeed());
    final SimpleKeyPair keyPair = await Ed25519().newKeyPairFromSeed(seed);
    final Signature signature = await Ed25519().sign(
      utf8.encode(payloadSegment),
      keyPair: keyPair,
    );
    final String signatureSegment = base64Url
        .encode(signature.bytes)
        .replaceAll('=', '');
    final String rawLicense =
        '$licenseStructuredPrefix.$payloadSegment.$signatureSegment';

    return GeneratedLicense(
      licenseId: resolvedLicenseId,
      payload: payload,
      signatureSegment: signatureSegment,
      rawLicense: rawLicense,
      issuedAt: issuedAt,
    );
  }

  String _generateLicenseId(DateTime issuedAt) {
    final String timestamp =
        '${issuedAt.year.toString().padLeft(4, '0')}'
        '${issuedAt.month.toString().padLeft(2, '0')}'
        '${issuedAt.day.toString().padLeft(2, '0')}'
        '${issuedAt.hour.toString().padLeft(2, '0')}'
        '${issuedAt.minute.toString().padLeft(2, '0')}'
        '${issuedAt.second.toString().padLeft(2, '0')}';
    final String suffix = _random
        .nextInt(0x10000)
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return 'LIC-$timestamp-$suffix';
  }

  String _generateNonce() {
    return List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  String? _trimToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
