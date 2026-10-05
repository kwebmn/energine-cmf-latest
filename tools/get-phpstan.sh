#!/bin/bash
# PHPStan (phar, без Composer) для статического анализа PHP: tools/phpstan.phar, версия закреплена, сумма сверяется.
# Сайту не нужен — только разработчику: bash tests/phpstan.sh (в регрессии) или php8.5 tools/phpstan.phar analyse.
#   bash tools/get-phpstan.sh && bash tests/phpstan.sh
set -eu
VERSION=2.2.17
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp)
curl -fsSL -o "$tmp" "https://github.com/phpstan/phpstan/releases/download/$VERSION/phpstan.phar"
mv "$tmp" "$D/phpstan.phar"
(cd "$D" && sha256sum -c phpstan.phar.sha256) || { rm -f "$D/phpstan.phar"; echo "сумма не совпала — файл удалён" >&2; exit 1; }
echo "phpstan $VERSION: $D/phpstan.phar"
