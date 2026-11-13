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
