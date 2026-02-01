#!/bin/bash

# 热重载插件脚本
# 自动化：构建 → 复制到插件目录 → 提示重载

set -e

echo "🔥 Hot Reload IntelliJ Plugin"
echo "============================="
echo ""

# 1. 构建插件
echo "📦 Step 1/3: Building plugin..."
./gradlew buildPlugin -q

PLUGIN_ZIP=$(ls build/distributions/*.zip | head -1)

if [ -z "$PLUGIN_ZIP" ]; then
    echo "❌ Plugin zip not found"
    exit 1
fi

# 解压到临时目录
TEMP_DIR="/tmp/flutter-skill-plugin"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
unzip -q "$PLUGIN_ZIP" -d "$TEMP_DIR"

PLUGIN_DIR=$(ls -d "$TEMP_DIR"/*/ | head -1)

echo "✅ Plugin built: $(basename "$PLUGIN_ZIP")"
echo ""

# 2. 查找 IntelliJ 插件目录
echo "📁 Step 2/3: Locating IntelliJ plugins directory..."

# macOS 的 IntelliJ IDEA 插件目录
IDEA_PLUGINS_DIRS=(
    "$HOME/Library/Application Support/JetBrains/IntelliJIdea2023.3/plugins"
    "$HOME/Library/Application Support/JetBrains/IntelliJIdea2024.1/plugins"
    "$HOME/Library/Application Support/JetBrains/IntelliJIdea2024.2/plugins"
    "$HOME/Library/Application Support/JetBrains/IntelliJIdea2024.3/plugins"
    "$HOME/Library/Application Support/JetBrains/IdeaIC2023.3/plugins"
    "$HOME/Library/Application Support/JetBrains/IdeaIC2024.1/plugins"
)

TARGET_DIR=""
for dir in "${IDEA_PLUGINS_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        TARGET_DIR="$dir"
        break
    fi
done

if [ -z "$TARGET_DIR" ]; then
    echo "⚠️  Could not auto-detect IntelliJ plugins directory"
    echo ""
    echo "📋 Manual Installation:"
    echo "  1. Open IntelliJ IDEA"
    echo "  2. Preferences → Plugins → ⚙️ → Install Plugin from Disk"
    echo "  3. Select: $PLUGIN_ZIP"
    echo "  4. Restart IDE"
    exit 0
fi

echo "✅ Found plugins directory: $TARGET_DIR"
echo ""

# 3. 复制插件
echo "📋 Step 3/3: Installing plugin..."

INSTALLED_PLUGIN="$TARGET_DIR/flutter-skill-intellij"

if [ -d "$INSTALLED_PLUGIN" ]; then
    echo "⚠️  Plugin already installed, removing old version..."
    rm -rf "$INSTALLED_PLUGIN"
fi

cp -r "$PLUGIN_DIR" "$INSTALLED_PLUGIN"

echo "✅ Plugin installed to: $INSTALLED_PLUGIN"
echo ""

# 4. 提示重载
echo "🔥 HOT RELOAD Instructions:"
echo "============================"
echo ""
echo "If IntelliJ IDEA is currently running:"
echo ""
echo "  Option 1 - Soft Reload (recommended, no restart):"
echo "    1. Go to: Preferences → Plugins"
echo "    2. Find: Flutter Skill"
echo "    3. Click: Disable (禁用)"
echo "    4. Click: Enable (启用)"
echo "    → Plugin reloaded in ~5 seconds! ⚡️"
echo ""
echo "  Option 2 - Hard Reload (if soft reload doesn't work):"
echo "    1. Go to: Help → Find Action (⌘⇧A)"
echo "    2. Type: 'Invalidate Caches'"
echo "    3. Select: 'Invalidate Caches and Restart'"
echo "    → Takes ~30 seconds"
echo ""
echo "If IntelliJ IDEA is not running:"
echo "    Just start it normally - new plugin will be loaded"
echo ""
echo "🎯 Done! Total time: ~35 seconds (vs 2 minutes with runIde)"
