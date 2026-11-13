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
