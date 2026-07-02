import 'dart:io';

import 'package:teacher_hub_license_manager/modules/license_record/domain/license_import_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_generation_service.dart';

class LicenseDashboardSummary {
  const LicenseDashboardSummary({
    required this.totalCount,
    required this.activeCount,
    required this.revokedCount,
    required this.replacedCount,
    required this.permanentCount,
    required this.recentRecords,
  });

  final int totalCount;
  final int activeCount;
  final int revokedCount;
  final int replacedCount;
  final int permanentCount;
  final List<LicenseRecordEntity> recentRecords;
}

class LicenseRecordService {
  LicenseRecordService({
    LicenseRecordRepository? repository,
    LicenseGenerationService? generationService,
    LicenseExportService? exportService,
    LicenseImportService? importService,
    DateTime Function()? now,
  }) : _repository = repository ?? const LicenseRecordRepository(),
       _generationService = generationService ?? LicenseGenerationService(),
       _exportService = exportService,
       _importService = importService,
       _now = now ?? DateTime.now;

  final LicenseRecordRepository _repository;
  final LicenseGenerationService _generationService;
  final LicenseExportService? _exportService;
  final LicenseImportService? _importService;
  final DateTime Function() _now;

  Future<LicenseRecordEntity> createLicenseRecord({
    required String bindName,
    String? bindUserCode,
    required int durationDays,
    required bool permanent,
    DateTime? activationDeadline,
    String? operatorName,
    String? remark,
  }) async {
    final GeneratedLicense generated = await _generationService.generate(
      bindName: bindName,
      bindUserCode: bindUserCode,
      durationDays: durationDays,
      permanent: permanent,
      activationDeadline: activationDeadline,
    );

    final DateTime currentTime = _now().toUtc();
    final LicenseRecordEntity entity = LicenseRecordEntity(
      licenseId: generated.licenseId,
      bindName: bindName.trim(),
      bindUserCode: _trimToNull(bindUserCode),
      durationDays: permanent ? 0 : durationDays,
      permanent: permanent,
      issuedAt: generated.issuedAt,
      activationDeadline: generated.payload.activationDeadline,
      operatorName: _trimToNull(operatorName),
      remark: _trimToNull(remark),
      rawLicense: generated.rawLicense,
      status: LicenseRecordStatus.active,
      exportedAt: null,
      createdAt: currentTime,
      updatedAt: currentTime,
    );

    return _repository.insert(entity);
  }

  Future<List<LicenseRecordEntity>> listRecords() {
    return _repository.listAll();
  }

  Future<LicenseDashboardSummary> getDashboardSummary({
    int recentLimit = 6,
  }) async {
    final List<LicenseRecordEntity> records = await _repository.listAll();
    return LicenseDashboardSummary(
      totalCount: records.length,
      activeCount: records
          .where(
            (LicenseRecordEntity record) =>
                record.status == LicenseRecordStatus.active,
          )
          .length,
      revokedCount: records
          .where(
            (LicenseRecordEntity record) =>
                record.status == LicenseRecordStatus.revoked,
          )
          .length,
      replacedCount: records
          .where(
            (LicenseRecordEntity record) =>
                record.status == LicenseRecordStatus.replaced,
          )
          .length,
      permanentCount: records
          .where((LicenseRecordEntity record) => record.permanent)
          .length,
      recentRecords: records.take(recentLimit).toList(growable: false),
    );
  }

  Future<LicenseRecordEntity?> getRecord(String licenseId) {
    return _repository.findByLicenseId(licenseId);
  }

  Future<LicenseRecordEntity?> updateRecordStatus({
    required String licenseId,
    required LicenseRecordStatus status,
  }) async {
    final DateTime updatedAt = _now().toUtc();
    final int changedRows = await _repository.updateStatus(
      licenseId: licenseId,
      status: status,
      updatedAt: updatedAt,
    );
    if (changedRows == 0) {
      return null;
    }
    return _repository.findByLicenseId(licenseId);
  }

  Future<File> exportRecordAsText(LicenseRecordEntity record) {
    return (_exportService ??
            LicenseExportService(repository: _repository, now: _now))
        .exportRecordAsText(record);
  }

  Future<File> exportRecordsAsXlsx(List<LicenseRecordEntity> records) {
    return (_exportService ??
            LicenseExportService(repository: _repository, now: _now))
        .exportRecordsAsXlsx(records);
  }

  Future<File> exportBatchGenerateTemplate() {
    return (_exportService ??
            LicenseExportService(repository: _repository, now: _now))
        .exportBatchGenerateTemplate();
  }

  Future<File> exportExistingRecordTemplate() {
    return (_exportService ??
            LicenseExportService(repository: _repository, now: _now))
        .exportExistingRecordTemplate();
  }

  Future<LicenseImportResult> importExistingRecords(File file) {
    return (_importService ??
            LicenseImportService(repository: _repository, now: _now))
        .importExistingRecords(file);
  }

  Future<LicenseImportResult> batchGenerateFromFile(File file) {
    return (_importService ??
            LicenseImportService(repository: _repository, now: _now))
        .batchGenerateFromFile(file);
  }

  String? _trimToNull(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
