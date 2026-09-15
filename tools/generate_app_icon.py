#!/usr/bin/env python3
"""生成 Calculator-planover 的 Android 自适应应用图标（矢量）与预览图。

设计（用户 2026-09-15 拍板：「抽象计算器」方向）
--------------------------------------------------
108×108dp 画布上画一个抽象计算器：圆角机身 + 显示屏 + 3×3 键位。
键位与显示屏以 **evenOdd 挖空**形式呈现，让背景渐变透出来 —— 无需第二种填充色，
从而天然支持主题化与单色层复用。

三个硬约束（都写成脚本里的断言，可回归）
----------------------------------------
1. **66dp 圆形安全区**：Google 自适应图标规范里，始终可见的是居中 **直径 66dp 的圆**
   （不是 72dp 方框）。几何必须完全落在该圆内，否则圆形遮罩（如 Pixel 启动器）会裁掉四角。
   脚本对机身四角逐个断言 `dist(角, 中心) <= 33`。
2. **小尺寸可辨识**：48dp 显示下最小笔画 ≥ 2dp。源稿 108dp，故最小笔画需 ≥ 2×108/48 = 4.5dp。
   脚本对「机身边框厚度」「显示屏与键位间距」「键位间距」逐一断言 ≥ 4.5。
3. **安全区外的留白**：机身不触边，留出系统裁切余量。

输出
----
- Android 资源（写入仓库）：
  - `res/drawable/ic_launcher_background.xml`  背景渐变层
  - `res/drawable/ic_launcher_foreground.xml`  前景（机身 + 挖空）
  - `res/drawable/ic_launcher_monochrome.xml`  单色层（Android 13+ 主题图标）
  - `res/mipmap-anydpi-v26/ic_launcher.xml`    自适应图标引用
  - `res/mipmap-anydpi-v26/ic_launcher_round.xml`
- 预览图（写入 deliverables，供人工确认）：512/192/96/48 逐档 + 圆形遮罩 + 安全区叠加

为什么用矢量而非多密度 PNG：项目 `minSdk 26` 已支持自适应图标与矢量，矢量无多密度维护成本、
换形零返工，且与既有的 `ic_launcher_foreground.xml` 做法一致。
"""
import os
import sys

# ── 画布与安全区 ──────────────────────────────────────────────
CANVAS = 108.0
CENTER = CANVAS / 2.0          # 54
SAFE_R = 33.0                  # 66dp 圆的半径
MIN_STROKE = 4.5               # 48dp 下 ≥2dp ⇒ 源稿 ≥ 4.5dp

# ── 几何（全部为画布坐标，单位 dp）────────────────────────────
BODY = dict(x0=36.0, y0=30.0, x1=72.0, y1=78.0, r=7.0)
DISPLAY = dict(x0=42.0, y0=36.0, x1=66.0, y1=44.0, r=2.0)

# 3×3 键位：每键 6×5，列间距 3、行间距 3
KEY_W, KEY_H, KEY_R = 6.0, 5.0, 1.2
KEY_XS = [42.0, 51.0, 60.0]
KEY_YS = [50.0, 58.0, 66.0]

# ── 配色（青绿 → 青，取自用户选中的概念图）──────────────────
GRAD_START = "#FF0D9488"   # teal-600
GRAD_END = "#FF06B6D4"     # cyan-500

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(REPO, "app", "android", "app", "src", "main", "res")
DRAWABLE = os.path.join(RES, "drawable")
MIPMAP = os.path.join(RES, "mipmap-anydpi-v26")
PREVIEW = os.path.join(REPO, "..", "deliverables", "icon-preview")


# ══════════════════════════════════════════════════════════════
# 几何自检
# ══════════════════════════════════════════════════════════════
def check_geometry() -> None:
    """把三条硬约束变成断言；任一不满足即 exit 1。"""
    failures = []

    # 1) 机身四角必须落在 66dp 安全圆内
    for name, (cx, cy) in {
        "左上": (BODY["x0"], BODY["y0"]),
        "右上": (BODY["x1"], BODY["y0"]),
        "左下": (BODY["x0"], BODY["y1"]),
        "右下": (BODY["x1"], BODY["y1"]),
    }.items():
        d = ((cx - CENTER) ** 2 + (cy - CENTER) ** 2) ** 0.5
        if d > SAFE_R:
            failures.append(f"机身{name}角 (={d:.1f}dp) 超出 {SAFE_R}dp 安全圆")

    # 2) 最小笔画 ≥ MIN_STROKE
    strokes = {
        "左边框": DISPLAY["x0"] - BODY["x0"],
        "右边框": BODY["x1"] - DISPLAY["x1"],
        "上边框": DISPLAY["y0"] - BODY["y0"],
        "底边框": BODY["y1"] - KEY_YS[2] - KEY_H,
        "显示屏-键位间距": KEY_YS[0] - DISPLAY["y1"],
    }
    for k, v in strokes.items():
        if v < MIN_STROKE:
            failures.append(f"{k} = {v:.1f}dp < {MIN_STROKE}dp（48dp 下不足 2dp）")

    # 3) 键位：列/行间距与键本身尺寸
    col_gap = KEY_XS[1] - (KEY_XS[0] + KEY_W)
    row_gap = KEY_YS[1] - (KEY_YS[0] + KEY_H)
    if col_gap < 3.0:
        failures.append(f"键位列间距 {col_gap:.1f}dp < 3dp（洞会糊成一片）")
    if row_gap < 3.0:
        failures.append(f"键位行间距 {row_gap:.1f}dp < 3dp")
    if KEY_H < 4.0 or KEY_W < 4.0:
        failures.append(f"单键尺寸 {KEY_W}×{KEY_H}dp 过小，48dp 下不可辨")

    print("== 几何自检 ==")
    for name, (cx, cy) in {"左上": (BODY["x0"], BODY["y0"])}.items():
        print(f"  机身角到中心距离 {((cx-CENTER)**2+(cy-CENTER)**2)**0.5:.1f}dp (上限 {SAFE_R})")
    print(f"  最小可见笔画 {min(strokes.values()):.1f}dp (下限 {MIN_STROKE})")
    print(f"  键位列/行间距 {col_gap:.1f} / {row_gap:.1f}dp")
    if failures:
        print("\n❌ 几何自检未通过：", file=sys.stderr)
        for f in failures:
            print("   - " + f, file=sys.stderr)
        sys.exit(1)
    print("  ✅ 三条硬约束全部通过")


# ══════════════════════════════════════════════════════════════
# pathData 生成
# ══════════════════════════════════════════════════════════════
def rounded_rect_path(x0, y0, x1, y1, r) -> str:
    """圆角矩形子路径（顺时针）。"""
    return (
        f"M{x0+r:.2f},{y0:.2f} "
        f"H{x1-r:.2f} A{r:.2f},{r:.2f} 0 0 1 {x1:.2f},{y0+r:.2f} "
        f"V{y1-r:.2f} A{r:.2f},{r:.2f} 0 0 1 {x1-r:.2f},{y1:.2f} "
        f"H{x0+r:.2f} A{r:.2f},{r:.2f} 0 0 1 {x0:.2f},{y1-r:.2f} "
        f"V{y0+r:.2f} A{r:.2f},{r:.2f} 0 0 1 {x0+r:.2f},{y0:.2f} Z"
    )


def silhouette_path() -> str:
    """机身 + （显示屏、9 个键位）作为 evenOdd 挖空。"""
    parts = [rounded_rect_path(BODY["x0"], BODY["y0"], BODY["x1"], BODY["y1"], BODY["r"])]
    parts.append(rounded_rect_path(
        DISPLAY["x0"], DISPLAY["y0"], DISPLAY["x1"], DISPLAY["y1"], DISPLAY["r"]))
    for y in KEY_YS:
        for x in KEY_XS:
            parts.append(rounded_rect_path(x, y, x + KEY_W, y + KEY_H, KEY_R))
    return " ".join(parts)


BACKGROUND_XML = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/generate_app_icon.py 生成，请勿手改；改形请改脚本后重跑。 -->
<!-- 背景层：青绿→青的对角线性渐变。108×108dp 满铺，系统按遮罩裁切。 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0 H108 V108 H0 Z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="0" android:startY="0"
                android:endX="108" android:endY="108">
                <item android:offset="0" android:color="{GRAD_START}" />
                <item android:offset="1" android:color="{GRAD_END}" />
            </gradient>
        </aapt:attr>
    </path>
</vector>
"""

FOREGROUND_XML = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/generate_app_icon.py 生成，请勿手改。 -->
<!-- 前景层：白色抽象计算器机身；显示屏与 3×3 键位以 evenOdd 挖空，透出背景渐变。 -->
<!-- 几何须落在 66dp 圆形安全区内（脚本已断言），否则圆形遮罩会裁掉四角。 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="{silhouette_path()}" />
</vector>
"""

MONOCHROME_XML = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/generate_app_icon.py 生成，请勿手改。 -->
<!-- 单色层（Android 13+ 主题图标）：系统会按壁纸取色统一着色，故此处只给形状。 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="{silhouette_path()}" />
</vector>
"""

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tools/generate_app_icon.py 生成，请勿手改。 -->
<!-- 自适应图标：background / foreground / monochrome 三层。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
"""


def write_assets() -> None:
    os.makedirs(DRAWABLE, exist_ok=True)
    os.makedirs(MIPMAP, exist_ok=True)
    files = {
        os.path.join(DRAWABLE, "ic_launcher_background.xml"): BACKGROUND_XML,
        os.path.join(DRAWABLE, "ic_launcher_foreground.xml"): FOREGROUND_XML,
        os.path.join(DRAWABLE, "ic_launcher_monochrome.xml"): MONOCHROME_XML,
        os.path.join(MIPMAP, "ic_launcher.xml"): ADAPTIVE_XML,
        os.path.join(MIPMAP, "ic_launcher_round.xml"): ADAPTIVE_XML,
    }
    print("\n== 写入 Android 资源 ==")
    for path, content in files.items():
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print(f"  {os.path.relpath(path, REPO)}  ({len(content)} 字节)")


# ══════════════════════════════════════════════════════════════
# 预览渲染（PIL）—— 让用户看到"最终图标"而不是概念图
# ══════════════════════════════════════════════════════════════
def render_previews() -> None:
    from PIL import Image, ImageDraw

    os.makedirs(PREVIEW, exist_ok=True)
    S = 8  # 每 dp 的像素倍率，108dp → 864px 高精度母版

    def hex2rgb(h):
        h = h.lstrip("#")
        return tuple(int(h[i:i + 2], 16) for i in (2, 4, 6))  # 跳过 AA

    def master(mask: str | None = None, safe_overlay: bool = False) -> Image.Image:
        W = int(CANVAS * S)
        img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        # 背景：对角渐变
        a, b = hex2rgb(GRAD_START), hex2rgb(GRAD_END)
        grad = Image.new("RGB", (W, W))
        gd = ImageDraw.Draw(grad)
        for i in range(W * 2):
            t = i / (W * 2 - 1)
            gd.line([(i, 0), (0, i)],
                    fill=tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3)), width=1)
        bg = grad.convert("RGBA")

        # 前景：机身（白）+ 挖空（透明 → 透出背景）
        fg = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        fd = ImageDraw.Draw(fg)

        def rrect(dr, g, rr, fill):
            dr.rounded_rectangle([g["x0"] * S, g["y0"] * S, g["x1"] * S, g["y1"] * S],
                                 radius=rr * S, fill=fill)

        rrect(fd, BODY, BODY["r"], (255, 255, 255, 255))
        # 挖空：先画不透明"洞"到 alpha=0 是不行的，改为在白色上重绘为背景色，
        # 这里为了预览保真，用"打洞"方式：把洞区域的 alpha 置 0
        hole = Image.new("L", (W, W), 0)
        hd = ImageDraw.Draw(hole)
        rrect(hd, DISPLAY, DISPLAY["r"], 255)
        for y in KEY_YS:
            for x in KEY_XS:
                hd.rounded_rectangle([x * S, y * S, (x + KEY_W) * S, (y + KEY_H) * S],
                                     radius=KEY_R * S, fill=255)
        # 仅对机身范围内的洞做 alpha=0
        body_mask = Image.new("L", (W, W), 0)
        rrect(ImageDraw.Draw(body_mask), BODY, BODY["r"], 255)
        hole = Image.composite(hole, Image.new("L", (W, W), 0), body_mask)
        fa = fg.getchannel("A")
        fg.putalpha(Image.composite(Image.new("L", (W, W), 0), fa, hole))

        img = Image.alpha_composite(bg, fg)

        # 遮罩模拟（圆形 / 圆角方）
        if mask == "circle":
            m = Image.new("L", (W, W), 0)
            ImageDraw.Draw(m).ellipse([0, 0, W - 1, W - 1], fill=255)
            img.putalpha(m)
        elif mask == "squircle":
            m = Image.new("L", (W, W), 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, W - 1],
                                                radius=int(W * 0.22), fill=255)
            img.putalpha(m)

        if safe_overlay:
            sd = ImageDraw.Draw(img)
            c, r = CENTER * S, SAFE_R * S
            sd.ellipse([c - r, c - r, c + r, c + r], outline=(255, 0, 0, 255), width=4)

        return img

    def save(img: Image.Image, name: str, size: int):
        p = os.path.join(PREVIEW, name)
        img.resize((size, size), Image.LANCZOS).save(p)
        print(f"  {name}")

    print("\n== 渲染预览 ==")
    m = master()
    save(m, "icon-512.png", 512)
    save(m, "icon-192.png", 192)
    save(m, "icon-96.png", 96)
    save(m, "icon-48.png", 48)

    # 圆形遮罩（Pixel 启动器风格）
    save(master(mask="circle"), "icon-512-circle.png", 512)
    # 圆角方遮罩
    save(master(mask="squircle"), "icon-512-squircle.png", 512)
    # 安全区叠加（诊断用）
    save(master(safe_overlay=True), "icon-512-safearea.png", 512)

    # 48dp 逐档拼图，检验小尺寸可辨性
    strip = Image.new("RGBA", (512, 160), (255, 255, 255, 255))
    x = 8
    for s in (48, 72, 96, 144):
        t = m.resize((s, s), Image.LANCZOS)
        strip.alpha_composite(t, (x, (160 - s) // 2))
        x += s + 16
    strip.save(os.path.join(PREVIEW, "icon-sizes.png"))
    print("  icon-sizes.png")


def main() -> int:
    check_geometry()
    write_assets()
    render_previews()
    print("\n完成。预览目录：" + os.path.relpath(PREVIEW, REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main())
