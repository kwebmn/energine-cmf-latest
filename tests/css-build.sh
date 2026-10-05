#!/bin/bash
# Стили собраны из исходников: main.css == сборка tailwind.css (тема сайта), admin.css == сборка admin.tailwind.css
# (админка) — бинарник tools/get-tailwind.sh, пересборка — setup css.
# Без бинарника — провал с подсказкой (пропуск только явно: CSS_BUILD_SKIP=1). Выход: 0 — совпало или пропуск, 1 — нет.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS=$R/site/modules/main/stylesheets
fail=0
if [ ! -x "$R/tools/tailwindcss" ]; then
  if [ "${CSS_BUILD_SKIP:-}" = 1 ]; then echo "SKIP сборка не проверена (CSS_BUILD_SKIP=1)"
  else echo "FAIL нет tools/tailwindcss — bash tools/get-tailwind.sh (или CSS_BUILD_SKIP=1)"; fail=1; fi
else
  for pair in "$R/site/modules/main/stylesheets tailwind.css main.css" "$R/core/modules/share/stylesheets admin.tailwind.css admin.css"; do
    set -- $pair
    out=$(mktemp)
    (cd "$1" && "$R/tools/tailwindcss" --input "$2" --output "$out" --minify > /dev/null 2>&1) \
      && cmp -s "$out" "$1/$3" && echo "OK   $3 собран из $2" \
      || { echo "FAIL $3 не совпадает со сборкой: php web/index.php setup css"; fail=$((fail+1)); }
    rm -f "$out"
  done
fi
head -c 200 "$CSS/main.css" | grep -q 'tailwindcss v4' && grep -q '@layer components' "$CSS/main.css" \
  && echo "OK   main.css — сборка Tailwind со слоями" || { echo "FAIL main.css — не сборка Tailwind"; fail=$((fail+1)); }
# «&» в классе XSLT записывается как &amp; — сканер Tailwind такой класс не узнаёт (стили молча не собираются):
# для вложенных элементов — свои варианты @custom-variant в tailwind.css и admin.tailwind.css
ADM=$R/core/modules/share/stylesheets/admin.css
head -c 200 "$ADM" 2>/dev/null | grep -q 'tailwindcss v4' && grep -q '@layer admin' "$ADM" \
  && echo "OK   admin.css — сборка Tailwind со слоями" || { echo "FAIL admin.css — не сборка Tailwind"; fail=$((fail+1)); }
# утилиты админки (слой utilities) — только с префиксом a: (иначе совпали бы с классами ядра и утилитами сайта)
bare=$(sed 's/.*@layer utilities{//' "$ADM" 2>/dev/null | grep -o '}\.[a-z][a-z0-9-]*{' | grep -v '^}\.a\\:' | head -5 | tr '\n' ' ')
[ -z "$bare" ] && echo "OK   в admin.css нет утилит без префикса a:" || { echo "FAIL правила без префикса в admin.css: $bare"; fail=$((fail+1)); }
amp=$(grep -rn 'class="[^"]*&amp;' --include=*.xslt "$R/core" "$R/site" | sed "s|$R/||")
[ -z "$amp" ] && echo "OK   в классах XSLT нет «&amp;»" || { echo "FAIL «&amp;» в классе XSLT: $amp"; fail=$((fail+1)); }
echo "== css failures: $fail"
[ $fail -eq 0 ]
