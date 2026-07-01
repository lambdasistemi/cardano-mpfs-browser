#!/usr/bin/env bash
set -euo pipefail
# dev.plutimus preview ticket #60 gate
just lint
just build
just bundle
just verify-cage-config
just test
