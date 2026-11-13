#!/usr/bin/env bash
# IntSense Remote: собирает исходники в этом репозитории из открытого кода
# (релиз 1.5.3) и применяет брендинг IntSense: имя, иконки, цвет, сервер, ключ.
set -euo pipefail
REPO="$(pwd)"
TAG="1.5.3"
PUBKEY="vQb0OuWhGtsuCDkGGS2mDkfdqSa1LHcFqLeA3C8pFX4="
WORK="$(mktemp -d)"
mkdir -p "$WORK/b"

cat > "$WORK/b/rebrand.sh" <<'__END_REBRAND__'
#!/usr/bin/env bash
# Превращает исходники RustDesk 1.5.3 в IntSense Remote.
# Запуск из корня исходников: bash rebrand.sh <публичный ключ сервера>
set -euo pipefail
PUBKEY="${1:?публичный ключ сервера}"
NAME="IntSense"                 # внутреннее имя: пути, службы, бандл (без пробелов)
DISPLAY="IntSense Remote"       # видимое имя там, где пробел безопасен
SERVER="rd.intsense.ai"
BUNDLE_ID="ai.intsense.remote"
SRC_URL="${SRC_URL:-https://github.com/intsense/intsense-remote}"

sub() { # sub файл perl-выражение
  perl -0pi -e "$2" "$1"
}

# 1. Ядро: имя, сервер, ключ
C=libs/hbb_common/src/config.rs
sub $C 's/RwLock::new\("RustDesk"\.to_owned\(\)\)/RwLock::new("'"$NAME"'".to_owned())/'
sub $C 's/RENDEZVOUS_SERVERS: &\[&str\] = &\["rs-ny\.rustdesk\.com"\]/RENDEZVOUS_SERVERS: &[&str] = &["'"$SERVER"'"]/'
sub $C 's/pub const RS_PUB_KEY: &str = "[^"]+"/pub const RS_PUB_KEY: &str = "'"$PUBKEY"'"/'
grep -q "\"$NAME\".to_owned()" $C && grep -q "\"$SERVER\"" $C && grep -q "$PUBKEY" $C

# Проверка обновлений ходила бы на api.rustdesk.com: выключаем полностью
sub src/common.rs 's/pub fn check_software_update\(\) \{\n/pub fn check_software_update() {\n    if true {\n        return; \/\/ IntSense Remote: обновления только из своей сборки\n    }\n/'

# 2. macOS
sub flutter/macos/Runner/Configs/AppInfo.xcconfig 's/PRODUCT_NAME = RustDesk/PRODUCT_NAME = '"$NAME"'/'
sub flutter/macos/Runner/Configs/AppInfo.xcconfig 's/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = '"$BUNDLE_ID"'/'
sub flutter/macos/Runner/Configs/AppInfo.xcconfig 's/PRODUCT_COPYRIGHT = .*/PRODUCT_COPYRIGHT = © 2026 IntSense/'

# 3. iOS
sub flutter/ios/Runner/Info.plist 's#<string>RustDesk</string>#<string>'"$NAME"'</string>#g'
sub flutter/ios/Runner.xcodeproj/project.pbxproj 's/PRODUCT_BUNDLE_IDENTIFIER = com\.carriez\.[A-Za-z0-9_.]+;/PRODUCT_BUNDLE_IDENTIFIER = '"$BUNDLE_ID"';/g'

# 4. Android
A=flutter/android/app/src/main
sub $A/AndroidManifest.xml 's/android:label="RustDesk Input"/android:label="'"$NAME"' Input"/; s/android:label="RustDesk"/android:label="'"$NAME"'"/'
sub $A/res/values/strings.xml 's/RustDesk/'"$NAME"'/g'
sub $A/res/values/ic_launcher_background.xml 's/#ffffff/#F4F4FA/'

# 5. Windows
sub flutter/windows/runner/Runner.rc 's/"RustDesk Remote Desktop"/"'"$DISPLAY"'"/; s/VALUE "ProductName", "RustDesk"/VALUE "ProductName", "'"$NAME"'"/'

# 6. Фирменный цвет вместо синего RustDesk (лавандовый из знака IntSense)
sub flutter/lib/common.dart 's/0xFF0071FF/0xFF6F62C8/g; s/0x770071FF/0x776F62C8/g; s/0xAA0071FF/0xAA6F62C8/g; s/0xFF2C8CFF/0xFF7B6FD6/g'
for f in $(grep -rlI "2c8cff\|2C8CFF" flutter/lib); do sub "$f" 's/0xFF2c8cff/0xFF7B6FD6/gi'; done

# 7. «О программе»: свои ссылки + обязательное по AGPL указание на исходники и авторов
D=flutter/lib/desktop/pages/desktop_setting_page.dart
sub $D "s#launchUrlString\('https://rustdesk.com/privacy.html'\)#launchUrlString('https://intsense.ai')#"
sub $D "s#launchUrlString\('https://rustdesk.com'\);#launchUrlString('$SRC_URL');#"
sub $D "s#'Copyright © \\\$\{DateTime.now\(\).toString\(\).substring\(0, 4\)\} Purslane Tech Pte. Ltd.\\\\n\\\$license'#'IntSense Remote · intsense.ai\\\\n© \\\${DateTime.now().toString().substring(0, 4)} IntSense. Portions © Purslane Tech Pte. Ltd.\\\\nGNU AGPL-3.0, без гарантий. Исходный код: кнопка «Сайт» выше.'#"
sub $D 's/const BoxDecoration\(color: Color\(0xFF2c8cff\)\)/const BoxDecoration(color: Color(0xFF6F62C8))/i'
M=flutter/lib/mobile/pages/settings_page.dart
sub $M "s#'https://rustdesk.com/privacy.html'#'https://intsense.ai'#g; s#'https://rustdesk.com'#'$SRC_URL'#g; s#Text\('rustdesk.com',#Text('intsense.ai',#g"

# 8. CI: имя бандла и файлов
for wf in .github/workflows/flutter-build.yml; do
  sub $wf 's/RustDesk\.app/'"$NAME"'.app/g; s#Contents/MacOS/RustDesk#Contents/MacOS/'"$NAME"'#g'
done



# 9. Заголовок окна (Windows/Linux) написан напрямую, без автозамены
perl -0pi -e 's/child: const Text\(\n(\s*)"RustDesk",/child: const Text(\n$1"IntSense",/' flutter/lib/desktop/widgets/tabbar_widget.dart
echo "rebrand: OK ($NAME, $SERVER)"
__END_REBRAND__

cat > "$WORK/b/make_icons.py" <<'__END_ICONS__'
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
__END_ICONS__

cat > "$WORK/b/logo.b64" <<'__END_LOGO__'
iVBORw0KGgoAAAANSUhEUgAAAd0AAAHzCAMAAABSRTcaAAADAFBMVEX8/PzVuNrO1tHsx9nQu+Gv
yerv09HNxtm1y9fPxOTiutiyu+G70da4tdzkw+Gv0O7u5/H6+fv29frx8/bz6vXP1ubs5uzp1ufp
2uvp1ePt8vXa5u7V1+jt5ObX5OzRrtnW4Nv47fjr3e3hveHZ2erk4uLc6PO5rtPV4+bkzuXj4dzu
5N3SzeLl8fbIruLR2N7grtvf6vjt5d7b4d7m3Nzs3+/v1L/fy9/Oyd3d393e3Ove8vz6zL/kzt/3
7vYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAABeKxj1AAABAHRSTlMA/v7+/v7+/v7+/v7+/v3+iy5Ob3Tzrs2074a10srL/vJV
kv637pT/7dTwz9mn/dP/fLvV13v/vdi+jsD/0j4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
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
dS1g/Q+mK1dz9MUIUQAAAABJRU5ErkJggg==
__END_LOGO__

cat > "$WORK/b/README.md" <<'__END_README__'
# IntSense Remote

Удалённый доступ к своим устройствам (Windows, macOS, Linux, Android; управление с iPhone).
Подключается только к собственному серверу `rd.intsense.ai`. Публичные серверы не используются.

## Сборка

GitHub → **Actions → Flutter Nightly Build → Run workflow**. Готовые файлы появятся в Releases (тег `nightly`) и в артефактах запуска:
- macOS: `*.dmg` (x86_64 и aarch64)
- Windows: `*.exe` / `*.msi`
- Android: `*.apk`
- iOS: `intsense-ios-unsigned-ipa` (подписать своим Apple ID, например через Xcode или Sideloadly)

## Брендинг

`branding/rebrand.sh` и `branding/make_icons.py` применяют имя, иконки, цвет, адрес и ключ сервера.

## Лицензия

Модифицированная версия открытого проекта (GNU AGPL-3.0, см. `LICENCE`), © 2026 IntSense; portions © Purslane Tech Pte. Ltd. Исходный код этой сборки открыт в этом репозитории.
__END_README__

git clone -q --depth 1 --branch "$TAG" https://github.com/rustdesk/rustdesk.git "$WORK/src"
SUB="$(git -C "$WORK/src" ls-tree HEAD libs/hbb_common | awk '{print $3}')"
git clone -q https://github.com/rustdesk/hbb_common.git "$WORK/hbb"
git -C "$WORK/hbb" checkout -q "$SUB"
rm -rf "$WORK/src/.git" "$WORK/src/.gitmodules" "$WORK/src/libs/hbb_common" "$WORK/hbb/.git"
cp -r "$WORK/hbb" "$WORK/src/libs/hbb_common"
mkdir -p "$WORK/src/docs/upstream" "$WORK/src/branding"
mv "$WORK/src/README.md" "$WORK/src/docs/upstream/README-upstream.md"

cd "$WORK/src"
bash "$WORK/b/rebrand.sh" "$PUBKEY"
base64 -d "$WORK/b/logo.b64" > "$WORK/b/logo.png"
python3 "$WORK/b/make_icons.py" "$WORK/b/logo.png" "$WORK/src" > /dev/null
rm -f "$WORK/b/preview-"*.png
cp "$WORK/b/rebrand.sh" "$WORK/b/make_icons.py" "$WORK/b/logo.png" branding/
cp "$WORK/b/README.md" README.md
rm -rf .github   # workflow-файлы живут только в самом репозитории

cd "$REPO"
cp -a "$WORK/src/." ./
echo "bootstrap: OK"
