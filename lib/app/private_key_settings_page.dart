import 'dart:io';

import 'package:flutter/material.dart';
import 'package:teacher_hub_license_manager/core/crypto/private_key_storage_service.dart';

class PrivateKeySettingsPage extends StatefulWidget {
  const PrivateKeySettingsPage({
    super.key,
    PrivateKeyStorageService? service,
  }) : _service = service;

  final PrivateKeyStorageService? _service;

  @override
  State<PrivateKeySettingsPage> createState() => _PrivateKeySettingsPageState();
}

class _PrivateKeySettingsPageState extends State<PrivateKeySettingsPage> {
  late final PrivateKeyStorageService _service =
      widget._service ?? PrivateKeyStorageService();

  bool _loading = true;
  bool _working = false;
  File? _storedKeyFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('私钥设置'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '当前状态',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _storedKeyFile == null ? '未配置本地私钥文件' : '已配置本地私钥文件',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _storedKeyFile == null
                              ? '请导入一个私钥文件后再生成授权码。'
                              : '当前私钥文件保存在：${_storedKeyFile!.path}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '操作说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('1. 点击“导入私钥文件”打开系统文件选择器。'),
                        const SizedBox(height: 6),
                        const Text('2. 选择你自己的私钥文件。'),
                        const SizedBox(height: 6),
                        const Text('3. 程序会复制一份到应用本地设置目录，后续发码直接使用。'),
                        const SizedBox(height: 6),
                        const Text('4. 如需替换私钥，可重新导入；如需移除，可点击“清除私钥”。'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _working ? null : _importKeyFile,
                      icon: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_open),
                      label: Text(_working ? '处理中...' : '导入私钥文件'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _working || _storedKeyFile == null ? null : _clearKey,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清除私钥'),
                    ),
                    TextButton.icon(
                      onPressed: _working ? null : _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新状态'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final File? storedFile = await _service.getStoredKeyFile();
    if (!mounted) {
      return;
    }
    setState(() {
      _storedKeyFile = storedFile;
      _loading = false;
    });
  }

  Future<void> _importKeyFile() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _working = true;
    });
    try {
      final File? storedFile = await _service.importKeyFromPicker();
      if (!mounted) {
        return;
      }
      if (storedFile == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已取消导入私钥文件。'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        setState(() {
          _storedKeyFile = storedFile;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('私钥文件已导入：${storedFile.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('导入私钥失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _clearKey() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _working = true;
    });
    try {
      await _service.clearStoredKey();
      if (!mounted) {
        return;
      }
      setState(() {
        _storedKeyFile = null;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('本地私钥已清除。'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('清除私钥失败：$error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }
}
