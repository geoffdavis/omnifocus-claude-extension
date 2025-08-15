#!/bin/bash
# Wrapper script to launch the Node.js MCP server

# Find node in common locations
if command -v node &> /dev/null; then
    NODE_CMD="node"
elif [ -x "/usr/local/bin/node" ]; then
    NODE_CMD="/usr/local/bin/node"
elif [ -x "/opt/homebrew/bin/node" ]; then
    NODE_CMD="/opt/homebrew/bin/node"
else
    echo "Error: Node.js not found" >&2
    exit 1
fi

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Launch the server
exec "$NODE_CMD" "$DIR/index.js"
