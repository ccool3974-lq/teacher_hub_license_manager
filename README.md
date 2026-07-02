# Teacher Hub License Manager

`Teacher Hub License Manager` 是 `Teacher Toolkit` 的内部授权管理工具。

它用于：
- 生成 TTK3 离线登录密钥
- 保存授权记录
- 查询与筛选授权历史
- 导出授权记录
- 管理导出目录
- 导入并管理本地私钥文件

推荐整体结构：

```text
d:\code\
  teacher_hub\
  teacher_hub_license_manager\
  teacher_toolkit_license_protocol\
```

工作区级结构和交互规范见：

- [WORKSPACE_DESIGN.md](d:/code/WORKSPACE_DESIGN.md)
- [WORKSPACE_UX_GUIDELINES.md](d:/code/WORKSPACE_UX_GUIDELINES.md)

## 运行

进入项目目录：

```powershell
cd d:\code\teacher_hub_license_manager
```

程序支持两种私钥来源：

1. 环境变量
```powershell
$env:TEACHER_HUB_LICENSE_PRIVATE_KEY_SEED='你的私钥种子'
flutter run -d windows
```

2. 程序内导入私钥文件  
安装后或运行时可通过“私钥设置”页面导入私钥文件，导入后的副本会保存到应用本地设置目录。

## 打包 Windows Release

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

发布目录：

```text
d:\code\teacher_hub_license_manager\build\windows\x64\runner\Release\
```

## 构建安装包

本项目提供 Inno Setup 脚本：

```text
d:\code\teacher_hub_license_manager\installer.iss
```

使用方式：

1. 先执行 `flutter build windows --release`
2. 安装 Inno Setup
3. 打开 `installer.iss`
4. 在 Inno Setup 中点击 Build

生成的安装包默认输出到：

```text
d:\code\teacher_hub_license_manager\dist\
```

完整 Windows 打包流程见：

- [WINDOWS_PACKAGING.md](d:/code/teacher_hub_license_manager/WINDOWS_PACKAGING.md)

## 安全说明

- 私钥不得提交到 git
- 私钥不得写入源码常量
- 私钥不得进入安装包默认内容
- 正式使用时建议通过本地安全文件、环境变量或程序内私钥导入功能提供私钥
- 离线密钥会写入首次激活截止日期，发码时默认预填签发后 30 天，也可按具体日期调整
- 当前发码工具不再区分免费版、基础版、高级版，也不再按功能点授权
- `teacher_hub` 同步接入新协议前，不要将新 TTK3 离线密钥与旧授权码混用
