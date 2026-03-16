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
    spago bundle

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

# Generate test vectors and run tests
test:
    #!/usr/bin/env bash
    set -euo pipefail
    nix run .#cage-test-vectors > test/fixtures/cage-vectors.json
    spago test

# E2E tests against devnet server
e2e blueprint:
    #!/usr/bin/env bash
    set -euo pipefail
    PORT=18713
    MPFS_BLUEPRINT="{{blueprint}}" mpfs-devnet-server --port "$PORT" &
    SERVER_PID=$!
    trap "kill $SERVER_PID 2>/dev/null" EXIT
    for i in $(seq 1 60); do
        if curl -sf "http://localhost:$PORT/status" >/dev/null 2>&1; then
            break
        fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "Server exited unexpectedly"
            exit 1
        fi
        sleep 2
    done
    if ! curl -sf "http://localhost:$PORT/status" >/dev/null 2>&1; then
        echo "Server failed to start within timeout"
        exit 1
    fi
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
    rm -rf output/ dist/index.js
