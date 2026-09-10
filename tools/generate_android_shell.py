#!/usr/bin/env python3
"""为 Calculator-planover 补齐 Android 原生壳层（gradle 壳 + jniLibs + local.properties）。

在 `flutter build apk` 之前运行（架构 §2.1 / §8.3）。

背景：``gradle-wrapper.jar`` 是二进制、不入库（仓库 ``app/android/`` 下没有
``gradlew`` / wrapper jar）。因此这里用**与当前 Flutter 版本 100% 匹配**的
``flutter create`` 现场生成 android 壳，再把 gradle 壳文件拷回 ``app/android/``。

步骤：
1. ``tempfile.mkdtemp()`` 建临时目录，在其中执行
   ``flutter create --platforms=android --org org.solovyev.android
   --project-name calculator <tmpdir>``，拿到匹配当前 Flutter 版本的 android 壳；
2. 把 ``<tmpdir>/android/gradle`` 目录、``gradlew``、``gradlew.bat`` 拷回
   ``app/android/``（覆盖同名），并 ``chmod +x app/android/gradlew``；
3. 若 ``app/android/settings.gradle.kts`` 不存在，则整目录拷贝
   ``<tmpdir>/android`` 到 ``app/android/``（兜底）；
4. 创建各 ABI 的 jniLibs 目录（放置 Rust cdylib 产物）；
5. 写 ``app/android/local.properties``（用 ``FLUTTER_ROOT``，若已设置）；
6. 清理临时目录。

说明：Gradle / Manifest / Kotlin 文本配置已提交在仓库（``app/android/``），
本脚本只补齐"每台机器不同"（local.properties、gradle 壳）与"按构建产物填充"
（jniLibs 目录骨架）的部分。
"""
import os
import shutil
import subprocess
import sys
import tempfile

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_DIR = os.path.join(PROJECT_ROOT, "app", "android")
JNILIBS = os.path.join(ANDROID_DIR, "app", "src", "main", "jniLibs")
ABIS = ["arm64-v8a", "armeabi-v7a", "x86_64", "x86"]


def generate_shell(tmpdir: str) -> bool:
    """用 flutter 在 tmpdir 生成 android 壳；失败返回 False。"""
    flutter = shutil.which("flutter")
    if flutter is None:
        print(
            "错误：找不到 `flutter`，请确保 Flutter SDK 已安装且在 PATH 中。",
            file=sys.stderr,
        )
        return False
    cmd = [
        flutter,
        "create",
        "--platforms=android",
        "--org",
        "org.solovyev.android",
        "--project-name",
        "calculator",
        tmpdir,
    ]
    print("运行：" + " ".join(cmd))
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"错误：`flutter create` 失败（退出码 {e.returncode}）", file=sys.stderr)
        return False
    return True


def copy_shell(tmp_android: str) -> None:
    """把生成的 android 壳的 gradle 部分拷回 app/android/。"""
    # 2. gradle 目录 + gradlew 脚本（覆盖同名）
    for name in ("gradle", "gradlew", "gradlew.bat"):
        src = os.path.join(tmp_android, name)
        if not os.path.exists(src):
            continue
        dst = os.path.join(ANDROID_DIR, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            os.makedirs(ANDROID_DIR, exist_ok=True)
            shutil.copy2(src, dst)
        print(f"拷贝 {src} -> {dst}")

    # 3. 缺失 settings.gradle.kts 时整目录兜底
    if not os.path.exists(os.path.join(ANDROID_DIR, "settings.gradle.kts")):
        shutil.copytree(tmp_android, ANDROID_DIR, dirs_exist_ok=True)
        print(f"settings.gradle.kts 缺失：整目录拷贝 {tmp_android} -> {ANDROID_DIR}")

    # 让 gradlew 可执行
    gradlew = os.path.join(ANDROID_DIR, "gradlew")
    if os.path.exists(gradlew):
        os.chmod(gradlew, 0o755)
        print(f"已 chmod +x {gradlew}")


def main() -> int:
    os.makedirs(ANDROID_DIR, exist_ok=True)
    tmpdir = tempfile.mkdtemp(prefix="calcplanover_shell_")
    try:
        if not generate_shell(tmpdir):
            return 1
        copy_shell(os.path.join(tmpdir, "android"))

        # 4. jniLibs 目录骨架
        for abi in ABIS:
            os.makedirs(os.path.join(JNILIBS, abi), exist_ok=True)

        # 5. local.properties（用 FLUTTER_ROOT）
        flutter_root = os.environ.get("FLUTTER_ROOT")
        if flutter_root and os.path.isdir(flutter_root):
            with open(
                os.path.join(ANDROID_DIR, "local.properties"),
                "w",
                encoding="utf-8",
            ) as f:
                f.write(f"flutter.sdk={flutter_root}\n")
                f.write("flutter.minSdkVersion=21\n")

        print(f"Android shell ensured under {ANDROID_DIR}")
        return 0
    finally:
        # 6. 清理临时目录
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
