#!/bin/bash

# OmniFocus Claude Extension Installation Script
# This script helps install the extension to Claude Desktop

echo "🚀 OmniFocus Claude Extension Installer"
echo "========================================"
echo ""

# Check if the extension file exists
if [ ! -f "omnifocus-gtd.dxt" ]; then
    echo "❌ Error: omnifocus-gtd.dxt not found in current directory"
    echo "Please run this script from the repository root."
    exit 1
fi

# Check if Claude Desktop is installed
if [ ! -d "/Applications/Claude.app" ]; then
    echo "⚠️  Warning: Claude Desktop doesn't appear to be installed"
    echo "Please install Claude Desktop first from: https://claude.ai/download"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if OmniFocus is installed
if [ ! -d "/Applications/OmniFocus 3.app" ] && [ ! -d "/Applications/OmniFocus.app" ]; then
    echo "⚠️  Warning: OmniFocus doesn't appear to be installed"
    echo "Please install OmniFocus first from: https://www.omnigroup.com/omnifocus"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Prerequisites check complete"
echo ""
echo "📦 Installation Instructions:"
echo "1. Open Claude Desktop"
echo "2. Drag the omnifocus-gtd.dxt file onto the Claude Desktop window"
echo "3. Grant permission when prompted"
echo ""
echo "Would you like to:"
echo "1) Open the folder containing the extension file"
echo "2) Copy the extension to your Desktop for easy access"
echo "3) View the README"
echo "4) Exit"
echo ""
read -p "Choose an option (1-4): " choice

case $choice in
    1)
        echo "Opening folder..."
        open .
        ;;
    2)
        echo "Copying to Desktop..."
        cp omnifocus-gtd.dxt ~/Desktop/
        echo "✅ Extension copied to Desktop"
        open ~/Desktop
        ;;
    3)
        echo "Opening README..."
        if command -v mdless &> /dev/null; then
            mdless README.md
        elif command -v less &> /dev/null; then
            less README.md
        else
            cat README.md
        fi
        ;;
    4)
        echo "Goodbye!"
        ;;
    *)
        echo "Invalid option"
        ;;
esac

echo ""
echo "🎉 Thank you for using OmniFocus Claude Extension!"
echo "For support, please visit: https://github.com/yourusername/omnifocus-claude-extension"