#!/bin/bash
# Стили сайта собраны из исходников: main.css == сборка Tailwind из tailwind.css (бинарник — tools/get-tailwind.sh).
# Без бинарника — провал с подсказкой (пропуск только явно: CSS_BUILD_SKIP=1). Выход: 0 — совпало или пропуск, 1 — нет.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS=$R/site/modules/main/stylesheets
fail=0
if [ ! -x "$R/tools/tailwindcss" ]; then
  if [ "${CSS_BUILD_SKIP:-}" = 1 ]; then echo "SKIP сборка не проверена (CSS_BUILD_SKIP=1)"
  else echo "FAIL нет tools/tailwindcss — bash tools/get-tailwind.sh (или CSS_BUILD_SKIP=1)"; fail=1; fi
else
  out=$(mktemp)
  (cd "$CSS" && "$R/tools/tailwindcss" --input tailwind.css --output "$out" --minify > /dev/null 2>&1) \
    && cmp -s "$out" "$CSS/main.css" && echo "OK   main.css собран из tailwind.css" \
    || { echo "FAIL main.css не совпадает со сборкой: php web/index.php setup css"; fail=$((fail+1)); }
  rm -f "$out"
fi
head -c 200 "$CSS/main.css" | grep -q 'tailwindcss v4' && grep -q '@layer components' "$CSS/main.css" \
  && echo "OK   main.css — сборка Tailwind со слоями" || { echo "FAIL main.css — не сборка Tailwind"; fail=$((fail+1)); }
# «&» в классе XSLT записывается как &amp; — сканер Tailwind такой класс не узнаёт (стили молча не собираются):
# для вложенных элементов — свои варианты @custom-variant в tailwind.css
amp=$(grep -rn 'class="[^"]*&amp;' --include=*.xslt "$R/core" "$R/site" | sed "s|$R/||")
[ -z "$amp" ] && echo "OK   в классах XSLT нет «&amp;»" || { echo "FAIL «&amp;» в классе XSLT: $amp"; fail=$((fail+1)); }
echo "== css failures: $fail"
[ $fail -eq 0 ]
