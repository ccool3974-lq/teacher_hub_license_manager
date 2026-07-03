import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_export_service.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/shared/chinese_date_time_formatter.dart';
import 'package:teacher_hub_license_manager/shared/navigation/app_route_observer.dart';
import 'package:teacher_hub_license_manager/shared/transient_snack_bar.dart';

class LicenseDetailPage extends StatefulWidget {
  const LicenseDetailPage({
    super.key,
    required this.licenseId,
    LicenseRecordService? service,
  }) : _service = service;

  final String licenseId;
  final LicenseRecordService? _service;

  @override
  State<LicenseDetailPage> createState() => _LicenseDetailPageState();
}

class _LicenseDetailPageState extends State<LicenseDetailPage>
    with HideTransientSnackBarOnRouteChange<LicenseDetailPage> {
  late final LicenseRecordService _service =
      widget._service ?? LicenseRecordService();
  final LicenseExportService _exportService = LicenseExportService();
  late Future<LicenseRecordEntity?> _recordFuture = _service.getRecord(
    widget.licenseId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权详情'),
        actions: <Widget>[
          IconButton(
            tooltip: '授权总览',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.dashboard_outlined),
          ),
          IconButton(
            tooltip: '授权记录',
            onPressed: () => context.go('/records'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: FutureBuilder<LicenseRecordEntity?>(
        future: _recordFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<LicenseRecordEntity?> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('加载授权详情失败：${snapshot.error}'));
              }

              final LicenseRecordEntity? record = snapshot.data;
              if (record == null) {
                return const Center(child: Text('未找到对应的授权记录。'));
              }

              return ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  _InfoCard(
                    title: '基本信息',
                    rows: <_InfoRow>[
                      _InfoRow('授权编号', record.licenseId),
                      _InfoRow('应用版本号', record.appVersion),
                      _InfoRow('绑定用户', record.bindName),
                      _InfoRow('用户编号', record.bindUserCode ?? '未填写'),
                      _InfoRow(
                        '有效期',
                        record.permanent ? '永久' : '${record.durationDays} 天',
                      ),
                      _InfoRow(
                        '首次激活截止',
                        _formatDateTime(record.activationDeadline),
                      ),
                      _InfoRow('状态', _statusLabel(record.status)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '状态管理',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: LicenseRecordStatus.values
                                .map((LicenseRecordStatus status) {
                                  return ChoiceChip(
                                    label: Text(_statusLabel(status)),
                                    selected: record.status == status,
                                    onSelected: (bool selected) {
                                      if (!selected ||
                                          record.status == status) {
                                        return;
                                      }
                                      _changeStatus(status);
                                    },
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: '记录信息',
                    rows: <_InfoRow>[
                      _InfoRow('发码时间', _formatDateTime(record.issuedAt)),
                      _InfoRow('创建时间', _formatDateTime(record.createdAt)),
                      _InfoRow('更新时间', _formatDateTime(record.updatedAt)),
                      _InfoRow('操作人', record.operatorName ?? '未填写'),
                      _InfoRow('备注', record.remark ?? '未填写'),
                      _InfoRow(
                        '最近导出时间',
                        record.exportedAt == null
                            ? '未导出'
                            : _formatDateTime(record.exportedAt!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text(
                                '离线密钥',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: record.rawLicense),
                                      );
                                      if (!context.mounted) {
                                        return;
                                      }
                                      showTransientSnackBar(
                                        context,
                                        const SnackBar(
                                          content: Text('离线密钥已复制。'),
                                          duration: Duration(seconds: 5),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy),
                                    label: const Text('复制'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        final file = await _service
                                            .exportRecordAsText(record);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        showTransientSnackBar(
                                          context,
                                          SnackBar(
                                            content: Text(
                                              '授权文件已导出到：${file.path}',
                                            ),
                                            duration: const Duration(
                                              seconds: 5,
                                            ),
                                            action: SnackBarAction(
                                              label: '打开目录',
                                              onPressed: () {
                                                _exportService
                                                    .openExportDirectory();
                                              },
                                            ),
                                          ),
                                        );
                                        setState(() {
                                          _recordFuture = _service.getRecord(
                                            widget.licenseId,
                                          );
                                        });
                                      } catch (error) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        showTransientSnackBar(
                                          context,
                                          SnackBar(
                                            content: Text('导出失败：$error'),
                                            duration: const Duration(
                                              seconds: 5,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.download),
                                    label: const Text('导出'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SelectableText(record.rawLicense),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Future<void> _changeStatus(LicenseRecordStatus status) async {
    try {
      final LicenseRecordEntity? updated = await _service.updateRecordStatus(
        licenseId: widget.licenseId,
        status: status,
      );
      if (!mounted) {
        return;
      }
      if (updated == null) {
        showTransientSnackBar(
          context,
          const SnackBar(
            content: Text('未找到可更新的授权记录。'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      setState(() {
        _recordFuture = Future<LicenseRecordEntity?>.value(updated);
      });
      showTransientSnackBar(
        context,
        SnackBar(
          content: Text('状态已更新为：${_statusLabel(status)}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showTransientSnackBar(
        context,
        SnackBar(
          content: Text('状态更新失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _statusLabel(LicenseRecordStatus status) {
    return switch (status) {
      LicenseRecordStatus.active => '有效',
      LicenseRecordStatus.revoked => '已作废',
      LicenseRecordStatus.replaced => '已替代',
    };
  }

  String _formatDateTime(DateTime value) {
    return ChineseDateTimeFormatter.formatDateTime(value);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (_InfoRow row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}
