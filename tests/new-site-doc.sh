#!/bin/bash
# Инструкция новой визитки docs/NEW-SITE.md не устарела: каждая «setup <команда>» есть в установщике
# (Setup::<команда>Action), каждый путь репозитория в `обратных кавычках` существует, шаблоны страниц упомянуты.
# Выход: 0 — всё на месте, 1 — нет.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC=$R/docs/NEW-SITE.md
fail=0
if [ ! -f "$DOC" ]; then echo "FAIL нет docs/NEW-SITE.md"; echo "== new-site-doc failures: 1"; exit 1; fi
for c in $(grep -oE 'setup [a-z]+' "$DOC" | awk '{print $2}' | sort -u); do
  grep -q "function ${c}Action" "$R/setup/Setup.php" && echo "OK   setup $c" || { echo "FAIL setup $c — нет в Setup.php"; fail=$((fail+1)); }
done
# пути: в обратных кавычках, начинаются с каталога репозитория, без подстановок
for p in $(grep -oE '`(core|site|docs|tests|sql|setup|tools|configs|htdocs)/[^` ]+`' "$DOC" | tr -d '`' | grep -v '[<*$]' | sort -u); do
  [ -e "$R/$p" ] && echo "OK   $p" || { echo "FAIL $p — нет в репозитории"; fail=$((fail+1)); }
done
for t in landing service contacts; do
  grep -q "main/$t.content.xml" "$DOC" && echo "OK   шаблон $t" || { echo "FAIL шаблон $t не упомянут"; fail=$((fail+1)); }
done
# перенос на хостинг: сначала setup install (он пишет конфиг площадки), затем база стенда и загруженные файлы
sec=$(sed -n '/^## 6\./,$p' "$DOC")
grep -q 'setup install' <<< "$sec" && grep -q 'web/uploads' <<< "$sec" && ! grep -q 'вместо `setup install`' <<< "$sec" \
  && echo "OK   перенос: установка, затем база и web/uploads" || { echo "FAIL перенос на хостинг: нужен setup install (конфиг), затем база стенда и web/uploads"; fail=$((fail+1)); }
echo "== new-site-doc failures: $fail"
[ $fail -eq 0 ]
