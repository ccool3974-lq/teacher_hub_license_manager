import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_repository.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

class LicenseImportResult {
  const LicenseImportResult({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.failures,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<String> failures;
}

class LicenseImportService {
  LicenseImportService({
    LicenseRecordRepository? repository,
    LicenseRecordService? recordService,
    DateTime Function()? now,
  })  : _repository = repository ?? const LicenseRecordRepository(),
        _recordService = recordService,
        _now = now ?? DateTime.now;

  static const List<String> existingRecordHeaders = <String>[
    '授权编号',
    '绑定用户',
    '用户编号',
    '授权版本',
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
  static const List<String> existingRecordLegacyHeaders = <String>[
    '授权编号',
    '绑定用户',
    '用户编号',
    '授权版本',
    '有效期',
    '状态',
    '发码时间',
    '创建时间',
    '更新时间',
    '操作人',
    '备注',
    '授权码',
    '操作标记',
  ];

  static const List<String> batchGenerateHeaders = <String>[
    '绑定用户',
    '用户编号',
    '授权版本',
    '有效期天数',
    '永久授权',
    '首次激活截止日期',
    '操作人',
    '备注',
    '操作标记',
  ];
  static const List<String> batchGenerateLegacyHeaders = <String>[
    '绑定用户',
    '用户编号',
    '授权版本',
    '有效期天数',
    '永久授权',
    '操作人',
    '备注',
    '操作标记',
  ];

  static const int maxImportRows = 1000;
  static const String existingRecordTemplateDisplayName = '授权记录导入模板';
  static const String batchGenerateTemplateDisplayName = '批量生码导入模板';
  static const String existingRecordTemplateFileBaseName =
      'license_record_import_template';
  static const String batchGenerateTemplateFileBaseName =
      'license_batch_generate_template';

  final LicenseRecordRepository _repository;
  final LicenseRecordService? _recordService;
  final DateTime Function() _now;

  Future<LicenseImportResult> importExistingRecords(File file) async {
    _assertTemplateFileName(
      file,
      requiredBaseName: existingRecordTemplateFileBaseName,
    );
    final Sheet sheet = await _loadSheet(file);
    final bool hasActivationDeadlineColumn = _assertHeaders(
      sheet: sheet,
      primaryHeaders: existingRecordHeaders,
      legacyHeaders: existingRecordLegacyHeaders,
    );
    final List<List<Data?>> dataRows = _dataRows(sheet);
    _assertMaxImportRows(dataRows.length);

    int totalRows = 0;
    int successCount = 0;
    final List<String> failures = <String>[];

    for (int index = 0; index < dataRows.length; index++) {
      final int rowIndex = index + 1;
      final List<Data?> row = dataRows[index];
      totalRows++;

      try {
        final String licenseId = _requiredText(row, 0, '授权编号');
        final _ImportOperation operation =
            _parseOperation(_requiredText(row, 12, '操作标记'));
        final LicenseRecordEntity? existing =
            await _repository.findByLicenseId(licenseId);

        switch (operation) {
          case _ImportOperation.insert:
            if (existing != null) {
              throw StateError('操作标记为 I，但授权编号已存在');
            }
            final LicenseRecordEntity entity = _parseExistingRecordRow(
              row,
              hasActivationDeadlineColumn: hasActivationDeadlineColumn,
            );
            await _repository.insert(entity);
            break;
          case _ImportOperation.update:
            if (existing == null) {
              throw StateError('操作标记为 U，但授权编号不存在');
            }
            final LicenseRecordEntity entity = _parseExistingRecordRow(
              row,
              hasActivationDeadlineColumn: hasActivationDeadlineColumn,
            );
            await _repository.upsertByLicenseId(entity);
            break;
          case _ImportOperation.delete:
            if (existing == null) {
              throw StateError('操作标记为 D，但授权编号不存在');
            }
            await _repository.deleteByLicenseId(licenseId);
            break;
        }
        successCount++;
      } catch (error) {
        failures.add('第 ${rowIndex + 1} 行：$error');
      }
    }

    return LicenseImportResult(
      totalRows: totalRows,
      successCount: successCount,
      failureCount: failures.length,
      failures: failures,
    );
  }

  Future<LicenseImportResult> batchGenerateFromFile(File file) async {
    final LicenseRecordService service =
        _recordService ?? LicenseRecordService(repository: _repository, now: _now);
    _assertTemplateFileName(
      file,
      requiredBaseName: batchGenerateTemplateFileBaseName,
    );
    final Sheet sheet = await _loadSheet(file);
    final bool hasActivationDeadlineColumn = _assertHeaders(
      sheet: sheet,
      primaryHeaders: batchGenerateHeaders,
      legacyHeaders: batchGenerateLegacyHeaders,
    );
    final List<List<Data?>> dataRows = _dataRows(sheet);
    _assertMaxImportRows(dataRows.length);

    int totalRows = 0;
    int successCount = 0;
    final List<String> failures = <String>[];

    for (int index = 0; index < dataRows.length; index++) {
      final int rowIndex = index + 1;
      final List<Data?> row = dataRows[index];
      totalRows++;

      try {
        final _BatchGenerateInput input = _parseBatchGenerateRow(
          row,
          hasActivationDeadlineColumn: hasActivationDeadlineColumn,
        );
        if (input.operation != _ImportOperation.insert) {
          throw StateError('批量生码导入当前仅支持操作标记 I');
        }
        await service.createLicenseRecord(
          bindName: input.bindName,
          bindUserCode: input.bindUserCode,
          tier: input.tier,
          durationDays: input.durationDays,
          permanent: input.permanent,
          activationDeadline: input.activationDeadline,
          operatorName: input.operatorName,
          remark: input.remark,
        );
        successCount++;
      } catch (error) {
        failures.add('第 ${rowIndex + 1} 行：$error');
      }
    }

    return LicenseImportResult(
      totalRows: totalRows,
      successCount: successCount,
      failureCount: failures.length,
      failures: failures,
    );
  }

  Future<Sheet> _loadSheet(File file) async {
    if (!await file.exists()) {
      throw StateError('未找到导入文件：${file.path}');
    }
    final Excel workbook = Excel.decodeBytes(await file.readAsBytes());
    if (workbook.tables.isEmpty) {
      throw StateError('导入文件中未找到工作表。');
    }
    return workbook.tables.values.first;
  }

  bool _assertHeaders({
    required Sheet sheet,
    required List<String> primaryHeaders,
    required List<String> legacyHeaders,
  }) {
    final List<String> actualHeaders = _normalizeHeaderCells(sheet.row(0))
        .map((Data? cell) => _cellText(cell))
        .toList(growable: false);
    if (_listEquals(actualHeaders, primaryHeaders)) {
      return true;
    }
    if (_listEquals(actualHeaders, legacyHeaders)) {
      return false;
    }
    if (actualHeaders.length > primaryHeaders.length) {
      throw StateError('导入模板表头不匹配，请使用系统导出的标准模板。');
    }
    throw StateError('导入模板表头不匹配，请使用系统导出的标准模板。');
  }

  List<List<Data?>> _dataRows(Sheet sheet) {
    return <List<Data?>>[
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++)
        if (!_isRowEmpty(sheet.row(rowIndex))) sheet.row(rowIndex),
    ];
  }

  void _assertMaxImportRows(int rowCount) {
    if (rowCount > maxImportRows) {
      throw StateError('单次最多导入 1000 条数据，当前文件共有 $rowCount 条。');
    }
  }

  void _assertTemplateFileName(File file, {required String requiredBaseName}) {
    final String baseName =
        p.basenameWithoutExtension(file.path).trim().toLowerCase();
    if (!baseName.contains(requiredBaseName.toLowerCase())) {
      throw StateError('导入文件名必须包含模板名“$requiredBaseName”，请基于最新下载模板填写后再导入。');
    }
  }

  List<Data?> _normalizeHeaderCells(List<Data?> headerRow) {
    final List<Data?> normalized = List<Data?>.from(headerRow);
    while (normalized.isNotEmpty && _cellText(normalized.last).isEmpty) {
      normalized.removeLast();
    }
    return normalized;
  }

  LicenseRecordEntity _parseExistingRecordRow(
    List<Data?> row, {
    required bool hasActivationDeadlineColumn,
  }) {
    final String licenseId = _requiredText(row, 0, '授权编号');
    final String bindName = _requiredText(row, 1, '绑定用户');
    final LicenseTier tier = _parseTier(_requiredText(row, 3, '授权版本'));
    final _DurationValue duration = _parseDuration(_requiredText(row, 4, '有效期'));
    final DateTime issuedAt = _parseDate(
      _requiredText(row, hasActivationDeadlineColumn ? 7 : 6, '发码时间'),
      '发码时间',
    );
    final DateTime activationDeadline = hasActivationDeadlineColumn
        ? _parseDate(_requiredText(row, 5, '首次激活截止'), '首次激活截止')
        : issuedAt.toUtc().add(const Duration(days: 30));
    final LicenseRecordStatus status = _parseStatus(
      _requiredText(row, hasActivationDeadlineColumn ? 6 : 5, '状态'),
    );
    final DateTime createdAt = _parseDate(
      _requiredText(row, hasActivationDeadlineColumn ? 8 : 7, '创建时间'),
      '创建时间',
    );
    final DateTime updatedAt = _parseDate(
      _requiredText(row, hasActivationDeadlineColumn ? 9 : 8, '更新时间'),
      '更新时间',
    );
    final String rawLicense = _requiredText(
      row,
      hasActivationDeadlineColumn ? 12 : 11,
      '授权码',
    );

    return LicenseRecordEntity(
      licenseId: licenseId,
      bindName: bindName,
      bindUserCode: _optionalText(row, 2),
      tier: tier,
      durationDays: duration.permanent ? null : duration.days,
      permanent: duration.permanent,
      issuedAt: issuedAt,
      activationDeadline: activationDeadline,
      operatorName: _optionalText(row, hasActivationDeadlineColumn ? 10 : 9),
      remark: _optionalText(row, hasActivationDeadlineColumn ? 11 : 10),
      rawLicense: rawLicense,
      status: status,
      exportedAt: null,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  _BatchGenerateInput _parseBatchGenerateRow(
    List<Data?> row, {
    required bool hasActivationDeadlineColumn,
  }) {
    final String bindName = _requiredText(row, 0, '绑定用户');
    final LicenseTier tier = _parseTier(_requiredText(row, 2, '授权版本'));
    final bool permanent = _parseBool(_requiredText(row, 4, '永久授权'));
    final int durationDays = permanent
        ? 0
        : _parseInt(_requiredText(row, 3, '有效期天数'), '有效期天数');
    if (!permanent && durationDays <= 0) {
      throw StateError('有效期天数必须大于 0');
    }
    final DateTime? activationDeadline = hasActivationDeadlineColumn
        ? _optionalDate(row, 5, '首次激活截止日期')
        : null;

    return _BatchGenerateInput(
      bindName: bindName,
      bindUserCode: _optionalText(row, 1),
      tier: tier,
      durationDays: durationDays,
      permanent: permanent,
      activationDeadline: activationDeadline,
      operatorName: _optionalText(row, hasActivationDeadlineColumn ? 6 : 5),
      remark: _optionalText(row, hasActivationDeadlineColumn ? 7 : 6),
      operation: _parseOperation(
        _requiredText(row, hasActivationDeadlineColumn ? 8 : 7, '操作标记'),
      ),
    );
  }

  String _requiredText(List<Data?> row, int index, String label) {
    final String value = _cellText(index < row.length ? row[index] : null);
    if (value.isEmpty) {
      throw StateError('$label 不能为空');
    }
    return value;
  }

  String? _optionalText(List<Data?> row, int index) {
    final String value = _cellText(index < row.length ? row[index] : null);
    return value.isEmpty ? null : value;
  }

  String _cellText(Data? cell) {
    return cell?.value?.toString().trim() ?? '';
  }

  DateTime _parseDate(String value, String label) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw StateError('$label 格式无效');
    }
    return parsed;
  }

  DateTime? _optionalDate(List<Data?> row, int index, String label) {
    final String value = _cellText(index < row.length ? row[index] : null);
    if (value.isEmpty) {
      return null;
    }
    return _parseDate(value, label);
  }

  int _parseInt(String value, String label) {
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      throw StateError('$label 格式无效');
    }
    return parsed;
  }

  LicenseTier _parseTier(String value) {
    switch (value) {
      case '基础版':
        return LicenseTier.basic;
      case '高级版':
        return LicenseTier.premium;
      case '免费版':
        return LicenseTier.free;
      default:
        throw StateError('授权版本无效：$value');
    }
  }

  LicenseRecordStatus _parseStatus(String value) {
    switch (value) {
      case '有效':
        return LicenseRecordStatus.active;
      case '已作废':
        return LicenseRecordStatus.revoked;
      case '已替代':
        return LicenseRecordStatus.replaced;
      default:
        throw StateError('状态无效：$value');
    }
  }

  bool _parseBool(String value) {
    final String normalized = value.trim().toLowerCase();
    if (<String>{'是', 'true', '1', 'y', 'yes'}.contains(normalized)) {
      return true;
    }
    if (<String>{'否', 'false', '0', 'n', 'no', ''}.contains(normalized)) {
      return false;
    }
    throw StateError('永久授权字段无效：$value');
  }

  _ImportOperation _parseOperation(String value) {
    switch (value.trim().toUpperCase()) {
      case 'I':
        return _ImportOperation.insert;
      case 'U':
        return _ImportOperation.update;
      case 'D':
        return _ImportOperation.delete;
      default:
        throw StateError('操作标记无效：$value');
    }
  }

  _DurationValue _parseDuration(String value) {
    if (value == '永久') {
      return const _DurationValue(permanent: true);
    }
    final String normalized = value.replaceAll('天', '').trim();
    final int? days = int.tryParse(normalized);
    if (days == null || days <= 0) {
      throw StateError('有效期格式无效：$value');
    }
    return _DurationValue(days: days, permanent: false);
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (int i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  bool _isRowEmpty(List<Data?> row) {
    return row.every((Data? cell) => _cellText(cell).isEmpty);
  }
}

enum _ImportOperation {
  insert,
  update,
  delete,
}

class _DurationValue {
  const _DurationValue({
    this.days,
    required this.permanent,
  });

  final int? days;
  final bool permanent;
}

class _BatchGenerateInput {
  const _BatchGenerateInput({
    required this.bindName,
    this.bindUserCode,
    required this.tier,
    required this.durationDays,
    required this.permanent,
    this.activationDeadline,
    this.operatorName,
    this.remark,
    required this.operation,
  });

  final String bindName;
  final String? bindUserCode;
  final LicenseTier tier;
  final int durationDays;
  final bool permanent;
  final DateTime? activationDeadline;
  final String? operatorName;
  final String? remark;
  final _ImportOperation operation;
}
