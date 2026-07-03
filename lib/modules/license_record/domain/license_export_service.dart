import 'dart:io';

import 'package:excel/excel.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';
import 'package:teacher_hub_license_manager/core/export/export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_import_service.dart';

class LicenseExportService {
  LicenseExportService({
    ExportService? exportService,
    ExportDirectoryService? exportDirectoryService,
    LicenseRecordRepository? repository,
    DateTime Function()? now,
  }) : _exportService =
           exportService ??
           ExportService(exportDirectoryService: exportDirectoryService),
       _exportDirectoryService =
           exportDirectoryService ?? ExportDirectoryService(),
       _repository = repository ?? const LicenseRecordRepository(),
       _now = now ?? DateTime.now;

  final ExportService _exportService;
  final ExportDirectoryService _exportDirectoryService;
  final LicenseRecordRepository _repository;
  final DateTime Function() _now;

  Future<File> exportRecordAsText(LicenseRecordEntity record) async {
    final DateTime exportedAt = _now().toUtc();
    final File file = await _exportService.writeTextFile(
      fileName: '${record.licenseId}.license.txt',
      content: _buildRecordText(record),
    );

    await _repository.updateStatus(
      licenseId: record.licenseId,
      status: record.status,
      exportedAt: exportedAt,
      updatedAt: exportedAt,
    );
    return file;
  }

  Future<File> exportRecordsAsXlsx(List<LicenseRecordEntity> records) async {
    final DateTime exportedAt = _now().toUtc();
    final String fileName = 'license_records_${_timestamp(exportedAt)}.xlsx';
    final Excel workbook = Excel.createExcel();
    const String sheetName = '授权记录';
    workbook.rename('Sheet1', sheetName);
    final Sheet sheet = workbook[sheetName];

    final List<String> headers = <String>[
      '授权编号',
      '应用版本号',
      '绑定用户',
      '用户编号',
      '有效期',
      '首次激活截止',
      '状态',
      '发码时间',
      '创建时间',
      '更新时间',
      '操作人',
      '备注',
      '授权码',
      '操作标记',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());

    for (final LicenseRecordEntity record in records) {
      sheet.appendRow(<CellValue>[
        TextCellValue(record.licenseId),
        TextCellValue(record.appVersion),
        TextCellValue(record.bindName),
        TextCellValue(record.bindUserCode ?? ''),
        TextCellValue(record.permanent ? '永久' : '${record.durationDays} 天'),
        TextCellValue(record.activationDeadline.toIso8601String()),
        TextCellValue(_statusLabel(record.status)),
        TextCellValue(record.issuedAt.toIso8601String()),
        TextCellValue(record.createdAt.toIso8601String()),
        TextCellValue(record.updatedAt.toIso8601String()),
        TextCellValue(record.operatorName ?? ''),
        TextCellValue(record.remark ?? ''),
        TextCellValue(record.rawLicense),
        TextCellValue('I'),
      ]);
    }

    final List<int>? bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('生成 .xlsx 文件失败。');
    }

    final File file = await _exportService.writeBytesFile(
      fileName: fileName,
      bytes: bytes,
    );

    for (final LicenseRecordEntity record in records) {
      await _repository.updateStatus(
        licenseId: record.licenseId,
        status: record.status,
        exportedAt: exportedAt,
        updatedAt: exportedAt,
      );
    }
    return file;
  }

  Future<Directory> getExportDirectory() {
    return _exportDirectoryService.getExportDirectory();
  }

  Future<File> exportBatchGenerateTemplate() async {
    final Excel workbook = Excel.createExcel();
    const String sheetName = '批量生码模板';
    workbook.rename('Sheet1', sheetName);
    final Sheet sheet = workbook[sheetName];

    sheet.appendRow(
      LicenseImportService.batchGenerateHeaders.map(TextCellValue.new).toList(),
    );
    sheet.appendRow(<CellValue>[
      TextCellValue('1.2.3'),
      TextCellValue('张老师'),
      TextCellValue('T001'),
      TextCellValue('30'),
      TextCellValue('否'),
      TextCellValue(DateTime.utc(2026, 5, 6, 23, 59, 59).toIso8601String()),
      TextCellValue('AdminA'),
      TextCellValue('示例数据'),
      TextCellValue('I'),
    ]);

    final List<int>? bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('生成批量生码导入模板失败。');
    }

    return _exportService.writeBytesFile(
      fileName:
          '${LicenseImportService.batchGenerateTemplateFileBaseName}.xlsx',
      bytes: bytes,
    );
  }

  Future<File> exportExistingRecordTemplate() async {
    final Excel workbook = Excel.createExcel();
    const String sheetName = '授权记录模板';
    workbook.rename('Sheet1', sheetName);
    final Sheet sheet = workbook[sheetName];

    sheet.appendRow(
      LicenseImportService.existingRecordHeaders
          .map(TextCellValue.new)
          .toList(),
    );
    sheet.appendRow(<CellValue>[
      TextCellValue('LIC-202604060001-ABCD'),
      TextCellValue('1.2.3'),
      TextCellValue('张老师'),
      TextCellValue('T001'),
      TextCellValue('30 天'),
      TextCellValue(DateTime.utc(2026, 5, 6, 23, 59, 59).toIso8601String()),
      TextCellValue('有效'),
      TextCellValue(DateTime.utc(2026, 4, 6, 10, 0).toIso8601String()),
      TextCellValue(DateTime.utc(2026, 4, 6, 10, 0).toIso8601String()),
      TextCellValue(DateTime.utc(2026, 4, 6, 10, 0).toIso8601String()),
      TextCellValue('AdminA'),
      TextCellValue('示例数据'),
      TextCellValue('TTK3.payload.signature'),
      TextCellValue('I'),
    ]);

    final List<int>? bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('生成授权记录导入模板失败。');
    }

    return _exportService.writeBytesFile(
      fileName:
          '${LicenseImportService.existingRecordTemplateFileBaseName}.xlsx',
      bytes: bytes,
    );
  }

  Future<void> openExportDirectory() {
    return _exportDirectoryService.openExportDirectory();
  }

  String _buildRecordText(LicenseRecordEntity record) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('授权编号: ${record.licenseId}')
      ..writeln('应用版本号: ${record.appVersion}')
      ..writeln('绑定用户: ${record.bindName}')
      ..writeln('用户编号: ${record.bindUserCode ?? ''}')
      ..writeln('有效期: ${record.permanent ? '永久' : '${record.durationDays} 天'}')
      ..writeln('首次激活截止: ${record.activationDeadline.toIso8601String()}')
      ..writeln('状态: ${_statusLabel(record.status)}')
      ..writeln('发码时间: ${record.issuedAt.toIso8601String()}')
      ..writeln('创建时间: ${record.createdAt.toIso8601String()}')
      ..writeln('更新时间: ${record.updatedAt.toIso8601String()}')
      ..writeln('操作人: ${record.operatorName ?? ''}')
      ..writeln('备注: ${record.remark ?? ''}')
      ..writeln()
      ..writeln('授权码:')
      ..writeln(record.rawLicense);
    return buffer.toString();
  }

  String _timestamp(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}_'
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}';
  }

  String _statusLabel(LicenseRecordStatus status) {
    return switch (status) {
      LicenseRecordStatus.active => '有效',
      LicenseRecordStatus.revoked => '已作废',
      LicenseRecordStatus.replaced => '已替代',
    };
  }
}
