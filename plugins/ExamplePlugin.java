package com.plugin;

import com.java.myapplication.Plugin;
import com.java.myapplication.ShizukuProxy;
import java.util.Map;

/**
 * 示例插件：读取设备基础信息。
 *
 * 编译打包见仓库 README（需要宿主的接口类作为 classpath）。
 */
public class ExamplePlugin implements Plugin {

    @Override
    public String getName() {
        return "ExamplePlugin";
    }

    @Override
    public String getDescription() {
        return "显示设备信息（型号、系统版本、屏幕、电池）";
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
        StringBuilder result = new StringBuilder();
        result.append("=== 设备信息 ===\n");
        result.append("品牌: ").append(proxy.getProp("ro.product.brand")).append("\n");
        result.append("型号: ").append(proxy.getProp("ro.product.model")).append("\n");
        result.append("Android 版本: ").append(proxy.getProp("ro.build.version.release")).append("\n");
        result.append("SDK 版本: ").append(proxy.getProp("ro.build.version.sdk")).append("\n");

        result.append("\n=== 屏幕 ===\n");
        result.append(proxy.execCommand("wm size")).append("\n");

        result.append("\n=== 电池 ===\n");
        result.append(proxy.execCommand("dumpsys battery | grep -E 'level|status|temperature'"));

        return result.toString();
    }
}
