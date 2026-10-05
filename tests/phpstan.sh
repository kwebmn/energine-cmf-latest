#!/bin/bash
# Статический анализ PHP: PHPStan (tools/phpstan.phar — bash tools/get-phpstan.sh, версия закреплена) по phpstan.neon;
# известные ошибки записаны в phpstan-baseline.neon, новые — провал. Исправили ошибку из базовой линии — PHPStan
# сообщит о лишней записи: обновить линию — php8.5 tools/phpstan.phar analyse --generate-baseline.
# Без phar — провал с подсказкой (пропуск только явно: PHPSTAN_SKIP=1). Выход: 0 — чисто или пропуск, 1 — ошибки.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -f "$R/tools/phpstan.phar" ]; then
  if [ "${PHPSTAN_SKIP:-}" = 1 ]; then echo "SKIP PHPStan не запускался (PHPSTAN_SKIP=1)"; exit 0; fi
  echo "FAIL нет tools/phpstan.phar — bash tools/get-phpstan.sh (или PHPSTAN_SKIP=1)"; exit 1
fi
out=$(mktemp)
if (cd "$R" && php8.5 tools/phpstan.phar analyse --no-progress --no-ansi --memory-limit=1G --error-format=raw > "$out" 2>&1); then
  echo "OK   PHPStan: ошибок сверх базовой линии нет"; rm -f "$out"; exit 0
fi
echo "FAIL PHPStan: $(grep -c '^/' "$out") ошибок — новые или лишние записи базовой линии (см. комментарий в tests/phpstan.sh)"
grep '^/' "$out" | sed "s|$R/||" | head -40
rm -f "$out"; exit 1
