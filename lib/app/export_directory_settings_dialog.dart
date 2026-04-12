import 'dart:io';

import 'package:flutter/material.dart';
import 'package:teacher_hub_license_manager/core/export/export_directory_service.dart';

class ExportDirectorySettingsDialog extends StatefulWidget {
  const ExportDirectorySettingsDialog({
    super.key,
    ExportDirectoryService? service,
  }) : _service = service;

  final ExportDirectoryService? _service;

  @override
  State<ExportDirectorySettingsDialog> createState() =>
      _ExportDirectorySettingsDialogState();
}

class _ExportDirectorySettingsDialogState
    extends State<ExportDirectorySettingsDialog> {
  late final ExportDirectoryService _service =
      widget._service ?? ExportDirectoryService();

  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _pickingDirectory = false;
  String? _defaultPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出目录设置'),
      content: SizedBox(
        width: 640,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _controller,
                    readOnly: true,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '当前导出目录',
                      helperText: '通过系统目录选择器设置授权导出目录。',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '选择目录',
                        onPressed: _loading || _saving || _pickingDirectory
                            ? null
                            : _pickDirectory,
                        icon: _pickingDirectory
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '默认目录：${_defaultPath ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _platformHint(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _loading || _saving ? null : _openDirectory,
          child: const Text('打开目录'),
        ),
        TextButton(
          onPressed: _loading || _saving ? null : _resetToDefault,
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }

  Future<void> _load() async {
    final Directory defaultDirectory = await _service.getDefaultExportDirectory();
    final Directory currentDirectory = await _service.getExportDirectory();
    if (!mounted) {
      return;
    }
    setState(() {
      _defaultPath = defaultDirectory.path;
      _controller.text = currentDirectory.path;
      _loading = false;
    });
  }

  Future<void> _pickDirectory() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _pickingDirectory = true;
    });
    try {
      final String? selectedPath = await _service.pickDirectoryPath();
      if (!mounted) {
        return;
      }
      if (selectedPath != null && selectedPath.trim().isNotEmpty) {
        _controller.text = selectedPath;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('选择目录失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingDirectory = false;
        });
      }
    }
  }

  Future<void> _openDirectory() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await _service.openExportDirectory();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已尝试打开导出目录'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('打开导出目录失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
    });
    try {
      await _service.resetToDefaultDirectory();
      await _load();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('已恢复默认导出目录'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('恢复默认目录失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
    });
    try {
      await _service.saveExportDirectory(_controller.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('导出目录已更新'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('保存导出目录失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _platformHint() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return '当前平台支持系统目录选择和打开导出目录。';
    }
    return '当前平台优先支持系统目录选择；打开导出目录能力可能受平台限制。';
  }
}
