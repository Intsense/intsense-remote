"""Генерация всех иконок IntSense Remote из фирменного знака IntSense.

Использование: python3 make_icons.py <logo-mark.png RGBA> <корень исходников>
Заменяет иконки на месте с теми же размерами, что у оригиналов.
"""
import base64
import io
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

MARK = Image.open(sys.argv[1]).convert("RGBA")
ROOT = sys.argv[2]

# Обрезаем прозрачные поля знака
MARK = MARK.crop(MARK.getbbox())


def fit_mark(size, scale):
    """Знак, вписанный в квадрат size*scale с сохранением пропорций."""
    target = int(size * scale)
    m = MARK.copy()
    m.thumbnail((target, target), Image.LANCZOS)
    return m


def pearl_tile(size):
    """Перламутровая плитка: светлый вертикальный градиент с холодным и тёплым отливом."""
    tile = Image.new("RGBA", (size, size))
    top, bottom = (252, 251, 255), (236, 238, 246)
    px = tile.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        for x in range(size):
            s = x / max(size - 1, 1)
            r = int(top[0] * (1 - t) + bottom[0] * t - 4 * s)
            g = int(top[1] * (1 - t) + bottom[1] * t - 2 * s)
            b = int(top[2] * (1 - t) + bottom[2] * t)
            px[x, y] = (r, g, b, 255)
    return tile


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return m


def strengthen(mark):
    """Чуть насыщеннее и плотнее, чтобы пастельный знак не терялся на светлом фоне."""
    r, g, b, a = mark.split()
    rgb = Image.merge("RGB", (r, g, b))
    from PIL import ImageEnhance
    rgb = ImageEnhance.Color(rgb).enhance(1.6)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.88)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def app_icon(size, macos=False, full_bleed=False):
    """Иконка приложения. macOS: плитка 824/1024 с тенью. full_bleed: без скругления (iOS/Android сами скругляют)."""
    big = 1024
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if macos:
        tile_size, off, radius = 824, 100, 185
    elif full_bleed:
        tile_size, off, radius = big, 0, 0
    else:
        tile_size, off, radius = 960, 32, 210
    tile = pearl_tile(tile_size)
    if radius:
        mask = rounded_mask(tile_size, radius)
        if macos:
            shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
            sm = Image.new("L", (big, big), 0)
            sm.paste(mask, (off, off + 12))
            shadow.putalpha(sm.point(lambda v: int(v * 0.35)))
            shadow = shadow.filter(ImageFilter.GaussianBlur(18))
            canvas = Image.alpha_composite(canvas, shadow)
        tile.putalpha(mask)
    canvas.paste(tile, (off, off), tile)
    mark = strengthen(fit_mark(tile_size, 0.66))
    mx = off + (tile_size - mark.width) // 2
    my = off + (tile_size - mark.height) // 2
    canvas.alpha_composite(mark, (mx, my))
    return canvas.resize((size, size), Image.LANCZOS)


def mono_mark(size, color, scale=0.86):
    """Одноцветный силуэт знака (трей macOS/Windows, значок уведомлений Android)."""
    m = fit_mark(size, scale)
    a = m.split()[3]
    solid = Image.new("RGBA", m.size, color)
    solid.putalpha(a)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(solid, ((size - m.width) // 2, (size - m.height) // 2))
    return out


def foreground(size):
    """Android adaptive foreground: знак в безопасной зоне 66%."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    m = strengthen(fit_mark(size, 0.50))
    out.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return out


def replace_png(path, maker):
    if not os.path.exists(path):
        return
    w, h = Image.open(path).size
    img = maker(max(w, h))
    if (w, h) != img.size:
        img = img.resize((w, h), Image.LANCZOS)
    img.save(path)
    print("png ", path, f"{w}x{h}")


def save_ico(path, maker, sizes=(16, 24, 32, 48, 64, 128, 256)):
    img = maker(256)
    img.save(path, format="ICO", sizes=[(s, s) for s in sizes])
    print("ico ", path)


def svg_wrap(img, size):
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<image width="{size}" height="{size}" xlink:href="data:image/png;base64,{b64}"/></svg>\n')


J = lambda *p: os.path.join(ROOT, *p)

# --- общие (res/) ---
for name in ["icon.png", "32x32.png", "64x64.png", "128x128.png", "128x128@2x.png"]:
    replace_png(J("res", name), lambda s: app_icon(s))
replace_png(J("res", "mac-icon.png"), lambda s: app_icon(s, macos=True))
# Трей macOS: шаблонные иконки (тёмная для светлой темы и наоборот)
replace_png(J("res", "mac-tray-light-x2.png"), lambda s: mono_mark(s, (0, 0, 0, 255)))
replace_png(J("res", "mac-tray-dark-x2.png"), lambda s: mono_mark(s, (255, 255, 255, 255)))
save_ico(J("res", "icon.ico"), lambda s: app_icon(s))
save_ico(J("res", "tray-icon.ico"), lambda s: app_icon(s), sizes=(16, 24, 32, 48, 64))
save_ico(J("flutter", "windows", "runner", "resources", "app_icon.ico"), lambda s: app_icon(s))
for svg in ["icon.svg", "logo.svg", "scalable.svg"]:
    p = J("res", svg)
    if os.path.exists(p):
        open(p, "w").write(svg_wrap(app_icon(512), 512))
        print("svg ", p)

# --- Flutter UI ---
open(J("flutter", "assets", "icon.svg"), "w").write(svg_wrap(app_icon(256), 256))
print("svg ", J("flutter", "assets", "icon.svg"))
app_icon(512).save(J("flutter", "assets", "icon.png"))
print("png ", J("flutter", "assets", "icon.png"))

# --- macOS ---
icns = J("flutter", "macos", "Runner", "AppIcon.icns")
app_icon(1024, macos=True).save(icns, format="ICNS")
print("icns", icns)

# --- iOS (без скругления, iOS скругляет сам; без прозрачности) ---
ios_dir = J("flutter", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
for f in sorted(os.listdir(ios_dir)):
    if f.endswith(".png"):
        replace_png(os.path.join(ios_dir, f), lambda s: app_icon(s, full_bleed=True).convert("RGB"))
launch_dir = J("flutter", "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
for f in sorted(os.listdir(launch_dir)):
    if f.endswith(".png"):
        replace_png(os.path.join(launch_dir, f), lambda s: Image.new("RGBA", (s, s), (0, 0, 0, 0)))

# --- Android ---
res = J("flutter", "android", "app", "src", "main", "res")
for d in sorted(os.listdir(res)):
    if not d.startswith("mipmap-"):
        continue
    replace_png(os.path.join(res, d, "ic_launcher.png"), lambda s: app_icon(s))
    replace_png(os.path.join(res, d, "ic_launcher_round.png"), lambda s: app_icon(s))
    replace_png(os.path.join(res, d, "ic_launcher_foreground.png"), foreground)
    replace_png(os.path.join(res, d, "ic_stat_logo.png"), lambda s: mono_mark(s, (255, 255, 255, 255)))

# Превью для проверки
app_icon(1024, macos=True).save(os.path.join(os.path.dirname(__file__), "preview-macos.png"))
app_icon(512, full_bleed=True).save(os.path.join(os.path.dirname(__file__), "preview-ios.png"))
