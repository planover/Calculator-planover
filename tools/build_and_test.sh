#!/usr/bin/env bash
# 本地一键构建并测试 Rust 内核（Linux / macOS / CI 通用）。
set -euo pipefail
cd "$(dirname "$0")/../engine"
echo "==> cargo build (core)"
cargo build -p calculator_core
echo "==> cargo test -p calculator_core"
cargo test -p calculator_core
echo "完成。"
