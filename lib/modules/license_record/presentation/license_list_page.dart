import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_hub_license_manager/app/export_directory_settings_dialog.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/presentation/widgets/license_import_assistant_dialog.dart';
import 'package:teacher_hub_license_manager/shared/chinese_date_time_formatter.dart';
import 'package:teacher_hub_license_manager/shared/navigation/app_route_observer.dart';
import 'package:teacher_hub_license_manager/shared/transient_snack_bar.dart';

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
  final ExportDirectoryService _exportDirectoryService =
      ExportDirectoryService();
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
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'assistant',
                    child: Text('导入与模板助手'),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索绑定用户、授权编号、应用版本号、操作人',
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openImportAssistant,
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('批量维护'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<LicenseRecordEntity>>(
              future: _recordsFuture,
              builder:
                  (
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

                    final List<LicenseRecordEntity> records = _filter(
                      snapshot.data ?? const <LicenseRecordEntity>[],
                    );
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
                              await context.push(
                                '/records/${record.licenseId}',
                              );
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          '离线密钥 · ${record.licenseId} · ${record.appVersion}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge,
                                        ),
                                        if (record.operatorName
                                            case final String operatorName
                                            when operatorName
                                                .trim()
                                                .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 4),
                                          Text(
                                            '操作人：$operatorName',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 116,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '激活截止 ${ChineseDateTimeFormatter.formatDateTime(record.activationDeadline)}',
                                          textAlign: TextAlign.right,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
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
    return records
        .where((LicenseRecordEntity record) {
          if (_selectedStatus != null && record.status != _selectedStatus) {
            return false;
          }
          if (_query.isEmpty) {
            return true;
          }

          final String haystack = <String?>[
            record.bindName,
            record.licenseId,
            record.appVersion,
            record.operatorName,
            record.bindUserCode,
          ].whereType<String>().join(' ').toLowerCase();
          return haystack.contains(_query);
        })
        .toList(growable: false);
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
      case 'assistant':
        await _openImportAssistant();
        return;
    }
  }

  Future<void> _openImportAssistant() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return LicenseImportAssistantDialog(
          service: _service,
          exportService: _exportService,
          onChanged: _reload,
        );
      },
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
