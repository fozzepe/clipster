#!/bin/zsh
# Установка Clipster одной командой:
#   curl -fsSL https://raw.githubusercontent.com/fozzepe/clipster/main/install.sh | zsh
#
# Скачивает последний релиз с GitHub, кладёт Clipster.app в «Программы» и запускает.
# Пароль не нужен. Файл, скачанный через curl, macOS не помечает как «из интернета»,
# поэтому окна «не удаётся проверить разработчика» не будет.
set -euo pipefail

URL="https://github.com/fozzepe/clipster/releases/latest/download/Clipster.zip"
DEST="${CLIPSTER_INSTALL_DIR:-/Applications}"

major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major < 14 )); then
    echo "Clipster работает на macOS 14 и новее, а у тебя $(sw_vers -productVersion)."
    exit 1
fi

# Без прав администратора в /Applications не записать: ставим в личную папку программ.
if [[ ! -w "$DEST" ]]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Скачиваю Clipster…"
curl -fL --progress-bar "$URL" -o "$TMP/Clipster.zip"
ditto -x -k "$TMP/Clipster.zip" "$TMP"

pkill -x Clipster 2>/dev/null || true
rm -rf "$DEST/Clipster.app"
mv "$TMP/Clipster.app" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/Clipster.app" 2>/dev/null || true

echo "Готово: $DEST/Clipster.app"
if [[ -z "${CLIPSTER_NO_LAUNCH:-}" ]]; then
    open "$DEST/Clipster.app"
    echo "Clipster запущен. Разреши ему «Универсальный доступ», когда macOS спросит, и жми ⌘E."
fi
