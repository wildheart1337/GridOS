#!/bin/bash
# Двойной клик по этому файлу собирает GridOS на вашем Mac и кладёт его в «Программы».
set -euo pipefail
cd "$(dirname "$0")"

echo "== Сборка GridOS =="

if ! xcrun --find swift >/dev/null 2>&1; then
    echo
    echo "Нужны инструменты командной строки Apple (это не Xcode, около 1–2 ГБ)."
    echo "Сейчас появится окно установки: нажмите «Установить» и дождитесь окончания."
    echo "Потом снова дважды кликните по этому файлу."
    xcode-select --install || true
    read -r -p "Нажмите Enter, чтобы закрыть окно…"
    exit 1
fi

VERSION="${VERSION:-1.0.0}" ./Scripts/package-app.sh

echo
echo "== Установка в «Программы» =="
osascript -e 'tell application "GridOS" to quit' >/dev/null 2>&1 || true
pkill -x GridOS >/dev/null 2>&1 || true
rm -rf /Applications/GridOS.app
cp -R dist/GridOS.app /Applications/
xattr -dr com.apple.quarantine /Applications/GridOS.app 2>/dev/null || true
open /Applications/GridOS.app

echo
echo "Готово! GridOS запущен: значок сетки в строке меню сверху справа."
read -r -p "Нажмите Enter, чтобы закрыть окно…"
