#!/bin/bash
# Бинарник Tailwind CSS (без Node и npm) для пересборки стилей сайта: tools/tailwindcss, версия закреплена,
# сумма сверяется. Сайту бинарник не нужен — собранный main.css лежит в git.
#   bash tools/get-tailwind.sh && php web/index.php setup css
set -eu
VERSION=v4.3.3
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp)
curl -fsSL -o "$tmp" "https://github.com/tailwindlabs/tailwindcss/releases/download/$VERSION/tailwindcss-linux-x64"
mv "$tmp" "$D/tailwindcss"
(cd "$D" && sha256sum -c tailwindcss.sha256) || { rm -f "$D/tailwindcss"; echo "сумма не совпала — файл удалён" >&2; exit 1; }
chmod +x "$D/tailwindcss"
echo "tailwindcss $VERSION: $D/tailwindcss"
