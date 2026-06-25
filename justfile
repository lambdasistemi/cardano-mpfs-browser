# shellcheck shell=bash

set unstable := true

# List available recipes
default:
    @just --list

# Build PureScript
build:
    #!/usr/bin/env bash
    set -euo pipefail
    spago build

# Bundle for browser
bundle:
    #!/usr/bin/env bash
    set -euo pipefail
    just prepare-wasm
    mkdir -p dist
    esbuild src/bootstrap.js \
      --bundle \
      --outfile=dist/deps.js \
      --format=iife \
      --platform=browser \
      --loader:.wasm=file \
      --asset-names='[name].[hash]' \
      --public-path=. \
      --minify
    spago bundle --module Main --outfile dist/index.js
    cat dist/deps.js dist/index.js > dist/bundle.js
    mv dist/bundle.js dist/index.js
    rm dist/deps.js

# Watch and rebuild
dev:
    #!/usr/bin/env bash
    set -euo pipefail
    spago build --watch

# Format source files
format:
    #!/usr/bin/env bash
    set -euo pipefail
    purs-tidy format-in-place 'src/**/*.purs'

# Check formatting (CI)
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    purs-tidy check 'src/**/*.purs'

# Full CI pipeline
ci:
    #!/usr/bin/env bash
    set -euo pipefail
    npm ci
    just lint
    just build
    just bundle
    just test

# Prepare the WASM reactor and run tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    just prepare-wasm
    spago test

# Copy the Haskell WASM verifier from the flake input for tests and bundles
prepare-wasm:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p src/assets
    wasm_out="$(nix build --fallback --no-link --print-out-paths .#wasm-mpfs-verify)"
    test -f "$wasm_out/mpfs-verify-reactor.wasm"
    install -m 644 "$wasm_out/mpfs-verify-reactor.wasm" src/assets/mpfs-verify-reactor.wasm

# E2E tests against devnet server
e2e blueprint:
    #!/usr/bin/env bash
    set -euo pipefail
    npm ci
    PORT=$((10000 + RANDOM % 50000))
    MPFS_BLUEPRINT="{{blueprint}}" mpfs-devnet-server --port "$PORT" &
    SERVER_PID=$!
    trap "kill $SERVER_PID 2>/dev/null" EXIT
    for i in $(seq 1 60); do
        if curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/status" 2>/dev/null | grep -q '200'; then
            break
        fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "Server exited unexpectedly"
            exit 1
        fi
        sleep 2
    done
    STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/status" 2>/dev/null)
    if [ "$STATUS" != "200" ]; then
        echo "Server not ready, last status: $STATUS"
        curl -s "http://localhost:$PORT/status" 2>&1 || true
        exit 1
    fi
    just prepare-wasm
    MPFS_BASE_URL="http://localhost:$PORT" spago test

# Serve locally
serve:
    #!/usr/bin/env bash
    set -euo pipefail
    just bundle
    npx serve dist -p 10002

# Clean build artifacts
clean:
    #!/usr/bin/env bash
    rm -rf output/ dist/index.js dist/*.wasm src/assets
