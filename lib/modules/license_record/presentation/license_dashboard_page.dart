import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_hub_license_manager/app/export_directory_settings_dialog.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_storage_service.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/widgets/license_import_assistant_dialog.dart';
import 'package:teacher_hub_license_manager/shared/chinese_date_time_formatter.dart';
import 'package:teacher_hub_license_manager/shared/navigation/app_route_observer.dart';
import 'package:teacher_hub_license_manager/shared/transient_snack_bar.dart';

class LicenseDashboardPage extends StatefulWidget {
  const LicenseDashboardPage({
    super.key,
    LicenseRecordService? service,
    PrivateKeyStorageService? privateKeyStorageService,
  }) : _service = service,
       _privateKeyStorageService = privateKeyStorageService;

  final LicenseRecordService? _service;
  final PrivateKeyStorageService? _privateKeyStorageService;

  @override
  State<LicenseDashboardPage> createState() => _LicenseDashboardPageState();
}

class _LicenseDashboardPageState extends State<LicenseDashboardPage>
    with HideTransientSnackBarOnRouteChange<LicenseDashboardPage> {
  late final LicenseRecordService _service =
      widget._service ?? LicenseRecordService();
  late final PrivateKeyStorageService _privateKeyStorageService =
      widget._privateKeyStorageService ?? PrivateKeyStorageService();
  final LicenseExportService _exportService = LicenseExportService();
  final ExportDirectoryService _exportDirectoryService =
      ExportDirectoryService();

  Future<_DashboardData>? _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权运营工作台'),
        actions: <Widget>[
          IconButton(
            tooltip: '授权记录',
            onPressed: _openRecordsPage,
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: '导入与模板助手',
            onPressed: _openImportAssistant,
            icon: const Icon(Icons.rule_folder_outlined),
          ),
          IconButton(
            tooltip: '私钥设置',
            onPressed: () => context.push('/private-key'),
            icon: const Icon(Icons.key),
          ),
          IconButton(
            tooltip: '导出目录设置',
            onPressed: _openExportSettings,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return FutureBuilder<_DashboardData>(
            future: _dashboardFuture,
            builder:
                (BuildContext context, AsyncSnapshot<_DashboardData> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('加载授权运营工作台失败：${snapshot.error}'),
                      ),
                    );
                  }

                  final _DashboardData data =
                      snapshot.data ??
                      const _DashboardData(
                        hasPrivateKey: false,
                        summary: LicenseDashboardSummary(
                          totalCount: 0,
                          activeCount: 0,
                          revokedCount: 0,
                          replacedCount: 0,
                          permanentCount: 0,
                          unexportedCount: 0,
                          activationDeadlineWarningCount: 0,
                          todayCreatedCount: 0,
                          recentRecords: <LicenseRecordEntity>[],
                        ),
                      );
                  final bool wide = constraints.maxWidth >= 980;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _PrivateKeyStatusBanner(
                                  hasPrivateKey: data.hasPrivateKey,
                                  onConfigure: () =>
                                      context.push('/private-key'),
                                ),
                                const SizedBox(height: 16),
                                _MetricsGrid(summary: data.summary),
                                const SizedBox(height: 16),
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        flex: 5,
                                        child: _OperationsPanel(
                                          onCreate: _openNewLicensePage,
                                          onBatchGenerate: _openImportAssistant,
                                          onViewRecords: _openRecordsPage,
                                          onExport: _exportAll,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 6,
                                        child: _RecentRecordsSection(
                                          records: data.summary.recentRecords,
                                          onViewAll: _openRecordsPage,
                                          onOpenRecord: _openRecordDetail,
                                        ),
                                      ),
                                    ],
                                  )
                                else ...<Widget>[
                                  _OperationsPanel(
                                    onCreate: _openNewLicensePage,
                                    onBatchGenerate: _openImportAssistant,
                                    onViewRecords: _openRecordsPage,
                                    onExport: _exportAll,
                                  ),
                                  const SizedBox(height: 16),
                                  _RecentRecordsSection(
                                    records: data.summary.recentRecords,
                                    onViewAll: _openRecordsPage,
                                    onOpenRecord: _openRecordDetail,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
          );
        },
      ),
    );
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  Future<_DashboardData> _loadDashboardData() async {
    final LicenseDashboardSummary summary = await _service
        .getDashboardSummary();
    final File? storedKeyFile = await _privateKeyStorageService
        .getStoredKeyFile();
    return _DashboardData(
      hasPrivateKey: storedKeyFile != null,
      summary: summary,
    );
  }

  Future<void> _refresh() async {
    _reload();
    await _dashboardFuture;
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

  Future<void> _openImportAssistant() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return LicenseImportAssistantDialog(
          service: _service,
          exportService: _exportService,
          onChanged: _reload,
        );
      },
    );
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
      showTransientSnackBar(
        context,
        SnackBar(
          content: Text('导出失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _DashboardData {
  const _DashboardData({required this.hasPrivateKey, required this.summary});

  final bool hasPrivateKey;
  final LicenseDashboardSummary summary;
}

class _PrivateKeyStatusBanner extends StatelessWidget {
  const _PrivateKeyStatusBanner({
    required this.hasPrivateKey,
    required this.onConfigure,
  });

  final bool hasPrivateKey;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color background = hasPrivateKey
        ? colorScheme.surfaceContainerHighest
        : colorScheme.errorContainer;
    final Color foreground = hasPrivateKey
        ? colorScheme.onSurface
        : colorScheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hasPrivateKey ? Icons.verified_user_outlined : Icons.warning_amber,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasPrivateKey ? '私钥已配置，可以生成授权码' : '未配置私钥，暂时无法生成授权码',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.key),
            label: Text(hasPrivateKey ? '查看私钥设置' : '配置私钥'),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final LicenseDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 680
            ? 3
            : 2;
        final double spacing = 12;
        final double width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            _MetricCard(
              width: width,
              label: '授权记录总数',
              value: '${summary.totalCount}',
              helper: '全部离线密钥',
            ),
            _MetricCard(
              width: width,
              label: '有效授权数',
              value: '${summary.activeCount}',
              helper:
                  '作废 ${summary.revokedCount} · 替代 ${summary.replacedCount}',
            ),
            _MetricCard(
              width: width,
              label: '未导出记录数',
              value: '${summary.unexportedCount}',
              helper: '待备份或交付',
              emphasis: summary.unexportedCount > 0,
            ),
            _MetricCard(
              width: width,
              label: '7 天内激活截止',
              value: '${summary.activationDeadlineWarningCount}',
              helper: '仅统计有效授权',
              warning: summary.activationDeadlineWarningCount > 0,
            ),
            _MetricCard(
              width: width,
              label: '今日生成',
              value: '${summary.todayCreatedCount}',
              helper: '永久 ${summary.permanentCount}',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.helper,
    this.emphasis = false,
    this.warning = false,
  });

  final double width;
  final String label;
  final String value;
  final String helper;
  final bool emphasis;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color valueColor = warning
        ? colorScheme.error
        : emphasis
        ? colorScheme.primary
        : colorScheme.onSurface;
    return SizedBox(
      width: width,
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
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(helper, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.onCreate,
    required this.onBatchGenerate,
    required this.onViewRecords,
    required this.onExport,
  });

  final VoidCallback onCreate;
  final VoidCallback onBatchGenerate;
  final VoidCallback onViewRecords;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '主操作',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('新增授权'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onBatchGenerate,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('批量生码'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onViewRecords,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('查看记录'),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导出列表'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRecordsSection extends StatelessWidget {
  const _RecentRecordsSection({
    required this.records,
    required this.onViewAll,
    required this.onOpenRecord,
  });

  final List<LicenseRecordEntity> records;
  final VoidCallback onViewAll;
  final void Function(String licenseId) onOpenRecord;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '最近生成记录',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('当前还没有授权记录。可以先从“新增授权”开始。'),
              )
            else
              ...records.map(
                (LicenseRecordEntity record) => _RecentRecordTile(
                  record: record,
                  onTap: () => onOpenRecord(record.licenseId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentRecordTile extends StatelessWidget {
  const _RecentRecordTile({required this.record, required this.onTap});

  final LicenseRecordEntity record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.bindName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('授权编号：${record.licenseId}'),
                  const SizedBox(height: 4),
                  Text('应用版本号：${record.appVersion}'),
                  const SizedBox(height: 4),
                  Text(
                    '首次激活截止：${ChineseDateTimeFormatter.formatDateTime(record.activationDeadline)}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _statusLabel(record.status),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(record.permanent ? '永久' : '${record.durationDays} 天'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(LicenseRecordStatus status) {
    return switch (status) {
      LicenseRecordStatus.active => '有效',
      LicenseRecordStatus.revoked => '已作废',
      LicenseRecordStatus.replaced => '已替代',
    };
  }
}
