import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_hub_license_manager/modules/license_record/data/license_record_entity.dart';
import 'package:teacher_hub_license_manager/modules/license_record/domain/license_record_service.dart';
import 'package:teacher_hub_license_manager/shared/chinese_date_time_formatter.dart';

class LicenseFormPage extends StatefulWidget {
  const LicenseFormPage({super.key, LicenseRecordService? service})
    : _service = service;

  final LicenseRecordService? _service;

  @override
  State<LicenseFormPage> createState() => _LicenseFormPageState();
}

class _LicenseFormPageState extends State<LicenseFormPage> {
  static const List<int> _presetDurationOptions = <int>[30, 180, 365];

  late final LicenseRecordService _service =
      widget._service ?? LicenseRecordService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _bindNameController = TextEditingController();
  final TextEditingController _bindUserCodeController = TextEditingController();
  final TextEditingController _operatorNameController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _durationDaysController = TextEditingController(
    text: '30',
  );

  int? _selectedPresetDurationDays = 30;
  late DateTime _activationDeadlineDate = _defaultActivationDeadlineDate();
  bool _permanent = false;
  bool _submitting = false;

  @override
  void dispose() {
    _bindNameController.dispose();
    _bindUserCodeController.dispose();
    _operatorNameController.dispose();
    _remarkController.dispose();
    _durationDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建离线密钥'),
        actions: <Widget>[
          IconButton(
            tooltip: '授权总览',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.dashboard_outlined),
          ),
          IconButton(
            tooltip: '私钥设置',
            onPressed: () => context.go('/private-key'),
            icon: const Icon(Icons.key),
          ),
          IconButton(
            tooltip: '授权记录',
            onPressed: () => context.go('/records'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            TextFormField(
              controller: _bindNameController,
              decoration: const InputDecoration(
                labelText: '绑定用户姓名',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入绑定用户姓名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bindUserCodeController,
              decoration: const InputDecoration(
                labelText: '用户编号（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _permanent,
              onChanged: (bool value) {
                setState(() {
                  _permanent = value;
                });
              },
              title: const Text('永久授权'),
              subtitle: const Text('关闭后按指定天数从首次激活开始计算有效期。'),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_permanent) ...<Widget>[
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '有效期快捷选择',
                  border: OutlineInputBorder(),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _presetDurationOptions.map((int days) {
                        return ChoiceChip(
                          label: Text('$days 天'),
                          selected: _selectedPresetDurationDays == days,
                          onSelected: (_) {
                            setState(() {
                              _selectedPresetDurationDays = days;
                              _durationDaysController.text = days.toString();
                            });
                          },
                        );
                      }).toList()..add(
                        ChoiceChip(
                          label: const Text('手动填写'),
                          selected: _selectedPresetDurationDays == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedPresetDurationDays = null;
                            });
                          },
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationDaysController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: '有效期天数',
                  hintText: '请输入具体天数，例如 45',
                  helperText: '单位为天，可先快捷选择，也可在这里手动输入。',
                  suffixText: '天',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (_permanent) {
                    return null;
                  }
                  final int? days = int.tryParse((value ?? '').trim());
                  if (days == null || days <= 0) {
                    return '请输入大于 0 的有效期天数';
                  }
                  return null;
                },
                onChanged: (String value) {
                  final int? days = int.tryParse(value.trim());
                  setState(() {
                    _selectedPresetDurationDays =
                        _presetDurationOptions.contains(days) ? days : null;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickActivationDeadlineDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '首次激活截止日期',
                  helperText: '约束授权码首次使用窗口，永久授权也需要设置。',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatActivationDeadlineDate(_activationDeadlineDate),
                      ),
                    ),
                    const Icon(Icons.calendar_month_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _operatorNameController,
              decoration: const InputDecoration(
                labelText: '操作人（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarkController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vpn_key),
              label: Text(_submitting ? '生成中...' : '生成离线密钥'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final int durationDays = _permanent
          ? 0
          : int.parse(_durationDaysController.text.trim());
      final LicenseRecordEntity record = await _service.createLicenseRecord(
        bindName: _bindNameController.text,
        bindUserCode: _bindUserCodeController.text,
        durationDays: durationDays,
        permanent: _permanent,
        activationDeadline: _normalizeDeadlineForStorage(
          _activationDeadlineDate,
        ),
        operatorName: _operatorNameController.text,
        remark: _remarkController.text,
      );

      if (!mounted) {
        return;
      }

      final _PostCreateAction? action = await _showGeneratedLicenseDialog(
        record,
      );
      if (!mounted) {
        return;
      }
      switch (action) {
        case _PostCreateAction.keepCreating:
          _resetForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('授权已生成，可以继续新建下一条。'),
              duration: Duration(seconds: 5),
            ),
          );
        case _PostCreateAction.viewDetail:
          await context.push('/records/${record.licenseId}');
        case _PostCreateAction.viewRecords:
          context.go('/records');
        case null:
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成失败：$error'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '私钥设置',
            onPressed: () {
              context.go('/private-key');
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<_PostCreateAction?> _showGeneratedLicenseDialog(
    LicenseRecordEntity record,
  ) async {
    return showDialog<_PostCreateAction>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('离线密钥已生成'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _InfoLine(label: '授权编号', value: record.licenseId),
                  _InfoLine(label: '绑定用户', value: record.bindName),
                  _InfoLine(
                    label: '有效期',
                    value: record.permanent ? '永久' : '${record.durationDays} 天',
                  ),
                  _InfoLine(
                    label: '首次激活截止',
                    value: ChineseDateTimeFormatter.formatDateTime(
                      record.activationDeadline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '离线密钥',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: SelectableText(record.rawLicense),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      dialogContext.pop(_PostCreateAction.keepCreating);
                    },
                    child: const Text('继续新建'),
                  ),
                  TextButton(
                    onPressed: () {
                      dialogContext.pop(_PostCreateAction.viewRecords);
                    },
                    child: const Text('查看记录'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      dialogContext.pop(_PostCreateAction.viewDetail);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('查看详情'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: record.rawLicense),
                      );
                      if (!dialogContext.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(const SnackBar(content: Text('授权码已复制')));
                    },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('复制离线密钥'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _bindNameController.clear();
    _bindUserCodeController.clear();
    _operatorNameController.clear();
    _remarkController.clear();
    setState(() {
      _selectedPresetDurationDays = 30;
      _durationDaysController.text = '30';
      _activationDeadlineDate = _defaultActivationDeadlineDate();
      _permanent = false;
    });
  }

  DateTime _defaultActivationDeadlineDate() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
  }

  DateTime _normalizeDeadlineForStorage(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toUtc();
  }

  String _formatActivationDeadlineDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  Future<void> _pickActivationDeadlineDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _activationDeadlineDate.isBefore(now)
        ? now
        : _activationDeadlineDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: '选择首次激活截止日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _activationDeadlineDate = picked;
    });
  }
}

enum _PostCreateAction { keepCreating, viewDetail, viewRecords }

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: <InlineSpan>[
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
