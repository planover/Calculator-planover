# 本地一键构建并测试 Calculator-planover 的 Rust 内核。
#
# 在 Windows(MSVC) 上，Rust 链接器需要 MSVC Build Tools 的 bin 与 LIB。
# 下面按本机工具链路径注入 PATH / LIB（CI 用 Ubuntu，无需此步）。

$ErrorActionPreference = "Stop"

# —— MSVC 工具链路径（按本机安装调整）——
$VS = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
$MSVC = "$VS\VC\Tools\MSVC\14.44.35207"
$WINKIT = "C:\Program Files (x86)\Windows Kits\10"

$env:PATH = "$MSVC\bin\Hostx64\x64;" + $env:PATH
$env:LIB = "$MSVC\lib\x64;$WINKIT\Lib\10.0.26100.0\um\x64;$WINKIT\Lib\10.0.26100.0\ucrt\x64"
$env:CARGO_TARGET_DIR = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { "target" }

$EngineDir = Join-Path $PSScriptRoot "..\engine"
Push-Location $EngineDir

Write-Host "==> cargo build (core)" -ForegroundColor Cyan
cargo build -p calculator_core

Write-Host "==> cargo test -p calculator_core (全部用例)" -ForegroundColor Cyan
cargo test -p calculator_core

Pop-Location
Write-Host "完成。" -ForegroundColor Green
