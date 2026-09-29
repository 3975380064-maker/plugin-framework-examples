package com.plugin.deviceinfo;

import com.java.myapplication.Plugin;
import com.java.myapplication.ShizukuProxy;
import java.util.Map;

/**
 * 设备信息插件：演示 getProp + execCommand 组合使用。
 *
 * 打包必须走 build.sh（javac -> d8 -> jar），jar 内需为 classes.dex。
 */
public class DeviceInfoPlugin implements Plugin {

    @Override
    public String getName() {
        return "DeviceInfoPlugin";
    }

    @Override
    public String getDescription() {
        return "设备信息：硬件、系统、屏幕、电池、存储、第三方应用数";
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
        StringBuilder out = new StringBuilder();

        out.append("设备\n");
        out.append("  品牌/型号: ")
            .append(prop(proxy, "ro.product.brand")).append(" ")
            .append(prop(proxy, "ro.product.model")).append("\n");
        out.append("  系统版本: Android ")
            .append(prop(proxy, "ro.build.version.release"))
            .append(" (SDK ").append(prop(proxy, "ro.build.version.sdk")).append(")\n");
        out.append("  构建指纹: ").append(prop(proxy, "ro.build.fingerprint")).append("\n");

        out.append("\n屏幕\n").append(indent(proxy.execCommand("wm size")));
        out.append("\n电池\n").append(
            indent(proxy.execCommand("dumpsys battery | grep -E 'level|status|temperature|voltage'")));
        out.append("\n存储\n").append(indent(proxy.execCommand("df -h /data | tail -1")));
        out.append("\n第三方应用数\n").append(
            indent(proxy.execCommand("pm list packages -3 | wc -l")));

        return out.toString();
    }

    private static String prop(ShizukuProxy proxy, String key) {
        String value = proxy.getProp(key);
        return value == null ? "-" : value.trim();
    }

    private static String indent(String text) {
        if (text == null) return "  -\n";
        StringBuilder builder = new StringBuilder();
        for (String line : text.trim().split("\n")) {
            builder.append("  ").append(line).append("\n");
        }
        return builder.toString();
    }
}