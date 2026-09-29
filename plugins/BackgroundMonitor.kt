package com.plugin.monitor

import com.java.myapplication.BackgroundPlugin
import com.java.myapplication.ShizukuProxy
import com.java.myapplication.SubPluginDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/**
 * 后台常驻插件示例。
 *
 * 演示三件事：
 * 1. BackgroundPlugin.runInBackground 的写法与取消语义（scope 由宿主管理）
 * 2. plugin.properties 里声明 subPlugins，由本插件自己响应子插件调用
 * 3. SubPluginDispatcher.call(id, args) 的参数会透传到 execute 的 args
 *
 * 子插件 ID：
 * - battery：读取电量与温度
 * - prop：读取指定系统属性，args["key"] 指定属性名
 */
class BackgroundMonitor : BackgroundPlugin {

    override fun getName(): String = "BackgroundMonitor"

    override fun getDescription(): String = "每 10 秒采样一次；子插件 battery / prop"

    override fun getVersion(): String = "1.0.0"

    /**
     * 手动执行入口。常驻插件正常情况下不会从「手动执行」Tab 调用，
     * 但子插件调度会走到这里，args 里带 subPluginId。
     */
    override fun execute(proxy: ShizukuProxy, args: Map<String, Any>?): String {
        val subPluginId = args?.get("subPluginId") as? String
            ?: return "这是常驻插件，请在「长期任务」Tab 启动"

        return when (subPluginId) {
            "battery" -> readBattery(proxy)
            "prop" -> {
                val key = args["key"] as? String ?: DEFAULT_PROP
                proxy.getProp(key)
            }
            else -> "未知子插件: $subPluginId"
        }
    }

    override suspend fun runInBackground(
        proxy: ShizukuProxy,
        scope: CoroutineScope,
        dispatcher: SubPluginDispatcher
    ) {
        var round = 0
        while (scope.isActive) {
            round++
            val battery = dispatcher.call("battery")
            val model = dispatcher.call("prop", mapOf("key" to "ro.product.model"))
            android.util.Log.i(TAG, "第 $round 次采样: $battery | 型号=$model")
            delay(SAMPLE_INTERVAL_MS)
        }
    }

    private fun readBattery(proxy: ShizukuProxy): String {
        return proxy.execCommand("dumpsys battery | grep -E 'level|temperature'").trim()
    }

    private companion object {
        const val TAG = "BackgroundMonitor"
        const val DEFAULT_PROP = "ro.product.model"
        const val SAMPLE_INTERVAL_MS = 10_000L
    }
}