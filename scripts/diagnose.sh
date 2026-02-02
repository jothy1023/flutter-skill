#!/bin/bash

# Flutter Skill Diagnostic Script
# Usage: ./scripts/diagnose.sh [project_path]

PROJECT_PATH="${1:-.}"
cd "$PROJECT_PATH" || exit 1

echo "=================================="
echo "Flutter Skill Diagnostic Report"
echo "=================================="
echo ""
echo "Project Path: $(pwd)"
echo "Date: $(date)"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_flutter() {
    echo "--- Flutter Environment ---"
    if command -v flutter &> /dev/null; then
        echo -e "${GREEN}✅ Flutter installed${NC}"
        flutter --version
    else
        echo -e "${RED}❌ Flutter not found in PATH${NC}"
        return 1
    fi
    echo ""
}

check_pubspec() {
    echo "--- pubspec.yaml Configuration ---"
    if [ -f "pubspec.yaml" ]; then
        echo -e "${GREEN}✅ pubspec.yaml exists${NC}"
        if grep -q "flutter_skill" pubspec.yaml; then
            echo -e "${GREEN}✅ flutter_skill dependency found${NC}"
            grep -A 1 "flutter_skill" pubspec.yaml
        else
            echo -e "${RED}❌ flutter_skill dependency NOT found${NC}"
            echo -e "${YELLOW}Fix: Add to pubspec.yaml dependencies:${NC}"
            echo "  flutter_skill: ^0.4.4"
        fi
    else
        echo -e "${RED}❌ pubspec.yaml not found${NC}"
        echo "This doesn't appear to be a Flutter project"
        return 1
    fi
    echo ""
}

check_main_dart() {
    echo "--- lib/main.dart Configuration ---"
    if [ -f "lib/main.dart" ]; then
        echo -e "${GREEN}✅ lib/main.dart exists${NC}"

        # Check for import
        if grep -q "flutter_skill" lib/main.dart; then
            echo -e "${GREEN}✅ flutter_skill import found${NC}"
        else
            echo -e "${RED}❌ flutter_skill import NOT found${NC}"
            echo -e "${YELLOW}Fix: Add import:${NC}"
            echo "  import 'package:flutter_skill/flutter_skill.dart';"
        fi

        # Check for initialization
        if grep -q "FlutterSkillBinding.ensureInitialized" lib/main.dart; then
            echo -e "${GREEN}✅ FlutterSkillBinding initialization found${NC}"
        else
            echo -e "${RED}❌ FlutterSkillBinding initialization NOT found${NC}"
            echo -e "${YELLOW}Fix: Add to main() function:${NC}"
            echo "  if (kDebugMode) {"
            echo "    FlutterSkillBinding.ensureInitialized();"
            echo "  }"
        fi

        echo ""
        echo "Current main.dart content (first 50 lines):"
        head -50 lib/main.dart
    else
        echo -e "${RED}❌ lib/main.dart not found${NC}"
        return 1
    fi
    echo ""
}

check_running_processes() {
    echo "--- Running Flutter Processes ---"
    if pgrep -f "flutter" > /dev/null; then
        echo -e "${YELLOW}⚠️  Flutter processes found:${NC}"
        ps aux | grep flutter | grep -v grep
    else
        echo -e "${GREEN}✅ No Flutter processes running${NC}"
    fi
    echo ""
}

check_ports() {
    echo "--- Port Usage (VM Service) ---"
    for port in 50000 50001 50002; do
        if lsof -i ":$port" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Port $port is in use:${NC}"
            lsof -i ":$port"
        else
            echo -e "${GREEN}✅ Port $port is available${NC}"
        fi
    done
    echo ""
}

check_flutter_skill_cli() {
    echo "--- Flutter Skill CLI ---"
    if command -v flutter_skill &> /dev/null; then
        echo -e "${GREEN}✅ flutter_skill CLI installed${NC}"
        flutter_skill --version 2>&1 || echo "Version info not available"
    else
        echo -e "${RED}❌ flutter_skill CLI not found${NC}"
        echo -e "${YELLOW}Fix: Install globally:${NC}"
        echo "  dart pub global activate flutter_skill"
    fi
    echo ""
}

# Run all checks
check_flutter
check_flutter_skill_cli
check_pubspec
check_main_dart
check_running_processes
check_ports

echo "=================================="
echo "Diagnostic Complete"
echo "=================================="
echo ""
echo "If you need to fix the configuration, run:"
echo "  flutter_skill setup"
echo ""
echo "Or manually apply the fixes shown above."
echo ""
