# Windows 打包与发布流程

本文档用于说明 `teacher_hub_license_manager` 在 Windows 平台上的发布流程。

## 1. 目标产物

最终发布产物为：

- 安装包：`teacher_toolkit_license_manager_setup.exe`

默认输出目录：

```text
d:\code\teacher_hub_license_manager\dist\
```

## 2. 发布前准备

发布前请确认：

1. 版本号已经更新  
   检查：
   - [pubspec.yaml](d:/code/teacher_hub_license_manager/pubspec.yaml)

2. 私钥没有写入源码、常量、资源文件或安装包默认内容

3. 当前代码可以通过基础校验

建议执行：

```powershell
cd d:\code\teacher_hub_license_manager
flutter analyze
$env:NO_PROXY='127.0.0.1,localhost'
$env:no_proxy='127.0.0.1,localhost'
flutter test
```

## 3. 构建 Windows Release

在项目目录执行：

```powershell
cd d:\code\teacher_hub_license_manager
flutter clean
flutter pub get
flutter build windows --release
```

构建完成后，Release 目录位于：

```text
d:\code\teacher_hub_license_manager\build\windows\x64\runner\Release\
```

说明：

- 安装脚本会从这个目录读取应用文件
- 安装脚本也会从这里自动读取可执行文件版本号

## 4. 生成安装包

本项目使用 Inno Setup 生成 Windows 安装包。

安装脚本文件：

- [installer.iss](d:/code/teacher_hub_license_manager/installer.iss)

步骤：

1. 安装 Inno Setup
2. 打开 `installer.iss`
3. 点击 `Build`

生成后，安装包位于：

```text
d:\code\teacher_hub_license_manager\dist\teacher_toolkit_license_manager_setup.exe
```

## 5. 安装包当前特性

当前安装包支持：

- 自动使用 Windows Release 目录作为安装源
- 自动读取发布版 exe 的版本号
- 安装器图标
- 卸载项图标
- 中文显示名称
- 桌面快捷方式
- 开始菜单快捷方式

## 6. 安装后验证

生成安装包后，建议先在本机做一次完整试装。

重点检查：

1. 安装向导是否正常显示
2. 默认安装路径是否符合预期
3. 开始菜单快捷方式是否正常
4. 桌面快捷方式是否正常
5. 卸载项名称和图标是否正常
6. 程序是否可以正常启动
7. 没有私钥时程序是否只是无法发码，而不是直接崩溃
8. 配置私钥后是否能正常生成授权码
9. 授权记录是否能落库
10. `.xlsx` 导出是否正常

## 7. 私钥相关说明

本项目的安装包默认不携带私钥。

必须遵守：

- 私钥不得提交到 git
- 私钥不得写入源码常量
- 私钥不得进入安装包默认内容

推荐做法：

- 通过环境变量提供私钥
- 或由程序启动后读取本地私钥文件

## 8. 版本号说明

当前建议以 Flutter 版本号为主。

主版本号位置：

- [pubspec.yaml](d:/code/teacher_hub_license_manager/pubspec.yaml)

例如：

```yaml
version: 1.0.0+1
```

说明：

- `1.0.0`：对外展示版本
- `+1`：内部构建号

安装脚本会自动从 Release 目录中的 exe 读取版本号，不需要再手工修改 `installer.iss` 里的版本字段。

## 9. 常见问题

### 9.1 安装脚本提示找不到 Release 文件

说明还没有先执行：

```powershell
flutter build windows --release
```

### 9.2 安装脚本提示找不到图标文件

请检查：

- [app_icon.ico](d:/code/teacher_hub_license_manager/windows/runner/resources/app_icon.ico)

### 9.3 程序安装后能打开，但发码失败

通常说明：

- 没有配置私钥
- 或私钥格式不正确

## 10. 建议发布流程

推荐每次发布按下面顺序执行：

1. 更新版本号
2. 执行 `flutter analyze`
3. 执行 `flutter test`
4. 执行 `flutter build windows --release`
5. 用 `installer.iss` 生成安装包
6. 本机试装
7. 确认无误后再分发安装包
