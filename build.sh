#!/usr/bin/env bash
#
# 把一个插件源文件编译成框架可加载的 .jar
#
# 用法:
#   ./build.sh <插件源文件> <mainClass> [宿主接口 classpath]
#
# 示例:
#   ./build.sh plugins/DeviceInfoPlugin.java com.plugin.deviceinfo.DeviceInfoPlugin \
#       /path/to/host-classes.jar:/path/to/android.jar
#
# 关键点：插件 jar 里必须是 classes.dex，不能是 .class。
#   框架用 DexClassLoader 加载，普通 javac 产物的 jar 会报
#   "Failed to open dex files from xxx.jar because: Entry not found"。
#
# 依赖：JDK 17+、Android SDK build-tools 里的 d8（通过 ANDROID_HOME 或 D8_JAR 指定）

set -euo pipefail

SRC="${1:?用法: build.sh <源文件> <mainClass> [宿主接口classpath]}"
MAIN_CLASS="${2:?缺少 mainClass}"
HOST_CP="${3:-}"

NAME="$(basename "${SRC%.java}")"
BUILD_DIR="build/$NAME"
CLS_DIR="$BUILD_DIR/classes"
DEX_DIR="$BUILD_DIR/dex"
OUT_JAR="$NAME.jar"

D8_JAR="${D8_JAR:-}"
if [ -z "$D8_JAR" ]; then
  for candidate in "${ANDROID_HOME:-/opt/android-sdk}"/build-tools/*/lib/d8.jar; do
    [ -f "$candidate" ] && D8_JAR="$candidate"
  done
fi
if [ -z "$D8_JAR" ] || [ ! -f "$D8_JAR" ]; then
  echo "找不到 d8.jar，请设置 D8_JAR，或确保 ANDROID_HOME/build-tools/*/lib/d8.jar 存在" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CLS_DIR" "$DEX_DIR" "$BUILD_DIR/META-INF"

echo "[1/4] javac"
if [ -n "$HOST_CP" ]; then
  javac -cp "$HOST_CP" -d "$CLS_DIR" "$SRC"
else
  javac -d "$CLS_DIR" "$SRC"
fi

echo "[2/4] d8 -> classes.dex"
find "$CLS_DIR" -name '*.class' -print0 \
  | xargs -0 java -cp "$D8_JAR" com.android.tools.r8.D8 --min-api 24 --output "$DEX_DIR"

if [ ! -f "$DEX_DIR/classes.dex" ]; then
  echo "d8 未生成 classes.dex" >&2
  exit 1
fi

echo "[3/4] 写入 META-INF/plugin.properties"
printf 'mainClass=%s\n' "$MAIN_CLASS" > "$BUILD_DIR/META-INF/plugin.properties"

if [ -f "$DEX_DIR/classes2.dex" ]; then
  echo "警告：生成了 classes2.dex。框架一次只加载一个 dex 文件，插件类应保持精简。" >&2
fi

echo "[4/4] 打包 $OUT_JAR"
cp "$DEX_DIR/classes.dex" "$BUILD_DIR/classes.dex"
( cd "$BUILD_DIR" && jar cf "../../$OUT_JAR" classes.dex META-INF/plugin.properties )

echo
echo "完成: $OUT_JAR"
unzip -l "$OUT_JAR"