# LanCtrl Mobile

LanCtrl 移动端项目，使用 Flutter 构建。

## 开发环境搭建

1. 确保已安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)。
2. 运行 `flutter doctor` 检查环境是否完整。

## 运行项目

用户常用的调试方式：
```bash
flutter run -d windows
```

其他运行方式：
- **运行到默认模拟器或真机**:
  ```bash
  flutter run
  ```
- **查看所有可用设备**:
  ```bash
  flutter devices
  ```
- **运行到特定设备**:
  ```bash
  flutter run -d <DEVICE_ID>
  ```

### 调试技巧
- 在控制台输入 `r` 进行 **热重载 (Hot Reload)**。
- 在控制台输入 `R` 进行 **热重启 (Hot Restart)**。

## 打包发布

### Android
- **生成 APK**:
  ```bash
  flutter build apk --release
  ```
- **生成 App Bundle (用于 Google Play 发布)**:
  ```bash
  flutter build appbundle --release
  ```

### iOS
*注意：打包 iOS 需要在 macOS 环境并安装 Xcode。*
- **生成 iOS 流项目**:
  ```bash
  flutter build ios --release
  ```

### Windows
- **生成 Windows 可执行文件**:
  ```bash
  flutter build windows --release
  ```

打包后的文件通常位于 `build/app/outputs/flutter-apk/` 或 `build/windows/` 等目录下。
