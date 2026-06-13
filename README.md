# Plugin Framework — 插件开发示例

本仓库包含 Plugin Framework 的插件开发示例和详细教程。

插件框架主仓库：[plugin-framework](https://github.com/3975380064-maker/plugin-framework)

---

## 快速开始

### 1. 创建插件类

创建一个 Java 类，实现 `Plugin` 接口：

```java
package com.example;

import com.java.myapplication.Plugin;
import com.java.myapplication.ShizukuProxy;
import java.util.Map;

public class MyPlugin implements Plugin {
    
    @Override
    public String getName() {
        return "我的插件";
    }
    
    @Override
    public String getDescription() {
        return "这是我的第一个插件";
    }
    
    @Override
    public String getVersion() {
        return "1.0.0";
    }
    
    @Override
    public boolean needsShizuku() {
        return true;
    }
    
    @Override
    public String execute(ShizukuProxy proxy, Map<String, ?> args) {
        return proxy.execCommand("echo Hello World!");
    }
}
```

### 2. 创建 plugin.properties

在 `META-INF/plugin.properties` 中声明入口类：

```properties
mainClass=com.example.MyPlugin
```

### 3. 编译打包

```bash
# 编译（需要 android.jar 或宿主接口 stub）
javac -cp platform-framework-stubs.jar MyPlugin.java

# 打包 jar
mkdir -p META-INF
echo "mainClass=com.example.MyPlugin" > META-INF/plugin.properties
jar cf MyPlugin.jar com/ META-INF/
```

### 4. 导入到框架

在 Plugin Framework 应用中点击 `+` 按钮，选择编译好的 `.jar` 文件即可。

---

## 示例插件

| 文件 | 说明 | Shizuku |
|------|------|---------|
| [ExamplePlugin.java](plugins/ExamplePlugin.java) | 设备信息查询（品牌、型号、Android版本、电池、存储） | ✅ |
| [TestPlugin.java](plugins/TestPlugin.java) | 设备信息查询 + 逐行日志输出 | ✅ |
| [ClipStackPlugin.java](plugins/ClipStackPlugin.java) | 自动授权剪贴板管理器权限 + 重启服务 | ✅ |

---

## 接口参考

### Plugin 接口

```java
public interface Plugin {
    String getName();                                    // 插件显示名称
    String getDescription();                             // 插件描述
    String getVersion();                                 // 版本号
    String execute(ShizukuProxy proxy, Map<String, ?> args); // 手动执行入口
    boolean needsShizuku();                              // 是否需要 Shizuku 权限（默认 true）
}
```

### ShizukuProxy 提供的能力

| 方法 | 用途 | 示例 |
|------|------|------|
| `execCommand(cmd)` | 执行任意 Shell 命令 | `execCommand("ls /sdcard")` |
| `getProp(key)` | 获取系统属性 | `getProp("ro.product.model")` |
| `installApk(path)` | 静默安装 APK | `installApk("/sdcard/app.apk")` |
| `uninstallApp(pkg)` | 卸载应用 | `uninstallApp("com.example.app")` |
| `launchApp(pkg)` | 启动应用 | `launchApp("com.example.app")` |
| `getSetting(ns, key)` | 读取系统设置 | `getSetting("system", "screen_brightness")` |
| `putSetting(ns, key, val)` | 修改系统设置 | `putSetting("system", "screen_brightness", "128")` |

---

## 进阶：后台常驻插件

实现 `BackgroundPlugin` 接口（继承 `Plugin`），可以让插件长期运行在后台：

```java
public class MyBackgroundPlugin implements BackgroundPlugin {
    
    // ... Plugin 接口方法 ...
    
    @Override
    public void runInBackground(ShizukuProxy proxy, CoroutineScope scope, SubPluginDispatcher dispatcher) {
        while (scope.isActive()) {
            // 持续监控或周期性任务
            String result = proxy.execCommand("...");
            delay(5000);
        }
    }
}
```

---

## 进阶：子插件

在 `plugin.properties` 中声明子插件 ID（逗号分隔）：

```properties
mainClass=com.example.AdKiller
uid=com.example.adkiller
version=2.0.0
subPlugins=monitor,kill,skip
```

常驻插件通过 `SubPluginDispatcher` 调用子插件：

```java
dispatcher.call("monitor", Map.of("target", "com.example.app"));
```

---

## 插件开发注意事项

1. **强制声明**：必须包含 `META-INF/plugin.properties` 且声明 `mainClass`
2. **安全校验**：所有 Shell 参数都经过格式校验，不要尝试绕过
3. **只加载可信插件**：DexClassLoader 可执行任意代码，插件拥有应用全部权限
4. **返回字符串**：`execute()` 返回值直接展示在 UI 中，注意格式化

---

## License

同主仓库 — Apache License 2.0

---

## ClipStack 插件使用说明

ClipStack 插件用于自动管理旧版剪贴板应用 [Tiny Clipboard Manager](https://github.com/catchingnow/tinyclipboardmanager) 的权限。

### 背景

旧版 Tiny Clipboard Manager（包名 `com.catchingnow.tinyclipboardmanager`）需要手动通过 ADB 或 Shizuku 授予悬浮窗和日志权限才能正常显示悬浮窗和通知。每次重启设备或清除应用数据后都需要重新授权。

### 插件功能

ClipStack 插件通过 Plugin Framework + Shizuku 自动完成以下操作：

1. **授予悬浮窗权限**：`appops set com.catchingnow.tinyclipboardmanager SYSTEM_ALERT_WINDOW allow`
2. **授予日志权限**：`pm grant com.catchingnow.tinyclipboardmanager android.permission.READ_LOGS`
3. **重启剪贴板服务**：强制停止并重新启动应用

### 使用步骤

1. 在手机上下载并安装旧版 [Tiny Clipboard Manager](https://f-droid.org/repo/com.catchingnow.tinyclipboardmanager_35.apk)
2. 下载 [ClipStackPlugin.java](plugins/ClipStackPlugin.java)，编译打包为 jar
3. 在 Plugin Framework 应用中导入 `ClipStackPlugin.jar`
4. 点击执行 → 自动完成授权和重启

### 编译命令

```bash
javac -cp plugin-framework-stubs.jar ClipStackPlugin.java
mkdir -p META-INF
echo "mainClass=com.plugin.clipstack.ClipStackPlugin" > META-INF/plugin.properties
jar cf ClipStackPlugin.jar com/ META-INF/
```
