import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_import_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/shared/transient_snack_bar.dart';

class LicenseImportAssistantDialog extends StatefulWidget {
  const LicenseImportAssistantDialog({
    super.key,
    required this.service,
    required this.exportService,
    this.onChanged,
  });

  final LicenseRecordService service;
  final LicenseExportService exportService;
  final VoidCallback? onChanged;

  @override
  State<LicenseImportAssistantDialog> createState() =>
      _LicenseImportAssistantDialogState();
}

class _LicenseImportAssistantDialogState
    extends State<LicenseImportAssistantDialog> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入与模板助手'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _AssistantSection(
                title: '授权记录导入',
                subtitle:
                    '用于导入已有授权记录，支持 I / U / D。I 要求授权编号不存在，U / D 要求授权编号已存在。',
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _working ? null : _downloadExistingTemplate,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('下载授权记录模板'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _working ? null : _importExistingRecords,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('导入授权记录'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AssistantSection(
                title: '批量生码导入',
                subtitle: '用于导入名单并生成新授权码，当前只支持操作标记 I，系统会自动生成授权编号和授权码。',
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _working ? null : _downloadBatchTemplate,
                    icon: const Icon(Icons.post_add_outlined),
                    label: const Text('下载批量生码模板'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _working ? null : _batchGenerateFromFile,
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('批量生码导入'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _RulesAndFields(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Future<void> _withWorking(Future<void> Function() action) async {
    setState(() {
      _working = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _downloadExistingTemplate() {
    return _withWorking(() async {
      try {
        final File file = await widget.service.exportExistingRecordTemplate();
        if (!mounted) {
          return;
        }
        _showSuccessWithDirectoryAction('授权记录模板已导出到：${file.path}');
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showFailureSnackBar('导出授权记录模板失败：$error');
      }
    });
  }

  Future<void> _downloadBatchTemplate() {
    return _withWorking(() async {
      try {
        final File file = await widget.service.exportBatchGenerateTemplate();
        if (!mounted) {
          return;
        }
        _showSuccessWithDirectoryAction('批量生码模板已导出到：${file.path}');
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showFailureSnackBar('导出批量生码模板失败：$error');
      }
    });
  }

  Future<void> _importExistingRecords() {
    return _withWorking(() async {
      final File? file = await _pickXlsxFile('选择授权记录导入文件');
      if (file == null) {
        return;
      }
      try {
        _assertTemplateFileName(
          file,
          requiredBaseName:
              LicenseImportService.existingRecordTemplateFileBaseName,
        );
        final LicenseImportResult result = await widget.service
            .importExistingRecords(file);
        if (!mounted) {
          return;
        }
        widget.onChanged?.call();
        await _showImportResultDialog(title: '导入授权记录结果', result: result);
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showFailureSnackBar('导入授权记录失败：$error');
      }
    });
  }

  Future<void> _batchGenerateFromFile() {
    return _withWorking(() async {
      final File? file = await _pickXlsxFile('选择批量生码导入文件');
      if (file == null) {
        return;
      }
      try {
        _assertTemplateFileName(
          file,
          requiredBaseName:
              LicenseImportService.batchGenerateTemplateFileBaseName,
        );
        final LicenseImportResult result = await widget.service
            .batchGenerateFromFile(file);
        if (!mounted) {
          return;
        }
        widget.onChanged?.call();
        await _showImportResultDialog(title: '批量生码结果', result: result);
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showFailureSnackBar('批量生码导入失败：$error');
      }
    });
  }

  Future<File?> _pickXlsxFile(String dialogTitle) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: const <String>['xlsx'],
      withData: false,
      lockParentWindow: true,
    );
    final String? path = result?.files.single.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path);
  }

  Future<void> _showImportResultDialog({
    required String title,
    required LicenseImportResult result,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('总条数：${result.totalRows}'),
                Text('成功：${result.successCount}'),
                Text('失败：${result.failureCount}'),
                if (result.failures.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text('错误明细：'),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.failures
                            .map(
                              (String failure) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('- $failure'),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessWithDirectoryAction(String message) {
    showTransientSnackBar(
      context,
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '打开目录',
          onPressed: () {
            widget.exportService.openExportDirectory();
          },
        ),
      ),
    );
  }

  void _showFailureSnackBar(String message) {
    showTransientSnackBar(
      context,
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  void _assertTemplateFileName(File file, {required String requiredBaseName}) {
    final String baseName = p
        .basenameWithoutExtension(file.path)
        .trim()
        .toLowerCase();
    if (!baseName.contains(requiredBaseName.toLowerCase())) {
      throw StateError('导入文件名必须包含模板名“$requiredBaseName”，请基于最新下载模板填写后再导入。');
    }
  }
}

class _AssistantSection extends StatelessWidget {
  const _AssistantSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: children),
        ],
      ),
    );
  }
}

class _RulesAndFields extends StatelessWidget {
  const _RulesAndFields();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('导入规则说明', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('1. 所有导入模板统一使用 .xlsx。'),
        Text('2. 所有导出文件统一使用 .xlsx，操作标记固定在最后一列，导出时默认写为 I。'),
        Text('3. 单次导入最多 1000 条，导入失败原因会完整展示。'),
        Text('4. 导入列数不能多于模板字段个数。'),
        Text('5. 文件名允许扩写，但必须包含系统下载模板名。'),
        SizedBox(height: 16),
        Text('字段说明', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text(
          '授权记录导入：授权编号、绑定用户、有效期、首次激活截止、状态、发码时间、创建时间、更新时间、授权码、操作标记为必填；用户编号、操作人、备注为选填。',
        ),
        SizedBox(height: 8),
        Text(
          '批量生码导入：绑定用户、有效期天数、永久授权、操作标记为必填；用户编号、首次激活截止日期、操作人、备注为选填。永久授权为“否”时有效期天数必须大于 0。',
        ),
        SizedBox(height: 8),
        Text('操作标记：授权记录导入支持 I / U / D；批量生码导入当前只支持 I。'),
      ],
    );
  }
}
