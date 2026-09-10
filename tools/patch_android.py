#!/usr/bin/env python3
"""把编译好的 Rust cdylib (.so) 打入 Android jniLibs。

用法:
    python3 tools/patch_android.py --artifacts <dir-with-so>

把 <artifacts> 下所有 `libcalculator_ffi.so` 按 ABI 目录拷贝到
`app/android/app/src/main/jniLibs/<abi>/libcalculator_ffi.so`。
ABI 由文件路径中的 target triple 推断（与 cargo ndk 产物布局一致）。
"""
import argparse
import os
import shutil
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(
    PROJECT_ROOT, "app", "android", "app", "src", "main", "jniLibs"
)
# cargo ndk 产物目录名 -> Android ABI 名
ABI_MAP = {
    "aarch64-linux-android": "arm64-v8a",
    "armv7-linux-androideabi": "armeabi-v7a",
    "x86_64-linux-android": "x86_64",
    "i686-linux-android": "x86",
}


def find_sos(root: str):
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if f == "libcalculator_ffi.so":
                yield os.path.join(dirpath, f)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifacts", required=True, help="包含 .so 的目录（可嵌套）")
    ap.add_argument("--so-name", default="libcalculator_ffi.so")
    args = ap.parse_args()

    copied = 0
    for so in find_sos(args.artifacts):
        abi = None
        for triple, android_abi in ABI_MAP.items():
            if triple in so:
                abi = android_abi
                break
        if abi is None:
            print(f"警告：无法从路径推断 ABI，跳过 {so}")
            continue
        dest_dir = os.path.join(TARGET, abi)
        os.makedirs(dest_dir, exist_ok=True)
        shutil.copy2(so, os.path.join(dest_dir, args.so_name))
        copied += 1
        print(f"{so} -> {dest_dir}/{args.so_name}")

    print(f"已打入 {copied} 个原生库到 {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
