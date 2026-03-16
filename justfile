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
