import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class LicenseDashboardPage extends StatefulWidget {
  const LicenseDashboardPage({super.key, LicenseRecordService? service})
      : _service = service;

  final LicenseRecordService? _service;

  @override
  State<LicenseDashboardPage> createState() => _LicenseDashboardPageState();
}

class _LicenseDashboardPageState extends State<LicenseDashboardPage>
    with HideTransientSnackBarOnRouteChange<LicenseDashboardPage> {
  late final LicenseRecordService _service =
      widget._service ?? LicenseRecordService();
  final LicenseExportService _exportService = LicenseExportService();
  final ExportDirectoryService _exportDirectoryService = ExportDirectoryService();

  Future<LicenseDashboardSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权总览'),
        actions: <Widget>[
          IconButton(
            tooltip: '授权记录',
            onPressed: () => context.push('/records'),
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: '新建授权',
            onPressed: () => context.push('/new'),
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: '私钥设置',
            onPressed: () => context.push('/private-key'),
            icon: const Icon(Icons.key),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<LicenseDashboardSummary>(
        future: _summaryFuture,
        builder: (
          BuildContext context,
          AsyncSnapshot<LicenseDashboardSummary> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载授权总览失败：${snapshot.error}'),
              ),
            );
          }

          final LicenseDashboardSummary summary =
              snapshot.data ??
              const LicenseDashboardSummary(
                totalCount: 0,
                activeCount: 0,
                revokedCount: 0,
                replacedCount: 0,
                basicCount: 0,
                premiumCount: 0,
                permanentCount: 0,
                recentRecords: <LicenseRecordEntity>[],
              );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _HeroCard(
                  totalCount: summary.totalCount,
                  activeCount: summary.activeCount,
                ),
                const SizedBox(height: 16),
                const _SectionTitle(
                  title: '快捷操作',
                  subtitle: '把日常高频动作集中到首页，减少来回切页。',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.add_circle_outline,
                      title: '新增授权',
                      subtitle: '进入表单直接生成授权码',
                      primary: true,
                      onTap: _openNewLicensePage,
                    ),
                    _ActionTile(
                      icon: Icons.list_alt_outlined,
                      title: '查看记录',
                      subtitle: '进入完整授权记录列表',
                      onTap: _openRecordsPage,
                    ),
                    _ActionTile(
                      icon: Icons.download_outlined,
                      title: '导出列表',
                      subtitle: '导出全部授权记录到 .xlsx',
                      onTap: _exportAll,
                    ),
                    _ActionTile(
                      icon: Icons.description_outlined,
                      title: '下载记录模板',
                      subtitle: '导出授权记录导入模板',
                      onTap: _downloadExistingTemplate,
                    ),
                    _ActionTile(
                      icon: Icons.post_add_outlined,
                      title: '下载生码模板',
                      subtitle: '导出批量生码导入模板',
                      onTap: _downloadBatchTemplate,
                    ),
                    _ActionTile(
                      icon: Icons.file_upload_outlined,
                      title: '导入授权记录',
                      subtitle: '从 .xlsx 批量导入已有记录',
                      onTap: _importExistingRecords,
                    ),
                    _ActionTile(
                      icon: Icons.bolt_outlined,
                      title: '批量生码',
                      subtitle: '导入名单并批量生成授权码',
                      onTap: _batchGenerateFromFile,
                    ),
                    _ActionTile(
                      icon: Icons.menu_book_outlined,
                      title: '字段说明',
                      subtitle: '查看导入字段含义与填写要求',
                      onTap: _showImportFieldDialog,
                    ),
                    _ActionTile(
                      icon: Icons.folder_open_outlined,
                      title: '导出目录',
                      subtitle: '调整当前导出目录设置',
                      onTap: _openExportSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: '统计概览',
                  subtitle: '优先查看记录量、状态分布和版本结构。',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatCard(
                      label: '总记录数',
                      value: '${summary.totalCount}',
                      color: const Color(0xFF0C6B61),
                    ),
                    _StatCard(
                      label: '有效授权',
                      value: '${summary.activeCount}',
                      color: Colors.green,
                    ),
                    _StatCard(
                      label: '已作废',
                      value: '${summary.revokedCount}',
                      color: Colors.orange,
                    ),
                    _StatCard(
                      label: '已替代',
                      value: '${summary.replacedCount}',
                      color: Colors.red,
                    ),
                    _StatCard(
                      label: '基础版',
                      value: '${summary.basicCount}',
                      color: Colors.blue,
                    ),
                    _StatCard(
                      label: '高级版',
                      value: '${summary.premiumCount}',
                      color: Colors.deepPurple,
                    ),
                    _StatCard(
                      label: '永久授权',
                      value: '${summary.permanentCount}',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: '最近生成',
                  subtitle: '最近几条记录适合快速核对状态和进入详情。',
                ),
                const SizedBox(height: 12),
                if (summary.recentRecords.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('当前还没有授权记录。可以先从“新增授权”开始。'),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: summary.recentRecords
                          .map(
                            (LicenseRecordEntity record) => InkWell(
                              onTap: () => _openRecordDetail(record.licenseId),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    CircleAvatar(
                                      child: Text(record.bindName.characters.first),
                                    ),
                                    const SizedBox(width: 16),
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
                                          const SizedBox(height: 4),
                                          Text(
                                            '创建时间：${ChineseDateTimeFormatter.formatDateTime(record.createdAt)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
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
                                                : '${record.durationDays ?? 0} 天',
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
                          )
                          .toList(growable: false),
                    ),
                  ),
                const SizedBox(height: 16),
                Column(
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _reload() {
    setState(() {
      _summaryFuture = _service.getDashboardSummary();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _summaryFuture;
  }

  Future<void> _openNewLicensePage() async {
    await context.push('/new');
    if (!mounted) {
      return;
    }
    _reload();
  }

  Future<void> _openRecordsPage() async {
    await context.push('/records');
    if (!mounted) {
      return;
    }
    _reload();
  }

  Future<void> _openRecordDetail(String licenseId) async {
    await context.push('/records/$licenseId');
    if (!mounted) {
      return;
    }
    _reload();
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
      final File file = await _service.exportRecordsAsXlsx(allRecords);
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
      _showFailureSnackBar('导出失败：$error');
    }
  }

  Future<void> _importExistingRecords() async {
    final File? file = await _pickXlsxFile('选择授权记录导入文件');
    if (file == null) {
      return;
    }
    try {
      _assertTemplateFileName(
        file: file,
        requiredBaseName: LicenseImportService.existingRecordTemplateFileBaseName,
      );
      final LicenseImportResult result = await _service.importExistingRecords(file);
      if (!mounted) {
        return;
      }
      _reload();
      await _showImportResultDialog(title: '导入授权记录结果', result: result);
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
        file: file,
        requiredBaseName: LicenseImportService.batchGenerateTemplateFileBaseName,
      );
      final LicenseImportResult result = await _service.batchGenerateFromFile(file);
      if (!mounted) {
        return;
      }
      _reload();
      await _showImportResultDialog(title: '批量生码结果', result: result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showFailureSnackBar('批量生码导入失败：$error');
    }
  }

  Future<void> _downloadBatchTemplate() async {
    try {
      final File file = await _service.exportBatchGenerateTemplate();
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
      final File file = await _service.exportExistingRecordTemplate();
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
                            .map(
                              (String failure) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $failure'),
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
                  Text('6. 状态：必填，只允许有效 / 已作废 / 已替代。'),
                  Text('7. 发码时间：必填，使用可被系统解析的日期时间。'),
                  Text('8. 创建时间：必填，表示记录创建时间。'),
                  Text('9. 更新时间：必填，表示记录最后更新时间。'),
                  Text('10. 操作人：选填，记录生成或维护人。'),
                  Text('11. 备注：选填，补充说明。'),
                  Text('12. 授权码：必填，导入已有授权记录时必须保留原始授权码。'),
                  Text('13. 操作标记：必填，只允许 I / U / D。'),
                  SizedBox(height: 12),
                  Text('批量生码导入字段'),
                  SizedBox(height: 8),
                  Text('1. 绑定用户：必填，用于生成授权记录时的绑定名称。'),
                  Text('2. 用户编号：选填，用于内部识别。'),
                  Text('3. 授权版本：必填，只允许免费版 / 基础版 / 高级版。'),
                  Text('4. 有效期天数：永久授权为“否”时必填，且必须大于 0。'),
                  Text('5. 永久授权：必填，填写 是 / 否 或兼容 true / false。'),
                  Text('6. 操作人：选填，记录批量生成责任人。'),
                  Text('7. 备注：选填，补充说明。'),
                  Text('8. 操作标记：必填，当前批量生码导入仅支持 I。'),
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

  void _assertTemplateFileName({
    required File file,
    required String requiredBaseName,
  }) {
    final String fileName = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    final String lowerName = fileName.toLowerCase();
    if (!lowerName.endsWith('.xlsx')) {
      throw StateError('仅支持导入 .xlsx 文件');
    }
    if (!lowerName.contains(requiredBaseName.toLowerCase())) {
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalCount,
    required this.activeCount,
  });

  final int totalCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFECF8F5),
            Color(0xFFF6FBFA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '授权管理总览',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前共维护 $totalCount 条授权记录，其中 $activeCount 条处于有效状态。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        color: primary ? colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
