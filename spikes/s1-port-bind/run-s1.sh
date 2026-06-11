#!/usr/bin/env bash
# S1 runner — proves the privileged-port bind asymmetry as the current (non-root) user.
# Pass/fail is the swift test's exit code; no system state is modified (bind + close only).
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(id -u)" == "0" ]]; then
    echo "Refusing to run as root — S1 must prove NON-root behavior." >&2
    exit 2
fi

swift bind-reality-test.swift
