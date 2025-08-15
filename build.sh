#!/bin/bash

# Build script for OmniFocus Claude Extension
# Generates a .dxt file from source files

set -e

echo "🔨 Building OmniFocus Claude Extension..."
echo ""

# Setup directories
SRC_DIR="src"
DIST_DIR="dist"
BUILD_DIR="build"

# Create directories if they don't exist
mkdir -p "$DIST_DIR"
mkdir -p "$BUILD_DIR"

# Read version from manifest
VERSION=$(grep '"version"' "$SRC_DIR/manifest.json" | cut -d '"' -f 4)
echo "📦 Building version: $VERSION"

# Start building the extension.json
echo "📝 Generating extension.json..."

# Copy manifest as base
cp "$SRC_DIR/manifest.json" "$BUILD_DIR/extension.json"

# Add tools array
echo "🔧 Processing tools..."

# Create a temporary file for tools
TOOLS_FILE="$BUILD_DIR/tools.json"
echo '{"tools":[' > "$TOOLS_FILE"

# Process each tool
FIRST_TOOL=true
for tool_file in "$SRC_DIR/tools"/*.json; do
    if [ -f "$tool_file" ]; then
        tool_name=$(basename "$tool_file" .json)
        echo "  📄 Processing: $tool_name"
        
        # Read tool definition
        tool_def=$(cat "$tool_file")
        script_file=$(echo "$tool_def" | grep '"script"' | cut -d '"' -f 4)
        
        # Read the AppleScript
        if [ -f "$SRC_DIR/scripts/$script_file" ]; then
            # Escape the script for JSON
            script_content=$(cat "$SRC_DIR/scripts/$script_file" | \
                sed 's/\\/\\\\/g' | \
                sed 's/"/\\"/g' | \
                sed ':a;N;$!ba;s/\n/\\n/g')
            
            # Add comma if not first tool
            if [ "$FIRST_TOOL" = false ]; then
                echo "," >> "$TOOLS_FILE"
            fi
            FIRST_TOOL=false
            
            # Extract tool properties
            name=$(echo "$tool_def" | grep '"name"' | head -1 | cut -d '"' -f 4)
            description=$(echo "$tool_def" | grep '"description"' | cut -d '"' -f 4)
            
            # Write tool entry
            cat >> "$TOOLS_FILE" << EOF
{
  "name": "$name",
  "description": "$description",
  "parameters": $(echo "$tool_def" | sed -n '/\"parameters\"/,/^  }/p' | tail -n +2),
  "command": "osascript",
  "arguments": [
    "-e",
    "$script_content"
EOF
            
            # Add parameter placeholders
            params=$(echo "$tool_def" | grep -o '"properties":{[^}]*}' | grep -o '"[^"]*":' | grep -o '"[^"]*"' | sed 's/"//g' | grep -v properties)
            for param in $params; do
                echo "    ,\"{{$param}}\"" >> "$TOOLS_FILE"
            done
            
            echo "  ]" >> "$TOOLS_FILE"
            echo "}" >> "$TOOLS_FILE"
        else
            echo "    ⚠️  Script not found: $script_file"
        fi
    fi
done

echo ']}' >> "$TOOLS_FILE"

# Merge manifest with tools using Python (more reliable JSON handling)
echo "🔀 Merging manifest and tools..."
python3 << EOF
import json

# Read manifest
with open('$BUILD_DIR/extension.json', 'r') as f:
    extension = json.load(f)

# Read tools
with open('$TOOLS_FILE', 'r') as f:
    tools_data = json.load(f)

# Merge
extension['tools'] = tools_data['tools']

# Write final extension.json
with open('$BUILD_DIR/extension.json', 'w') as f:
    json.dump(extension, f, indent=2)
EOF

# Create the .dxt file (zip archive)
echo "📦 Creating .dxt archive..."
cd "$BUILD_DIR"
zip -q "../$DIST_DIR/omnifocus-gtd.dxt" extension.json
cd ..

# Clean up
rm -rf "$BUILD_DIR"

# Summary
echo ""
echo "✅ Build complete!"
echo "   Output: $DIST_DIR/omnifocus-gtd.dxt"
echo "   Version: $VERSION"
echo ""
echo "📱 To install: Drag $DIST_DIR/omnifocus-gtd.dxt onto Claude Desktop"