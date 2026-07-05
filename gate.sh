#!/usr/bin/env bash
set -euo pipefail
nix develop --quiet -c bash -c 'just lint && just build && just bundle && just verify-cage-config && just test'
