#!/usr/bin/env bash
set -euo pipefail

: "${MPFS_BASE_URL:=https://umpfs.plutimus.com}"
export MPFS_BASE_URL

spago test --main Test.MPFS.LiveTokensSmoke
