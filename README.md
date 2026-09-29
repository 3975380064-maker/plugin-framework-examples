# plugin-framework-examples

[plugin-framework](https://github.com/3975380064-maker/plugin-framework) 的插件开发示例与教程。

框架 v2.1 起只接受 `.jar` 插件包，且必须在 jar 内声明 `META-INF/plugin.properties`。

## 快速开始

### 1. 引入宿主接口

插件源码需要引用宿主的两组类：

- `com.java.myapplication.Plugin`
- `com.java.myapplication.ShizukuProxy`
- `com.java.myapplication.BackgroundPlugin`（仅后台常驻插件需要）
- `com.java.myapplication.SubPluginDispatcher`（仅子插件调度需要）

获取方式：编译宿主仓库得到 `classes.jar`（`app/build/intermediates/.../classes`），或把这几个接口源文件复制进插件工程。

### 2. 编写插件类

```java
package com.example;

import com.java.myapplication.Plugin;
import com.java.myapplication.ShizukuProxy;
import java.util.Map;

public class MyPlugin implements Plugin {

    @Override
    public String getName() { return "我的插件"; }

    @Override
    public String getDescription() { return "这是我的第一个插件"; }

    @Override
    public String getVersion() { return "1.0.0"; }

    @Override
    public boolean needsShizuku() { return true; }

    @Override
    public String execute(ShizukuProxy proxy, Map<String, ?> args) {
        return proxy.execCommand("echo Hello World!");
    }
}
```

**签名注意**：`execute` 的参数必须写成 `Map<String, ?>`。宿主侧对应 Kotlin 的 `Map<String, Any>?`，编译后是 `Map<String, ? extends Object>`；写成 `Map<String, Object>` 会报 `name clash ... same erasure` 编译错误。

`needsShizuku()` 返回 `false` 表示插件不依赖提权，框架在 Shizuku 未授权时也允许执行。

### 3. 声明入口类

新建 `META-INF/plugin.properties`：

```properties
mainClass=com.example.MyPlugin
```

支持的键：

| 键 | 必填 | 说明 |
|----|------|------|
| `mainClass` | 是 | 插件入口类全名 |
| `uid` | 否 | 插件唯一标识 |
| `version` | 否 | 版本号，缺省取 `Plugin.getVersion()` |
| `description` | 否 | 描述，缺省取 `Plugin.getDescription()` |
| `subPlugins` | 否 | 子插件 ID 列表，逗号分隔 |

### 4. 编译打包

**关键点：jar 里必须是 `classes.dex`，不能是 `.class`。** 框架用 `DexClassLoader` 加载，只有 JVM 字节码的 jar 会报 `Failed to open dex files ... Entry not found`，插件不会出现在列表里。

本仓库提供封装好的 `build.sh`：

```bash
./build.sh plugins/MyPlugin.java com.example.MyPlugin "/path/to/host-classes.jar:/path/to/android.jar"
```

它依次完成 javac → d8 → 写入 `META-INF/plugin.properties` → 打包，产出 `MyPlugin.jar`。

手动执行等价于：

```bash
# 1) 编译
javac -cp host-classes.jar -d build/classes src/com/example/MyPlugin.java

# 2) 转成 dex
D8_JAR=$ANDROID_HOME/build-tools/<版本>/lib/d8.jar
java -cp "$D8_JAR" com.android.tools.r8.D8 --min-api 24 --output build/dex \
    $(find build/classes -name '*.class')

# 3) 声明入口类
mkdir -p build/META-INF
echo "mainClass=com.example.MyPlugin" > build/META-INF/plugin.properties

# 4) 打包
cp build/dex/classes.dex build/classes.dex
( cd build && jar cf ../MyPlugin.jar classes.dex META-INF/plugin.properties )
```

### 5. 导入框架

打开 Plugin Framework 应用，点右下角 `+`，选择 `MyPlugin.jar`。插件会立即出现在「手动执行」Tab。

## 示例插件

| 文件 | 说明 | Shizuku |
|------|------|---------|
| [TestPlugin.java](plugins/TestPlugin.java) | 最小模板，回显参数与当前身份，演示免提权插件 | 不需要 |
| [ExamplePlugin.java](plugins/ExamplePlugin.java) | 基础示例，读取型号 / 系统版本 / 屏幕 / 电池 | 需要 |
| [DeviceInfoPlugin.java](plugins/DeviceInfoPlugin.java) | 完整示例，`getProp` + `execCommand` 组合并做分段格式化输出 | 需要 |

三个插件的 jar 都可以用 `build.sh` 直接构建。

## 接口参考

### Plugin

```kotlin
interface Plugin {
    fun getName(): String
    fun getDescription(): String
    fun getVersion(): String
    fun execute(proxy: ShizukuProxy, args: Map<String, Any>? = null): String
    fun needsShizuku(): Boolean = true
}
```

`execute` 的返回值会直接显示在结果弹窗中，注意排版。

### ShizukuProxy

| 方法 | 说明 |
|------|------|
| `execCommand(cmd)` | 执行任意 shell 命令 |
| `getProp(prop)` | 读取系统属性 |
| `installApk(path)` | 静默安装 APK |
| `uninstallApp(packageName)` | 卸载应用 |
| `launchApp(packageName, activityName?)` | 启动应用 |
| `getSetting(namespace, key)` | 读取系统设置 |
| `putSetting(namespace, key, value)` | 修改系统设置 |
| `isShizukuAvailable()` | Shizuku 服务是否可用 |
| `checkPermission()` | 是否已授权 |

`namespace` 仅接受 `system` / `secure` / `global`。所有参数都会先做格式校验，非法输入直接返回 `Error: ...`，命令不会执行。

## 进阶：后台常驻插件

后台插件实现 `BackgroundPlugin`（继承 `Plugin`）：

```kotlin
interface BackgroundPlugin : Plugin {
    suspend fun runInBackground(
        proxy: ShizukuProxy,
        scope: CoroutineScope,
        dispatcher: SubPluginDispatcher
    )
}
```

**后台常驻插件必须用 Kotlin 编写。** `runInBackground` 是 Kotlin 的 `suspend fun`，Java 编译后的签名会多出一个 `Continuation<? super Unit>` 参数，无法用普通 Java 方法实现。

Kotlin 示例：

```kotlin
package com.example

import com.java.myapplication.BackgroundPlugin
import com.java.myapplication.ShizukuProxy
import com.java.myapplication.SubPluginDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

class MyBackgroundPlugin : BackgroundPlugin {

    override fun getName() = "MyBackgroundPlugin"
    override fun getDescription() = "每 5 秒读取一次亮度"
    override fun getVersion() = "1.0.0"
    override fun execute(proxy: ShizukuProxy, args: Map<String, Any>?) = "常驻插件无手动执行入口"

    override suspend fun runInBackground(
        proxy: ShizukuProxy,
        scope: CoroutineScope,
        dispatcher: SubPluginDispatcher
    ) {
        while (scope.isActive) {
            val brightness = proxy.getSetting("system", "screen_brightness")
            delay(5_000)
        }
    }
}
```

`scope` 由宿主管理，点「停止」或宿主销毁时会取消，循环会随之中断。

## 进阶：子插件

在 `plugin.properties` 中声明子插件 ID：

```properties
mainClass=com.example.AdKiller
uid=com.example.adkiller
version=2.0.0
subPlugins=monitor,kill,skip
```

常驻插件通过 `SubPluginDispatcher` 调用：

```kotlin
val result = dispatcher.call("monitor", mapOf("target" to "com.example.app"))
```

同一个子插件 ID 串行执行，不会并发触发。

## 注意事项

1. 必须实现 `Plugin` 接口，且 jar 内含 `META-INF/plugin.properties`
2. 不要尝试绕过参数校验，宿主会在执行前拦截非法输入
3. 插件以宿主进程身份运行，拥有宿主全部权限以及 Shizuku 的 ADB 权限，只加载可信来源的插件
4. 插件无法使用宿主 Android 资源系统（`R.layout`、`R.string` 等）
5. 插件运行在应用进程内，默认没有存储权限，不要直接写 `/sdcard`

## 排错

插件没出现在列表里：

1. 确认是 `.jar`，扩展名正确
2. 确认 jar 内有 `classes.dex`（用 `unzip -l XxxPlugin.jar` 查看；只有 `.class` 一定加载失败）
3. 确认 jar 内含 `META-INF/plugin.properties`
4. 确认 `mainClass` 与真实类名一致
5. 确认类实现了 `Plugin` 接口
6. 确认 `execute` 用的是 `Map<String, ?>` 签名

日志里出现 `Failed to open dex files from <path> because: Entry not found` 就是第 2 条。

执行报 `Error: 未获取Shizuku权限，请先授权`：打开 Shizuku 应用重新授权本框架。

看日志：

```bash
logcat -s ShizukuProxy:V PluginLoader:V PluginManager:V BackgroundPluginHost:V
```

## License

Apache License 2.0，与主仓库一致。