#!/bin/bash
# Стили сайта собраны из исходников: main.css == сборка Tailwind из tailwind.css (бинарник — tools/get-tailwind.sh).
# Без бинарника проверка пропускается (сайт от него не зависит). Выход: 0 — совпало или пропуск, 1 — расхождение.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS=$R/site/modules/main/stylesheets
fail=0
if [ ! -x "$R/tools/tailwindcss" ]; then
  echo "skip: нет tools/tailwindcss — bash tools/get-tailwind.sh"
else
  out=$(mktemp)
  (cd "$CSS" && "$R/tools/tailwindcss" --input tailwind.css --output "$out" --minify > /dev/null 2>&1) \
    && cmp -s "$out" "$CSS/main.css" && echo "OK   main.css собран из tailwind.css" \
    || { echo "FAIL main.css не совпадает со сборкой: php web/index.php setup css"; fail=$((fail+1)); }
  rm -f "$out"
fi
head -c 200 "$CSS/main.css" | grep -q 'tailwindcss v4' && grep -q '@layer components' "$CSS/main.css" \
  && echo "OK   main.css — сборка Tailwind со слоями" || { echo "FAIL main.css — не сборка Tailwind"; fail=$((fail+1)); }
echo "== css failures: $fail"
[ $fail -eq 0 ]
