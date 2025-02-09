# List available commands
default:
    @just --list

# Install development dependencies (luarocks, busted, luassert)
install-dev:
    #!/usr/bin/env bash
    set -euo pipefail
    # Check if luarocks is installed
    if ! command -v luarocks &> /dev/null; then
        if command -v brew &> /dev/null; then
            brew install luarocks
        else
            echo "Please install luarocks first:"
            echo "  - macOS: brew install luarocks"
            echo "  - Linux: sudo apt-get install luarocks"
            exit 1
        fi
    fi
    # Install test dependencies
    luarocks install --local busted
    luarocks install --local luassert

# Run tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    # Add local luarocks bin to path
    export PATH="$HOME/.luarocks/bin:$PATH"
    # Add test directory to Lua package path
    export LUA_PATH="${LUA_PATH:-;;}./?.lua;./?/init.lua;;"
    # Run tests
    busted tests/ 