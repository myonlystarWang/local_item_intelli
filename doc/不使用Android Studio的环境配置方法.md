下面按最小路径来，不装 Android Studio，不装模拟器。

**1. 安装 JDK 17**
打开 PowerShell，执行：

```powershell
winget install EclipseAdoptium.Temurin.17.JDK -e
```

配置 `JAVA_HOME`：

```powershell
$jdk = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk.FullName, "User")
$env:JAVA_HOME = $jdk.FullName
```

如果要写“系统环境变量”，要用 "Machine"，但通常需要管理员权限：
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk.FullName, "Machine")
这里建议先用用户环境变量就够了，Flutter/Gradle 调试可以识别。

**2. 下载 Android 命令行工具**
打开官方下载页：

```powershell
Start-Process "https://developer.android.com/studio#command-tools"
```

在页面里找 **Command line tools only**，下载 **Windows** 版本。

官方文档说明 Android SDK 可用 `sdkmanager` 安装和更新，命令行工具位于 `android_sdk/cmdline-tools/version/bin/`；`adb` 位于 `platform-tools/`。参考：[Android Command-line tools](https://developer.android.com/tools)。

**3. 解压 Android SDK 命令行工具**
假设下载到了 `Downloads`，执行：

```powershell
$sdk = "C:\Users\dell\AppData\Local\Android\sdk"
$tmp = "$env:TEMP\android-cmdline-tools"
$zip = Get-ChildItem "$env:USERPROFILE\Downloads\commandlinetools-win-*_latest.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

New-Item -ItemType Directory -Force "$sdk\cmdline-tools\latest" | Out-Null
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Expand-Archive $zip.FullName $tmp -Force
Copy-Item "$tmp\cmdline-tools\*" "$sdk\cmdline-tools\latest" -Recurse -Force
```

检查是否存在：

```powershell
Test-Path "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"
```

应该输出：

```text
True
```

**4. 配置 Android SDK 环境变量**

```powershell
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdk, "User")

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$add = @(
  "$sdk\platform-tools",
  "$sdk\cmdline-tools\latest\bin",
  "$env:JAVA_HOME\bin"
)

foreach ($p in $add) {
  if ($userPath -notlike "*$p*") {
    $userPath = "$userPath;$p"
  }
}

[Environment]::SetEnvironmentVariable("Path", $userPath, "User")

$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = "$env:Path;$sdk\platform-tools;$sdk\cmdline-tools\latest\bin;$env:JAVA_HOME\bin"
```

**5. 安装必要 SDK 组件**

```powershell
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$sdk "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest"
```

接受 licenses：

```powershell
E:\flutter\bin\flutter.bat doctor --android-licenses
```

一路输入：

```text
y
```

**6. 让 Flutter 认 SDK**

```powershell
E:\flutter\bin\flutter.bat config --android-sdk "$sdk"
```

检查：

```powershell
E:\flutter\bin\flutter.bat doctor -v
```

重点看这一项应变成通过：

```text
[√] Android toolchain - develop for Android devices
```

**7. 手机准备**
手机上打开：

```text
开发者选项
USB 调试
USB 安装 / 允许通过 USB 安装应用
```

USB 连接电脑后，手机弹窗点：

```text
允许 USB 调试
```

**8. 检查真机是否识别**

```powershell
adb devices
```

正常应看到类似：

```text
List of devices attached
xxxxxx    device
```

再检查 Flutter：

```powershell
E:\flutter\bin\flutter.bat devices
```

**9. 启动 App 调试**

```powershell
cd "E:\ww\sz work\item_intelli\proj\app"
E:\flutter\bin\flutter.bat run
```

如果有多个设备，先看设备 ID：

```powershell
E:\flutter\bin\flutter.bat devices
```

然后指定设备：

```powershell
E:\flutter\bin\flutter.bat run -d 你的设备ID
```

**10. 停止 App 调试**
在运行 `flutter run` 的终端里按：

```text
q
```