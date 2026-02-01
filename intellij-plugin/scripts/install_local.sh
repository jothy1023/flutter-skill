#!/bin/bash

# 快速安装到本地 IntelliJ IDEA
# 不需要启动沙盒 IDE，直接在日常使用的 IDE 中测试

set -e

echo "🔨 Building plugin..."
./gradlew buildPlugin

PLUGIN_ZIP=$(ls build/distributions/*.zip | head -1)

if [ -z "$PLUGIN_ZIP" ]; then
    echo "❌ Plugin zip not found"
    exit 1
fi

echo "✅ Plugin built: $PLUGIN_ZIP"
echo ""
echo "📦 Installing to local IntelliJ IDEA..."
echo ""
echo "🔧 Manual Installation Steps:"
echo "  1. Open your IntelliJ IDEA"
echo "  2. Go to: Preferences → Plugins → ⚙️ → Install Plugin from Disk..."
echo "  3. Select: $PLUGIN_ZIP"
echo "  4. Click OK and Restart IDE"
echo ""
echo "⚡️ Or use command line (if IDEA is closed):"
echo ""

# 检测 IntelliJ IDEA 安装路径
if [ -d "/Applications/IntelliJ IDEA.app" ]; then
    echo "open '/Applications/IntelliJ IDEA.app' && sleep 2"
    echo "# Then: Preferences → Plugins → Install from Disk → Select $PLUGIN_ZIP"
else
    echo "# Could not auto-detect IntelliJ IDEA path"
    echo "# Please install manually through: Preferences → Plugins"
fi

echo ""
echo "✨ Benefits:"
echo "  • No need to start sandbox IDE (save 1-2 minutes)"
echo "  • Test in real environment"
echo "  • Keep existing configuration"
echo "  • Instant reload with 'Unload/Reload Plugin'"
