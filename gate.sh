#!/usr/bin/env bash
set -euo pipefail
# #63 foundation gate
just lint
just build
just bundle
just verify-cage-config
just test
