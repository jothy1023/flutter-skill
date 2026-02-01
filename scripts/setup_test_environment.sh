#!/bin/bash
# Flutter Skill Plugin Testing Environment Setup
#
# This script sets up a test environment for VSCode and IntelliJ plugins
#
# Usage:
#   ./scripts/setup_test_environment.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Flutter Skill Plugin Testing Environment Setup${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found. Please install Flutter SDK first.${NC}"
    echo "   Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi
echo -e "${GREEN}  ✓ Flutter SDK found${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠️  Node.js not found. VSCode extension testing will be limited.${NC}"
    echo "   Visit: https://nodejs.org/"
else
    echo -e "${GREEN}  ✓ Node.js found${NC}"
fi

# Step 2: Create test app
echo ""
echo -e "${BLUE}📱 Creating test Flutter application...${NC}"

TEST_APP_DIR="/tmp/flutter_skill_test_app"

if [ -d "$TEST_APP_DIR" ]; then
    echo -e "${YELLOW}⚠️  Test app already exists at $TEST_APP_DIR${NC}"
    read -p "   Delete and recreate? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$TEST_APP_DIR"
    else
        echo "   Using existing test app"
        cd "$TEST_APP_DIR"
        TEST_APP_EXISTS=true
    fi
fi

if [ "$TEST_APP_EXISTS" != "true" ]; then
    flutter create "$TEST_APP_DIR" --platforms=ios,android
    cd "$TEST_APP_DIR"
    echo -e "${GREEN}  ✓ Test app created${NC}"
fi

# Step 3: Add flutter_skill dependency
echo ""
echo -e "${BLUE}📦 Adding flutter_skill dependency...${NC}"

# Check if already added
if grep -q "flutter_skill:" pubspec.yaml; then
    echo -e "${YELLOW}  ⚠️  flutter_skill already in pubspec.yaml${NC}"
else
    # Add dependency
    flutter pub add flutter_skill
    echo -e "${GREEN}  ✓ flutter_skill dependency added${NC}"
fi

# Step 4: Generate test main.dart
echo ""
echo -e "${BLUE}📝 Generating test main.dart...${NC}"

cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_skill/flutter_skill.dart';

void main() {
  // Initialize Flutter Skill
  FlutterSkillBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Skill Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _displayText = 'Tap a button or enter text';
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Skill Test App'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display Text
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _displayText,
                  key: const Key('display_text'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Buttons', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const Key('primary_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Primary Button Tapped!';
                        });
                      },
                      child: const Text('Primary Button'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('secondary_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Secondary Button Tapped!';
                        });
                      },
                      child: const Text('Secondary Button'),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      key: const Key('icon_button'),
                      icon: const Icon(Icons.favorite),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Icon Button Tapped!';
                        });
                      },
                      tooltip: 'Favorite',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Text Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Text Input', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('text_field'),
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Enter text here',
                        border: OutlineInputBorder(),
                        hintText: 'Type something...',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _displayText = 'You typed: $value';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const Key('submit_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Submitted: ${_controller.text}';
                        });
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Counter
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Counter', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '$_counter',
                      key: const Key('counter_text'),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          key: const Key('decrement_button'),
                          onPressed: () {
                            setState(() {
                              _counter--;
                            });
                          },
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          key: const Key('increment_button'),
                          onPressed: () {
                            setState(() {
                              _counter++;
                            });
                          },
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('fab'),
        onPressed: () {
          setState(() {
            _displayText = 'FAB Tapped!';
          });
        },
        tooltip: 'Floating Action Button',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
EOF

echo -e "${GREEN}  ✓ test main.dart generated${NC}"

# Step 5: Get dependencies
echo ""
echo -e "${BLUE}📥 Getting dependencies...${NC}"
flutter pub get
echo -e "${GREEN}  ✓ Dependencies installed${NC}"

# Step 6: Instructions
echo ""
echo -e "${GREEN}✅ Test environment setup complete!${NC}"
echo ""
echo -e "${BLUE}📱 Test app location: ${NC}$TEST_APP_DIR"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📖 Next Steps:${NC}"
echo ""
echo -e "${GREEN}1. Test VSCode Extension:${NC}"
echo "   cd vscode-extension"
echo "   npm install"
echo "   npm run compile"
echo "   # Press F5 in VSCode to start debugging"
echo ""
echo -e "${GREEN}2. Test IntelliJ Plugin:${NC}"
echo "   cd intellij-plugin"
echo "   ./gradlew runIde"
echo ""
echo -e "${GREEN}3. Run Flutter test app:${NC}"
echo "   cd $TEST_APP_DIR"
echo "   flutter run --vm-service-port=50000"
echo ""
echo -e "${GREEN}4. Open test app in IDE:${NC}"
echo "   VSCode: File > Open Folder > $TEST_APP_DIR"
echo "   IntelliJ: File > Open > $TEST_APP_DIR"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📚 Full testing guide: ${NC}docs/PLUGIN_TESTING_GUIDE.md"
echo ""
