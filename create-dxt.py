#!/usr/bin/env python3

import json
import zipfile
import os
from pathlib import Path

# Define paths
script_dir = Path(__file__).parent
build_dir = script_dir / "build-temp-fixed"
dist_dir = script_dir / "dist"
output_file = dist_dir / "omnifocus-gtd-fixed.dxt"

# Ensure dist directory exists
dist_dir.mkdir(exist_ok=True)

# Create DXT archive
with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as dxt:
    # Add manifest.json
    manifest_path = build_dir / "manifest.json" 
    dxt.write(manifest_path, "manifest.json")
    
    # Add server.js
    server_path = build_dir / "server.js"
    dxt.write(server_path, "server.js")

print(f"✅ Created fixed DXT extension: {output_file}")
print(f"📦 Size: {output_file.stat().st_size / 1024:.2f} KB")
print("\n🎉 Installation:")
print("   Drag the .dxt file onto Claude Desktop to install")
print("\n💡 If it still crashes, check:")
print("   • OmniFocus is installed and running")
print("   • Claude Desktop has permission to run scripts")
print("   • Node.js is available in your PATH")
