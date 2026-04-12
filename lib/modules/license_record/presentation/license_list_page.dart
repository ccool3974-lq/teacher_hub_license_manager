import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:teacher_hub_license_manager/app/export_directory_settings_dialog.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_import_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/shared/chinese_date_time_formatter.dart';
import 'package:teacher_hub_license_manager/shared/navigation/app_route_observer.dart';
import 'package:teacher_hub_license_manager/shared/transient_snack_bar.dart';
import 'package:teacher_toolkit_license_protocol/teacher_toolkit_license_protocol.dart';

class LicenseListPage extends StatefulWidget {
  const LicenseListPage({super.key, LicenseRecordService? service})
      : _service = service;

  final LicenseRecordService? _service;

  @override
  State<LicenseListPage> createState() => _LicenseListPageState();
}

class _LicenseListPageState extends State<LicenseListPage>
    with HideTransientSnackBarOnRouteChange<LicenseListPage> {
  late final LicenseRecordService _service =
      widget._service ?? LicenseRecordService();
  final LicenseExportService _exportService = LicenseExportService();
  final ExportDirectoryService _exportDirectoryService = ExportDirectoryService();
  final TextEditingController _searchController = TextEditingController();

  Future<List<LicenseRecordEntity>>? _recordsFuture;
  String _query = '';
  LicenseRecordStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权记录'),
        actions: <Widget>[
          IconButton(
            tooltip: '授权总览',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.dashboard_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: '批量操作',
            onSelected: _handleBatchAction,
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'show_fields',
                child: Text('导入字段说明'),
              ),
              PopupMenuItem<String>(
                value: 'show_rules',
                child: Text('导入规则说明'),
              ),
              PopupMenuItem<String>(
                value: 'import_existing',
                child: Text('导入授权记录'),
              ),
              PopupMenuItem<String>(
                value: 'batch_generate',
                child: Text('批量生码导入'),
              ),
              PopupMenuItem<String>(
                value: 'download_existing_template',
                child: Text('下载授权记录模板'),
              ),
              PopupMenuItem<String>(
                value: 'download_batch_template',
                child: Text('下载批量生码模板'),
              ),
            ],
            icon: const Icon(Icons.playlist_add_check),
          ),
          IconButton(
            tooltip: '私钥设置',
            onPressed: () => context.go('/private-key'),
            icon: const Icon(Icons.key),
          ),
          IconButton(
            tooltip: '导出目录设置',
            onPressed: _openExportSettings,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: '导出列表',
            onPressed: _exportAll,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: <Widget>[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('导入规则说明'),
                    subtitle: const Text(
                      '导入和导出统一使用 .xlsx，文件名允许扩写但必须包含系统下载模板名，单次最多 1000 条。',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showImportRulesDialog,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('导入字段说明'),
                    subtitle: const Text('查看授权记录导入和批量生码导入的字段含义、是否必填与填写要求。'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showImportFieldDialog,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索绑定用户、授权编号、操作人',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (String value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('全部状态'),
                  selected: _selectedStatus == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...LicenseRecordStatus.values.map(
                  (LicenseRecordStatus status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_statusLabel(status)),
                      selected: _selectedStatus == status,
                      onSelected: (_) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    await context.push('/new');
                    if (!mounted) {
                      return;
                    }
                    _reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('新增授权'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<LicenseRecordEntity>>(
              future: _recordsFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<List<LicenseRecordEntity>> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('加载授权记录失败：${snapshot.error}'),
                    ),
                  );
                }

                final List<LicenseRecordEntity> records =
                    _filter(snapshot.data ?? const <LicenseRecordEntity>[]);
                if (records.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty && _selectedStatus == null
                          ? '暂无授权记录。'
                          : '没有匹配的授权记录。',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: records.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final LicenseRecordEntity record = records[index];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await context.push('/records/${record.licenseId}');
                          if (!mounted) {
                            return;
                          }
                          _reload();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      record.bindName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_tierLabel(record.tier)} · ${record.licenseId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                    if (record.operatorName case final String operatorName
                                        when operatorName.trim().isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        '操作人：$operatorName',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 116),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      _statusLabel(record.status),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      record.permanent
                                          ? '永久'
                                          : '${record.durationDays} 天',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '激活截止 ${ChineseDateTimeFormatter.formatDateTime(record.activationDeadline)}',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.listRecords();
    });
  }

  List<LicenseRecordEntity> _filter(List<LicenseRecordEntity> records) {
    return records.where((LicenseRecordEntity record) {
      if (_selectedStatus != null && record.status != _selectedStatus) {
        return false;
      }
      if (_query.isEmpty) {
        return true;
      }

      final String haystack = <String?>[
        record.bindName,
        record.licenseId,
        record.operatorName,
        record.bindUserCode,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_query);
    }).toList(growable: false);
  }

  Future<void> _openExportSettings() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ExportDirectorySettingsDialog(service: _exportDirectoryService);
      },
    );
    if (changed == true && mounted) {
      showTransientSnackBar(
        context,
        const SnackBar(
          content: Text('导出目录已更新'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _exportAll() async {
    final List<LicenseRecordEntity> allRecords = await _service.listRecords();
    if (allRecords.isEmpty) {
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        const SnackBar(
          content: Text('暂无可导出的授权记录。'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      final file = await _service.exportRecordsAsXlsx(allRecords);
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        SnackBar(
            content: Text('导出完成，共 ${allRecords.length} 条，文件位置：${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '打开目录',
              onPressed: () {
                _exportService.openExportDirectory();
              },
            ),
          ),
      );
      _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        SnackBar(
          content: Text('导出失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleBatchAction(String action) async {
    switch (action) {
      case 'show_fields':
        await _showImportFieldDialog();
        return;
      case 'show_rules':
        await _showImportRulesDialog();
        return;
      case 'import_existing':
        await _importExistingRecords();
        return;
      case 'batch_generate':
        await _batchGenerateFromFile();
        return;
      case 'download_existing_template':
        await _downloadExistingTemplate();
        return;
      case 'download_batch_template':
        await _downloadBatchTemplate();
        return;
    }
  }

  Future<void> _importExistingRecords() async {
    final File? file = await _pickXlsxFile('选择授权记录导入文件');
    if (file == null) {
      return;
    }
    try {
      _assertTemplateFileName(
        file,
        requiredBaseName: LicenseImportService.existingRecordTemplateFileBaseName,
      );
      final LicenseImportResult result = await _service.importExistingRecords(file);
      if (!mounted) {
        return;
      }
      _reload();
      await _showImportResultDialog(
        title: '导入授权记录结果',
        result: result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailureSnackBar('导入授权记录失败：$error');
    }
  }

  Future<void> _batchGenerateFromFile() async {
    final File? file = await _pickXlsxFile('选择批量生码导入文件');
    if (file == null) {
      return;
    }
    try {
      _assertTemplateFileName(
        file,
        requiredBaseName: LicenseImportService.batchGenerateTemplateFileBaseName,
      );
      final LicenseImportResult result = await _service.batchGenerateFromFile(file);
      if (!mounted) {
        return;
      }
      _reload();
      await _showImportResultDialog(
        title: '批量生码结果',
        result: result,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailureSnackBar('批量生码导入失败：$error');
    }
  }

  Future<void> _downloadBatchTemplate() async {
    try {
      final file = await _service.exportBatchGenerateTemplate();
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        SnackBar(
            content: Text('模板已导出到：${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '打开目录',
              onPressed: () {
                _exportService.openExportDirectory();
              },
            ),
          ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailureSnackBar('导出模板失败：$error');
    }
  }

  Future<void> _downloadExistingTemplate() async {
    try {
      final file = await _service.exportExistingRecordTemplate();
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        SnackBar(
            content: Text('模板已导出到：${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '打开目录',
              onPressed: () {
                _exportService.openExportDirectory();
              },
            ),
          ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailureSnackBar('导出模板失败：$error');
    }
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
            width: 520,
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
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.failures
                            .map((String failure) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text('• $failure'),
                                ))
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

  Future<void> _showImportRulesDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('导入规则说明'),
          content: const SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('通用规则'),
                  SizedBox(height: 8),
                  Text('1. 所有导入模板统一使用 .xlsx。'),
                  Text('2. 所有导出文件统一使用 .xlsx。'),
                  Text('3. 操作标记固定在最后一列。'),
                  Text('4. 导出时操作标记默认写为 I。'),
                  Text('5. 单次导入最多 1000 条。'),
                  Text('6. 导入失败原因会完整展示。'),
                  Text('7. 导入列数不能多于模板字段个数。'),
                  Text('8. 文件名允许扩写，但必须包含系统下载模板名。'),
                  SizedBox(height: 12),
                  Text('授权记录导入规则'),
                  SizedBox(height: 8),
                  Text('1. 使用“下载授权记录模板”生成的标准模板。'),
                  Text('2. 文件名必须包含 license_record_import_template。'),
                  Text('3. I：授权编号必须不存在。'),
                  Text('4. U：授权编号必须已存在。'),
                  Text('5. D：授权编号必须已存在。'),
                  SizedBox(height: 12),
                  Text('批量生码导入规则'),
                  SizedBox(height: 8),
                  Text('1. 使用“下载批量生码模板”生成的标准模板。'),
                  Text('2. 文件名必须包含 license_batch_generate_template。'),
                  Text('3. 当前批量生码导入仅支持操作标记 I。'),
                  Text('4. 系统会自动生成新的授权编号和授权码。'),
                  SizedBox(height: 12),
                  Text('操作标记规则'),
                  SizedBox(height: 8),
                  Text('1. 只允许 I / U / D。'),
                  Text('2. I：目标记录必须不存在。'),
                  Text('3. U：目标记录必须已存在。'),
                  Text('4. D：目标记录必须已存在。'),
                ],
              ),
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

  Future<void> _showImportFieldDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('导入字段说明'),
          content: const SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('授权记录导入字段'),
                  SizedBox(height: 8),
                  Text('1. 授权编号：必填，业务唯一键，用于 I/U/D 判断目标记录。'),
                  Text('2. 绑定用户：必填，客户端显示的绑定名称。'),
                  Text('3. 用户编号：选填，用于内部标识用户或机构编号。'),
                  Text('4. 授权版本：必填，只允许免费版 / 基础版 / 高级版。'),
                  Text('5. 有效期：必填，填写“永久”或天数。'),
                  Text('6. 首次激活截止：选填，旧模板可不填；新模板建议填写可被系统解析的日期时间。'),
                  Text('7. 状态：必填，只允许有效 / 已作废 / 已替代。'),
                  Text('8. 发码时间：必填，使用可被系统解析的日期时间。'),
                  Text('9. 创建时间：必填，表示记录创建时间。'),
                  Text('10. 更新时间：必填，表示记录最后更新时间。'),
                  Text('11. 操作人：选填，记录生成或维护人。'),
                  Text('12. 备注：选填，补充说明。'),
                  Text('13. 授权码：必填，导入已有授权记录时必须保留原始授权码。'),
                  Text('14. 操作标记：必填，只允许 I / U / D。'),
                  SizedBox(height: 12),
                  Text('批量生码导入字段'),
                  SizedBox(height: 8),
                  Text('1. 绑定用户：必填，用于生成授权记录时的绑定名称。'),
                  Text('2. 用户编号：选填，用于内部识别。'),
                  Text('3. 授权版本：必填，只允许免费版 / 基础版 / 高级版。'),
                  Text('4. 有效期天数：永久授权为“否”时必填，且必须大于 0。'),
                  Text('5. 永久授权：必填，填写 是 / 否 或兼容 true / false。'),
                  Text('6. 首次激活截止日期：选填，留空时默认取发码时间后 30 天。'),
                  Text('7. 操作人：选填，记录批量生成责任人。'),
                  Text('8. 备注：选填，补充说明。'),
                  Text('9. 操作标记：必填，当前批量生码导入仅支持 I。'),
                ],
              ),
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

  void _showFailureSnackBar(String message) {
    showTransientSnackBar(
      context,
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _assertTemplateFileName(File file, {required String requiredBaseName}) {
    final String baseName =
        p.basenameWithoutExtension(file.path).trim().toLowerCase();
    if (!baseName.contains(requiredBaseName.toLowerCase())) {
      throw StateError('导入文件名必须包含模板名“$requiredBaseName”，请基于最新下载模板填写后再导入。');
    }
  }

  String _tierLabel(LicenseTier tier) {
    return switch (tier) {
      LicenseTier.free => '免费版',
      LicenseTier.basic => '基础版',
      LicenseTier.premium => '高级版',
    };
  }

  String _statusLabel(LicenseRecordStatus status) {
    return switch (status) {
      LicenseRecordStatus.active => '有效',
      LicenseRecordStatus.revoked => '已作废',
      LicenseRecordStatus.replaced => '已替代',
    };
  }
}
