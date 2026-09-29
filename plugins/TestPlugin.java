package com.plugin;

import com.java.myapplication.Plugin;
import com.java.myapplication.ShizukuProxy;
import java.util.Map;

/**
 * 最小插件模板：演示不需要 Shizuku 权限的插件如何编写。
 *
 * needsShizuku() 返回 false 时，框架在 Shizuku 未授权的情况下也允许执行。
 */
public class TestPlugin implements Plugin {

    @Override
    public String getName() {
        return "TestPlugin";
    }

    @Override
    public String getDescription() {
        return "最小插件模板，回显调用参数与当前身份";
    }

    @Override
    public String getVersion() {
        return "1.0";
    }

    @Override
    public boolean needsShizuku() {
        return false;
    }

    @Override
    public String execute(ShizukuProxy proxy, Map<String, ?> args) {
        StringBuilder result = new StringBuilder();
        result.append("Hello from TestPlugin\n");
        result.append("args: ").append(args == null ? "(null)" : args.toString()).append("\n");

        boolean available = proxy.isShizukuAvailable();
        result.append("Shizuku 可用: ").append(available).append("\n");

        if (available && proxy.checkPermission()) {
            result.append("\n=== 当前身份 ===\n");
            result.append(proxy.execCommand("id"));
        } else {
            result.append("未授权，跳过需要提权的命令");
        }

        return result.toString();
    }
}
