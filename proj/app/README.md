# 📱 精密工具智能化管理系统：移动手持终端调试指南 (Windows 10)

本指南针对如何在 Windows 10 本地环境下搭建 Flutter 运行环境，并对手持端（Flutter + SQLite）进行本地编译、运行、数据库查看以及局域网接口联调进行详细说明。

---

## 1. 🛠️ 开发与调试环境准备

由于目前项目仅包含 Dart 核心代码，您需要在本地 Windows 10 电脑上配置 Flutter SDK 环境以生成原生构建外壳并运行程序。

### 1.1 配置 Flutter SDK
1. **下载 SDK**：前往 [Flutter 官网](https://docs.flutter.dev/release/archive?tab=windows) 下载最新的稳定版 SDK 压缩包（如 `flutter_windows_3.x.x-stable.zip`）。
2. **解压与归档**：将压缩包解压到您电脑上一个没有中文、空格及特殊字符的目录（例如 `C:\src\flutter`）。
3. **配置环境变量 (Path)**：
   - 在 Windows 搜索栏输入“环境变量”，打开“编辑系统环境变量”。
   - 双击“Path”变量，点击“新建”，将 Flutter 的 `bin` 路径（如 `C:\src\flutter\bin`）添加进去。
4. **验证环境**：
   - 打开命令提示符（CMD）或 PowerShell，运行以下命令检查环境：
     ```bash
     flutter doctor
     ```
   - 根据输出提示，补全缺失的工具（如 Android Studio、Android SDK、CMD-line Tools 等）。

---

## 2. 🚀 初始化移动端原生外壳

在 `/proj/app` 目录下，只包含了核心的跨平台 `lib/` 源码和 `pubspec.yaml`。为了能够在 Windows 上调用原生编译器生成 Android/iOS 安装包，您需要补充原生运行环境壳：

1. 打开命令行，进入项目的移动端目录：
   ```bash
   cd "e:\ww\sz work\item_intelli\proj\app"
   ```
2. 执行补全命令：
   ```bash
   flutter create --org com.item_intelli .
   ```
   *该命令会检测当前目录，并安全地生成所需的 `android/`, `ios/` 等平台文件夹，而不会影响已有的 `lib/` 和 `pubspec.yaml`。*

3. 载入三方库依赖：
   ```bash
   flutter pub get
   ```

---

## 3. 🖥️ 设备连接与调试运行

### 3.1 方案 A：使用物理安卓真机调试 (推荐)
对于手持终端类应用，使用真机调试可以更方便地测试摄像头扫码和局域网连接：
1. **开启开发者模式**：在您的安卓手机上，进入“设置 -> 关于手机”，连续点击“版本号” 7 次以启用开发者选项。
2. **开启 USB 调试**：进入“系统 -> 开发者选项”，开启 **“USB 调试”**。
3. **物理连接**：用 USB 数据线将手机连接到电脑，手机上弹出“允许 USB 调试吗？”时选择“允许”。
4. **运行调试**：
   - 命令行运行 `flutter devices` 确认设备已识别。
   - 执行运行命令：
     ```bash
     flutter run
     ```

### 3.2 方案 B：使用 Android 模拟器调试
1. 打开 **Android Studio**，进入 **Virtual Device Manager** (AVD)。
2. 创建并启动一个虚拟的 Android 模拟器（推荐 API 30+ 且带有 Google Play Services 的系统镜像）。
3. 模拟器启动后，在 `/proj/app` 目录执行：
   ```bash
   flutter run
   ```

---

## 4. ⚡ 局域网同步接口联调 (关键)

在无网状态下，App 使用本地 SQLite 处理状态拦截；当手机连入库房的 Wi-Fi 后，需要向电脑上的 FastAPI 后端发起同步校验。

### 4.1 获取您电脑的局域网 IP
1. 在 Windows 电脑上打开 CMD，输入：
   ```cmd
   ipconfig
   ```
2. 找到您正在使用的网卡（如“无线局域网适配器 WLAN”），记下其中的 **IPv4 地址**（例如 `192.168.1.105`）。

### 4.2 配置 App 同步网关地址
1. 打开 [sync_screen.dart](file:///e:/ww/sz%20work/item_intelli/proj/app/lib/screens/sync_screen.dart#L65-L67)。
2. 修改第 66 行的 `http://192.168.1.100:8000/sync`，将其中的 IP 替换为您电脑的实际 IPv4 地址：
   ```dart
   // 将此处修改为您电脑的局域网 IP
   final url = Uri.parse('http://192.168.1.105:8000/sync'); 
   ```
3. **确保手机和电脑在同一个路由器 Wi-Fi 网络下**。如果无法联调，请检查 Windows 防火墙，确保 8000 端口没有被阻止。

---

## 5. 💾 SQLite 本地数据库调试

App 离线运行时的数据会保存在手机内置的 SQLite 数据库 `local_item_intelli.db` 中。

* **查看本地待同步记录**：
  直接在 App 首页点击 **“近场同步网关”** 进入同步控制台，界面会自动调用 SQLite 查询并展示所有未上传的离线日志。
* **提取数据库文件 (高级调试)**：
  如果您想直接使用 SQLite 数据库浏览器（如 DB Browser for SQLite）查看手机里的数据：
  1. 通过 USB 连接手机，在 CMD 中运行：
     ```bash
     adb shell
     run-as com.item_intelli
     ```
  2. 导出 db 文件到电脑：
     ```bash
     adb pull /data/data/com.item_intelli/databases/local_item_intelli.db C:\Users\Public\Downloads\
     ```
