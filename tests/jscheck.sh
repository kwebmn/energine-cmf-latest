#!/bin/bash
# Проверка типов JS без сборки: tsc --noEmit по jsconfig.json (checkJs + JSDoc; глобальные имена и заглушка Jodit —
# tests/types/*.d.ts). Нужен Node (как для аудитов Playwright); TypeScript закреплённой версии берётся через npx —
# первый запуск тянет пакет из сети, дальше из кеша npm. Без Node — провал с подсказкой (пропуск только явно:
# JSCHECK_SKIP=1). JSCHECK_TSC — другая команда вместо «npx … tsc» (самотест).
# Выход: 0 — ошибок нет или пропуск, 1 — ошибки типов или tsc не отработал (тогда печатается его вывод).
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v npx > /dev/null; then
  # Node из nvm владельца машины (аудиты ставились так же): самая новая версия по номеру
  nvm=$(ls -d /root/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1)
  [ -n "$nvm" ] && [ -x "$nvm/npx" ] && PATH="$nvm:$PATH"
fi
if ! command -v npx > /dev/null; then
  if [ "${JSCHECK_SKIP:-}" = 1 ]; then echo "SKIP типы JS не проверены (JSCHECK_SKIP=1)"; exit 0; fi
  echo "FAIL нет Node/npx — поставить Node 20 (или JSCHECK_SKIP=1)"; exit 1
fi
TSC="${JSCHECK_TSC:-npx -y -p typescript@5.9.3 tsc}"
out=$(mktemp)
(cd "$R" && $TSC -p jsconfig.json --pretty false > "$out" 2>&1)
rc=$?
if [ $rc -eq 0 ]; then
  echo "OK   tsc: ошибок типов в JS нет"; rm -f "$out"; exit 0
fi
n=$(grep -c 'error TS' "$out")
if [ "$n" -gt 0 ]; then
  echo "FAIL tsc: $n ошибок типов"
  grep 'error TS' "$out" | sed "s|$R/||" | head -40
else
  echo "FAIL tsc не отработал (код $rc) — npx/npm (сеть при первом запуске?) или сам tsc; вывод:"
  grep -v "^$" "$out" | tail -20
fi
rm -f "$out"; exit 1
