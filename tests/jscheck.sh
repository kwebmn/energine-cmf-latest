#!/bin/bash
# Проверка типов JS без сборки: tsc --noEmit по jsconfig.json (checkJs + JSDoc; глобальные имена и свойства на
# элементах описаны в tests/types/*.d.ts). Нужен Node (как для аудитов Playwright); TypeScript берётся через npx —
# первый запуск тянет пакет из сети, дальше из кеша npm. Без Node — провал с подсказкой (пропуск только явно:
# JSCHECK_SKIP=1). Выход: 0 — ошибок нет или пропуск, 1 — ошибки.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -d /root/.nvm/versions/node ] && PATH="$(ls -d /root/.nvm/versions/node/*/bin | tail -1):$PATH"
if ! command -v npx > /dev/null; then
  if [ "${JSCHECK_SKIP:-}" = 1 ]; then echo "SKIP типы JS не проверены (JSCHECK_SKIP=1)"; exit 0; fi
  echo "FAIL нет Node/npx — поставить Node 20 (или JSCHECK_SKIP=1)"; exit 1
fi
out=$(mktemp)
if (cd "$R" && npx -y -p typescript@5 tsc -p jsconfig.json --pretty false > "$out" 2>&1); then
  echo "OK   tsc: ошибок типов в JS нет"; rm -f "$out"; exit 0
fi
echo "FAIL tsc: $(grep -c 'error TS' "$out") ошибок типов"
grep 'error TS' "$out" | sed "s|$R/||" | head -40
rm -f "$out"; exit 1
