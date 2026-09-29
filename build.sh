#!/usr/bin/env bash
#
# 把一个插件源文件编译成框架可加载的 .jar
#
# 用法:
#   ./build.sh <插件源文件> <mainClass> [宿主接口 classpath]
#
# Java 示例:
#   ./build.sh plugins/DeviceInfoPlugin.java com.plugin.deviceinfo.DeviceInfoPlugin \
#       "/path/to/host-classes.jar:/path/to/android.jar"
#
# Kotlin 示例（后台常驻插件必须用 Kotlin）:
#   KOTLINC_JAR=/path/to/kotlin-compiler-embeddable.jar \
#   KOTLIN_CP="/path/to/kotlin-stdlib.jar:/path/to/kotlinx-coroutines-core-jvm.jar" \
#   ./build.sh plugins/BackgroundMonitor.kt com.plugin.monitor.BackgroundMonitor \
#       "/path/to/host-classes.jar:/path/to/android.jar"
#
# 关键点：
#   1. jar 里必须是 classes.dex，不能是 .class。
#      框架用 DexClassLoader 加载，普通 javac 产物会报
#      "Failed to open dex files from xxx.jar because: Entry not found"。
#   2. 若源文件同目录下存在同名 .properties，会原样作为 META-INF/plugin.properties；
#      没有则自动生成只有 mainClass 的声明文件。
#
# 依赖：JDK 17+、Android SDK build-tools 里的 d8（ANDROID_HOME 或 D8_JAR 指定）

set -euo pipefail

SRC="${1:?用法: build.sh <源文件> <mainClass> [宿主接口classpath]}"
MAIN_CLASS="${2:?缺少 mainClass}"
HOST_CP="${3:-}"

case "$SRC" in
  *.java) KIND=java ;;
  *.kt)   KIND=kotlin ;;
  *) echo "只支持 .java 与 .kt：$SRC" >&2; exit 1 ;;
esac

NAME="$(basename "${SRC%.*}")"
BUILD_DIR="build/$NAME"
CLS_DIR="$BUILD_DIR/classes"
DEX_DIR="$BUILD_DIR/dex"
OUT_JAR="$NAME.jar"
PROPS_SRC="${SRC%.*}.properties"

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

if [ "$KIND" = java ]; then
  echo "[1/4] javac"
  if [ -n "$HOST_CP" ]; then
    javac -encoding UTF-8 -cp "$HOST_CP" -d "$CLS_DIR" "$SRC"
  else
    javac -encoding UTF-8 -d "$CLS_DIR" "$SRC"
  fi
else
  echo "[1/4] kotlinc"
  KOTLINC_JAR="${KOTLINC_JAR:-}"
  KOTLIN_CP="${KOTLIN_CP:-}"
  if [ -z "${KOTLINC_CP:-}" ] && { [ -z "$KOTLINC_JAR" ] || [ ! -f "$KOTLINC_JAR" ]; }; then
    echo "Kotlin 插件需要 KOTLINC_JAR 指向 kotlin-compiler-embeddable jar，或用 KOTLINC_CP 指定完整编译器 classpath" >&2
    exit 1
  fi
  if [ -z "$KOTLIN_CP" ]; then
    echo "Kotlin 插件需要 KOTLIN_CP 指向 kotlin-stdlib（用到协程时还要 kotlinx-coroutines-core）" >&2
    exit 1
  fi
  # kotlin-compiler-embeddable 自身还依赖 kotlin-reflect / script-runtime 等，
  # 缺了会 NoClassDefFoundError。可用 KOTLINC_CP 覆盖完整的编译器 classpath。
  java -cp "${KOTLINC_CP:-$KOTLINC_JAR:$KOTLIN_CP}" org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
    -classpath "$HOST_CP:$KOTLIN_CP" \
    -no-stdlib -jvm-target 1.8 \
    -d "$CLS_DIR" "$SRC"
fi

echo "[2/4] d8 -> classes.dex"
find "$CLS_DIR" -name '*.class' -print0 \
  | xargs -0 java -cp "$D8_JAR" com.android.tools.r8.D8 --min-api 24 --output "$DEX_DIR"

if [ ! -f "$DEX_DIR/classes.dex" ]; then
  echo "d8 未生成 classes.dex" >&2
  exit 1
fi

echo "[3/4] 写入 META-INF/plugin.properties"
if [ -f "$PROPS_SRC" ]; then
  cp "$PROPS_SRC" "$BUILD_DIR/META-INF/plugin.properties"
  echo "  使用 $PROPS_SRC"
else
  printf 'mainClass=%s\n' "$MAIN_CLASS" > "$BUILD_DIR/META-INF/plugin.properties"
  echo "  自动生成 mainClass=$MAIN_CLASS"
fi

if [ -f "$DEX_DIR/classes2.dex" ]; then
  echo "警告：生成了 classes2.dex。框架一次只加载一个 dex 文件，插件类应保持精简。" >&2
fi

echo "[4/4] 打包 $OUT_JAR"
cp "$DEX_DIR/classes.dex" "$BUILD_DIR/classes.dex"
( cd "$BUILD_DIR" && jar cf "../../$OUT_JAR" classes.dex META-INF/plugin.properties )

echo
echo "完成: $OUT_JAR"
unzip -l "$OUT_JAR"