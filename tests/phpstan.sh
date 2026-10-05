#!/bin/bash
# Статический анализ PHP: PHPStan (tools/phpstan.phar — bash tools/get-phpstan.sh, версия закреплена) по phpstan.neon;
# известные ошибки записаны в phpstan-baseline.neon, новые — провал. Исправили ошибку из базовой линии — PHPStan
# сообщит о лишней записи: обновить линию — php8.5 tools/phpstan.phar analyse --generate-baseline (из корня репозитория).
# Без phar — провал с подсказкой (пропуск только явно: PHPSTAN_SKIP=1). PHPSTAN_NEON — другой конфиг (самотест).
# Выход: 0 — чисто или пропуск, 1 — ошибки или PHPStan не отработал (тогда печатается его вывод).
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEON="${PHPSTAN_NEON:-phpstan.neon}"
if [ ! -f "$R/tools/phpstan.phar" ]; then
  if [ "${PHPSTAN_SKIP:-}" = 1 ]; then echo "SKIP PHPStan не запускался (PHPSTAN_SKIP=1)"; exit 0; fi
  echo "FAIL нет tools/phpstan.phar — bash tools/get-phpstan.sh (или PHPSTAN_SKIP=1)"; exit 1
fi
out=$(mktemp)
(cd "$R" && php8.5 tools/phpstan.phar analyse -c "$NEON" --no-progress --no-ansi --memory-limit=1G --error-format=raw > "$out" 2>&1)
rc=$?
# регрессия идёт от root — кеш анализатора (tests/phpstan/cache) возвращается владельцу дерева, как и всё остальное
[ "$(id -u)" = 0 ] && [ -d "$R/tests/phpstan/cache" ] && chown -R --reference="$R" "$R/tests/phpstan/cache" 2>/dev/null
if [ $rc -eq 0 ]; then
  echo "OK   PHPStan: ошибок сверх базовой линии нет"; rm -f "$out"; exit 0
fi
# raw: «файл:строка:текст»; ошибки без файла (конфиг, неподошедшая запись линии) — «?:?:текст»
n=$(grep -c '^/\|^?:' "$out")
if [ "$n" -gt 0 ]; then
  echo "FAIL PHPStan: $n ошибок — новые или лишние записи базовой линии (см. комментарий в tests/phpstan.sh)"
  grep '^/\|^?:' "$out" | sed "s|$R/||" | head -40
else
  echo "FAIL PHPStan не отработал (код $rc) — конфиг, память или сам анализатор; его вывод:"
  sed "s|$R/||" "$out" | grep -v "^$" | tail -20
fi
rm -f "$out"; exit 1
