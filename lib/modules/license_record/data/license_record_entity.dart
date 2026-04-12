import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

enum LicenseRecordStatus {
  active('active'),
  revoked('revoked'),
  replaced('replaced');

  const LicenseRecordStatus(this.storageValue);

  final String storageValue;

  static LicenseRecordStatus fromStorageValue(String value) {
    return LicenseRecordStatus.values.firstWhere(
      (LicenseRecordStatus status) => status.storageValue == value,
      orElse: () => LicenseRecordStatus.active,
    );
  }
}

class LicenseRecordEntity {
  const LicenseRecordEntity({
    this.id,
    required this.licenseId,
    required this.bindName,
    this.bindUserCode,
    required this.tier,
    this.durationDays,
    required this.permanent,
    required this.issuedAt,
    required this.activationDeadline,
    this.operatorName,
    this.remark,
    required this.rawLicense,
    required this.status,
    this.exportedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String licenseId;
  final String bindName;
  final String? bindUserCode;
  final LicenseTier tier;
  final int? durationDays;
  final bool permanent;
  final DateTime issuedAt;
  final DateTime activationDeadline;
  final String? operatorName;
  final String? remark;
  final String rawLicense;
  final LicenseRecordStatus status;
  final DateTime? exportedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  LicenseRecordEntity copyWith({
    int? id,
    String? licenseId,
    String? bindName,
    String? bindUserCode,
    LicenseTier? tier,
    int? durationDays,
    bool? permanent,
    DateTime? issuedAt,
    DateTime? activationDeadline,
    String? operatorName,
    String? remark,
    String? rawLicense,
    LicenseRecordStatus? status,
    DateTime? exportedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearBindUserCode = false,
    bool clearOperatorName = false,
    bool clearRemark = false,
    bool clearExportedAt = false,
  }) {
    return LicenseRecordEntity(
      id: id ?? this.id,
      licenseId: licenseId ?? this.licenseId,
      bindName: bindName ?? this.bindName,
      bindUserCode:
          clearBindUserCode ? null : (bindUserCode ?? this.bindUserCode),
      tier: tier ?? this.tier,
      durationDays: durationDays ?? this.durationDays,
      permanent: permanent ?? this.permanent,
      issuedAt: issuedAt ?? this.issuedAt,
      activationDeadline: activationDeadline ?? this.activationDeadline,
      operatorName:
          clearOperatorName ? null : (operatorName ?? this.operatorName),
      remark: clearRemark ? null : (remark ?? this.remark),
      rawLicense: rawLicense ?? this.rawLicense,
      status: status ?? this.status,
      exportedAt: clearExportedAt ? null : (exportedAt ?? this.exportedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'licenseId': licenseId,
      'bindName': bindName,
      'bindUserCode': bindUserCode,
      'tier': tier.storageValue,
      'durationDays': durationDays,
      'permanent': permanent ? 1 : 0,
      'issuedAt': issuedAt.toIso8601String(),
      'activationDeadline': activationDeadline.toIso8601String(),
      'operatorName': operatorName,
      'remark': remark,
      'rawLicense': rawLicense,
      'status': status.storageValue,
      'exportedAt': exportedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LicenseRecordEntity.fromMap(Map<String, Object?> map) {
    return LicenseRecordEntity(
      id: map['id'] as int?,
      licenseId: map['licenseId'] as String,
      bindName: map['bindName'] as String,
      bindUserCode: map['bindUserCode'] as String?,
      tier: LicenseTier.fromStorageValue(map['tier'] as String),
      durationDays: map['durationDays'] as int?,
      permanent: (map['permanent'] as int) == 1,
      issuedAt: DateTime.parse(map['issuedAt'] as String),
      activationDeadline: map['activationDeadline'] == null
          ? DateTime.parse(map['issuedAt'] as String)
              .toUtc()
              .add(const Duration(days: 30))
          : DateTime.parse(map['activationDeadline'] as String),
      operatorName: map['operatorName'] as String?,
      remark: map['remark'] as String?,
      rawLicense: map['rawLicense'] as String,
      status: LicenseRecordStatus.fromStorageValue(map['status'] as String),
      exportedAt: map['exportedAt'] == null
          ? null
          : DateTime.parse(map['exportedAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
