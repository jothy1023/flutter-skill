#!/bin/bash
# Flutter Skill Uninstall Script
# Removes flutter-skill and all associated files

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

printf '%b\n' "${BLUE}Flutter Skill Uninstall${NC}"
echo ""

removed=0

# 1. Remove npm global package
if command -v npm &> /dev/null; then
    if npm list -g flutter-skill-mcp &> /dev/null; then
        printf '%b\n' "${YELLOW}Removing npm package flutter-skill-mcp...${NC}"
        npm uninstall -g flutter-skill-mcp
        printf '%b\n' "${GREEN}  Removed npm package${NC}"
        removed=$((removed + 1))
    fi
fi

# 2. Remove Homebrew package
if command -v brew &> /dev/null; then
    if brew list flutter-skill &> /dev/null 2>&1; then
        printf '%b\n' "${YELLOW}Removing Homebrew package flutter-skill...${NC}"
        brew uninstall flutter-skill
        printf '%b\n' "${GREEN}  Removed Homebrew package${NC}"
        removed=$((removed + 1))
    fi
fi

# 3. Remove source installation
if [ -d "$HOME/.flutter-skill-src" ]; then
    printf '%b\n' "${YELLOW}Removing source installation...${NC}"
    rm -rf "$HOME/.flutter-skill-src"
    printf '%b\n' "${GREEN}  Removed $HOME/.flutter-skill-src${NC}"
    removed=$((removed + 1))
fi

# 4. Remove wrapper scripts
for wrapper in "$HOME/bin/flutter-skill" "$HOME/.pub-cache/bin/flutter-skill" "$HOME/.pub-cache/bin/flutter_skill"; do
    if [ -f "$wrapper" ]; then
        printf '%b\n' "${YELLOW}Removing wrapper script...${NC}"
        rm -f "$wrapper"
        printf '%b\n' "${GREEN}  Removed $wrapper${NC}"
        removed=$((removed + 1))
    fi
done

# 5. Remove cached binaries
if [ -d "$HOME/.flutter-skill" ]; then
    printf '%b\n' "${YELLOW}Removing cached files...${NC}"
    rm -rf "$HOME/.flutter-skill"
    printf '%b\n' "${GREEN}  Removed $HOME/.flutter-skill${NC}"
    removed=$((removed + 1))
fi

# 6. Remove Dart global activation
if command -v dart &> /dev/null; then
    if dart pub global list 2>/dev/null | grep -q flutter_skill; then
        printf '%b\n' "${YELLOW}Removing Dart global activation...${NC}"
        dart pub global deactivate flutter_skill 2>/dev/null || true
        printf '%b\n' "${GREEN}  Removed Dart global package${NC}"
        removed=$((removed + 1))
    fi
fi

# 7. Remove tool priority rules
RULES_FILE="$HOME/.claude/prompts/flutter-tool-priority.md"
if [ -f "$RULES_FILE" ]; then
    printf '%b\n' "${YELLOW}Removing tool priority rules...${NC}"
    rm -f "$RULES_FILE"
    printf '%b\n' "${GREEN}  Removed $RULES_FILE${NC}"
    removed=$((removed + 1))
fi

# 8. Clean up PATH entries in shell configs
for rcfile in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish"; do
    if [ -f "$rcfile" ]; then
        if grep -q "Flutter Skill" "$rcfile" 2>/dev/null; then
            printf '%b\n' "${YELLOW}Cleaning PATH entry from $rcfile...${NC}"
            # Remove the Flutter Skill PATH block (comment + export line)
            sed -i '' '/# Flutter Skill/d' "$rcfile" 2>/dev/null || sed -i '/# Flutter Skill/d' "$rcfile" 2>/dev/null || true
            sed -i '' '/flutter-skill/d' "$rcfile" 2>/dev/null || sed -i '/flutter-skill/d' "$rcfile" 2>/dev/null || true
            printf '%b\n' "${GREEN}  Cleaned $rcfile${NC}"
            removed=$((removed + 1))
        fi
    fi
done

echo ""
if [ $removed -eq 0 ]; then
    echo "No flutter-skill installation found."
else
    printf '%b\n' "${GREEN}Uninstall complete! Removed $removed items.${NC}"
    printf '%b\n' "${YELLOW}You may need to restart your terminal for PATH changes to take effect.${NC}"
fi
