#!/bin/zsh
# Собирает Clipster.app (Apple Silicon + Intel) без Xcode и упаковывает в build/Clipster.zip.
# С флагом --install кладёт приложение в /Applications и перезапускает.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --triple arm64-apple-macosx14.0
swift build -c release --triple x86_64-apple-macosx14.0

APP=build/Clipster.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
    .build/arm64-apple-macosx/release/Clipster \
    .build/x86_64-apple-macosx/release/Clipster \
    -output "$APP/Contents/MacOS/Clipster"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" build/Clipster.zip
echo "Собрано: $APP и build/Clipster.zip"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Clipster 2>/dev/null || true
    rm -rf /Applications/Clipster.app
    cp -R "$APP" /Applications/Clipster.app
    open /Applications/Clipster.app
    echo "Установлено и запущено: /Applications/Clipster.app"
fi
