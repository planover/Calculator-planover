#!/usr/bin/env python3
"""为 Calculator-planover 生成 Android 原生壳层目录。

在 `flutter create` 之后、构建 APK 之前运行，确保：
- 创建各 ABI 的 jniLibs 目录（放置 Rust cdylib 产物）；
- 生成 `app/android/local.properties` 指向本机 Flutter SDK（若存在）。

说明：Gradle / Manifest / Kotlin 源码已提交在仓库（app/android/），本脚本只补齐
"每台机器不同"的部分（local.properties）与"按构建产物填充"的 jniLibs 目录骨架。
"""
import os
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_DIR = os.path.join(PROJECT_ROOT, "app", "android")
JNILIBS = os.path.join(ANDROID_DIR, "app", "src", "main", "jniLibs")
ABIS = ["arm64-v8a", "armeabi-v7a", "x86_64", "x86"]


def main() -> int:
    for abi in ABIS:
        os.makedirs(os.path.join(JNILIBS, abi), exist_ok=True)

    flutter_root = os.environ.get("FLUTTER_ROOT")
    if flutter_root and os.path.isdir(flutter_root):
        with open(
            os.path.join(ANDROID_DIR, "local.properties"), "w", encoding="utf-8"
        ) as f:
            f.write(f"flutter.sdk={flutter_root}\n")
            f.write("flutter.minSdkVersion=21\n")

    print(f"Android shell ensured under {ANDROID_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
