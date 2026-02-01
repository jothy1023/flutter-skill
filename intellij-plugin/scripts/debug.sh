#!/bin/bash

# 启动插件调试模式
# 支持真正的热重载：修改代码 → Ctrl+F9 → 立即生效，无需重启！

set -e

echo "🔥 IntelliJ Plugin Debug Mode"
echo "=============================="
echo ""
echo "This mode enables TRUE hot reload:"
echo "  1. Start plugin in debug mode"
echo "  2. Connect remote debugger from another IntelliJ"
echo "  3. Modify code → Ctrl+F9 (Reload Changed Classes)"
echo "  4. Changes take effect immediately! No restart needed!"
echo ""
echo "⏳ Starting plugin with debug enabled..."
echo "   Debug port: 5005"
echo "   Opening project: /Users/cw/development/dtok-app"
echo ""

# 启动插件，开启调试端口，并自动打开 Flutter 项目
./gradlew runIde --debug-jvm -Didea.project.to.open=/Users/cw/development/dtok-app &

GRADLE_PID=$!

echo ""
echo "✅ Plugin is starting with debug enabled (PID: $GRADLE_PID)"
echo ""
echo "📋 Next Steps:"
echo "=============="
echo ""
echo "1. Wait for the sandbox IDE to fully start (~30 seconds)"
echo ""
echo "2. In your MAIN IntelliJ IDEA (this one):"
echo "   a. Run → Edit Configurations..."
echo "   b. Click '+' → Remote JVM Debug"
echo "   c. Name: 'Flutter Skill Debug'"
echo "   d. Host: localhost"
echo "   e. Port: 5005"
echo "   f. Click OK"
echo ""
echo "3. Click Debug button (🐛) to connect"
echo ""
echo "4. Now you can:"
echo "   • Set breakpoints in your code"
echo "   • Modify code → Ctrl+F9 (Reload Changed Classes)"
echo "   • Changes applied instantly! No IDE restart! ⚡️"
echo ""
echo "💡 Tips:"
echo "   • Ctrl+F9 = Reload Changed Classes (hot swap)"
echo "   • Works for most code changes (method bodies, etc.)"
echo "   • Doesn't work for: new classes, signature changes"
echo "   • For those, use Ctrl+C to stop, then re-run this script"
echo ""
echo "Press Ctrl+C to stop the debug session..."
echo ""

# 等待
wait $GRADLE_PID
