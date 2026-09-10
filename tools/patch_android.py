#!/usr/bin/env python3
"""把编译好的 Rust cdylib (.so) 打入 Android jniLibs，并落包信息 + 断言。

用法:
    # 打 .so + 落包信息 + 断言（CI 用）
    python3 tools/patch_android.py --artifacts <dir-with-so>

    # 只落包信息 + 断言（本地/无产物时用；不打 .so）
    python3 tools/patch_android.py

职责（架构 §8.3）：
1. 把 <artifacts> 下所有 ``libcalculator_ffi.so`` 按 ABI 拷到
   ``app/android/app/src/main/jniLibs/<abi>/libcalculator_ffi.so``（ABI 由路径中
   的 target triple 推断；未传 ``--artifacts`` 时跳过此步）；
2. 正则改写 ``app/android/app/build.gradle.kts``：
   ``applicationId``、``minSdk = 26``、``targetSdk = 34``；
3. 改写 ``app/android/app/src/main/AndroidManifest.xml`` 的 ``android:label``；
4. **最后 grep 断言上述四项**，任一不符 ``sys.exit(1)``（§8.3 明确"失败即 exit 1"）。

幂等：重复运行结果一致。
"""
import argparse
import os
import re
import shutil
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_APP_DIR = os.path.join(PROJECT_ROOT, "app", "android", "app")
GRADLE_FILE = os.path.join(ANDROID_APP_DIR, "build.gradle.kts")
MANIFEST_FILE = os.path.join(ANDROID_APP_DIR, "src", "main", "AndroidManifest.xml")
JNILIBS = os.path.join(ANDROID_APP_DIR, "src", "main", "jniLibs")

# 期望的包信息（架构 §8.3 基准）
EXPECTED_APPLICATION_ID = "org.solovyev.android.calculator"
EXPECTED_MIN_SDK = 26
EXPECTED_TARGET_SDK = 34
EXPECTED_LABEL = "Calculator-planover"

# cargo ndk 产物目录名 -> Android ABI 名
ABI_MAP = {
    "aarch64-linux-android": "arm64-v8a",
    "armv7-linux-androideabi": "armeabi-v7a",
    "x86_64-linux-android": "x86_64",
    "i686-linux-android": "x86",
}


def find_sos(root: str):
    """递归查找 ``libcalculator_ffi.so``。"""
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if f == "libcalculator_ffi.so":
                yield os.path.join(dirpath, f)


def copy_sos(artifacts_dir: str, so_name: str) -> int:
    """把产物 .so 按 ABI 拷入 jniLibs。返回拷贝数量。"""
    copied = 0
    for so in find_sos(artifacts_dir):
        abi = None
        for triple, android_abi in ABI_MAP.items():
            if triple in so:
                abi = android_abi
                break
        if abi is None:
            print(f"警告：无法从路径推断 ABI，跳过 {so}")
            continue
        dest_dir = os.path.join(JNILIBS, abi)
        os.makedirs(dest_dir, exist_ok=True)
        shutil.copy2(so, os.path.join(dest_dir, so_name))
        copied += 1
        print(f"{so} -> {dest_dir}/{so_name}")
    print(f"已打入 {copied} 个原生库到 {JNILIBS}")
    return copied


def patch_gradle() -> None:
    """改写 build.gradle.kts 的 applicationId / minSdk / targetSdk。"""
    with open(GRADLE_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    text = re.sub(
        r'\bapplicationId\s*=\s*"[^"]*"',
        f'applicationId = "{EXPECTED_APPLICATION_ID}"',
        text,
    )
    text = re.sub(r"\bminSdk\b\s*=\s*\d+", f"minSdk = {EXPECTED_MIN_SDK}", text)
    text = re.sub(
        r"\btargetSdk\b\s*=\s*\d+", f"targetSdk = {EXPECTED_TARGET_SDK}", text
    )
    with open(GRADLE_FILE, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"已改写 {GRADLE_FILE}")


def patch_manifest() -> None:
    """改写 AndroidManifest.xml 的 android:label。"""
    with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
        text = f.read()
    text = re.sub(
        r'android:label\s*=\s*"[^"]*"',
        f'android:label="{EXPECTED_LABEL}"',
        text,
    )
    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"已改写 {MANIFEST_FILE}")


def assert_package_info() -> bool:
    """grep 断言四项包信息均正确；返回是否全部通过。"""
    with open(GRADLE_FILE, "r", encoding="utf-8") as f:
        gradle = f.read()
    with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
        manifest = f.read()

    checks = [
        ("applicationId", f'applicationId = "{EXPECTED_APPLICATION_ID}"', gradle),
        ("minSdk", f"minSdk = {EXPECTED_MIN_SDK}", gradle),
        ("targetSdk", f"targetSdk = {EXPECTED_TARGET_SDK}", gradle),
        ("android:label", f'android:label="{EXPECTED_LABEL}"', manifest),
    ]
    ok = True
    for name, needle, haystack in checks:
        if needle in haystack:
            print(f"断言通过：{name} -> {needle}")
        else:
            print(f"断言失败：未找到 {name}（期望 `{needle}`）", file=sys.stderr)
            ok = False
    return ok


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--artifacts",
        default=None,
        help="包含 .so 的目录（可嵌套）；不传则只落包信息 + 断言",
    )
    ap.add_argument("--so-name", default="libcalculator_ffi.so")
    args = ap.parse_args()

    if args.artifacts:
        copy_sos(args.artifacts, args.so_name)
    else:
        print("未提供 --artifacts：跳过 .so 打入，仅落包信息 + 断言")

    patch_gradle()
    patch_manifest()

    if not assert_package_info():
        print("包信息断言未通过：exit 1", file=sys.stderr)
        return 1
    print("包信息四项断言全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
