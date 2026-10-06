#!/bin/bash
# Самотест запуска наборов регрессии (надёжность, этап 5): упавший набор — синтаксическая ошибка bash, фатальная
# ошибка PHP, код выхода без строки FAIL — виден в выводе регрессии строкой «FAIL suite …», а не тишиной (так
# незаметно выпал smoke-write: регрессия считала только строки FAIL). Обычный набор — без лишних строк; набор со
# своими строками FAIL — без строки «упал». Во временном каталоге, площадка не нужна.
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
fail=0
ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1: $2"; fail=$((fail+1)); }
if [ ! -f "$S/suite-lib.sh" ]; then
  echo "FAIL нет tests/suite-lib.sh (функция suite для regression.sh)"; echo "== regression-selftest failures: 1"; exit 1
fi
# shellcheck source=suite-lib.sh
. "$S/suite-lib.sh"
printf '#!/bin/bash\nif [ then\n' > "$T/syntax.sh"
printf '<?php\necho "OK   до падения\\n";\nundefined_function_claude();\n' > "$T/fatal.php"
printf '#!/bin/bash\necho "OK   всё хорошо"; echo "== good failures: 0"\n' > "$T/good.sh"
printf '#!/bin/bash\necho "FAIL проверка: подробности"; echo "== red failures: 1"; exit 1\n' > "$T/red.sh"
printf '#!/bin/bash\necho "что-то пошло не так"; exit 1\n' > "$T/silent.sh"

out=$(suite syntax bash "$T/syntax.sh")
grep -q '^### syntax$' <<<"$out" && grep -q '^FAIL suite syntax: ' <<<"$out" && ok "синтаксическая ошибка bash — строка FAIL suite" \
  || bad "синтаксическая ошибка bash — строка FAIL suite" "$out"
out=$(suite fatal php8.5 "$T/fatal.php")
grep -q '^FAIL suite fatal: ' <<<"$out" && grep -q 'OK   до падения' <<<"$out" && ok "фатальная ошибка PHP — строка FAIL suite, вывод набора сохранён" \
  || bad "фатальная ошибка PHP — строка FAIL suite" "$out"
out=$(suite silent bash "$T/silent.sh")
grep -q '^FAIL suite silent: ' <<<"$out" && ok "код выхода 1 без строки FAIL — строка FAIL suite" || bad "код 1 без строки FAIL" "$out"
out=$(suite good bash "$T/good.sh")
! grep -q '^FAIL' <<<"$out" && grep -q '^== good failures: 0$' <<<"$out" && ok "обычный набор — без лишних строк" || bad "обычный набор" "$out"
out=$(suite red bash "$T/red.sh")
[ "$(grep -c '^FAIL' <<<"$out")" = 1 ] && ok "набор со своей строкой FAIL — без строки «упал»" || bad "набор со своей строкой FAIL" "$out"
# сама регрессия запускает наборы через suite, а все bash-наборы проходят проверку синтаксиса
grep -q '^suite smoke-write bash smoke-write.sh$' "$S/regression.sh" && ! grep -q '^echo "### [a-z-]*"; \(php8.5\|bash\) ' "$S/regression.sh" \
  && ok "regression.sh запускает наборы через suite" || bad "regression.sh запускает наборы через suite" "$(grep -c '^echo "### ' "$S/regression.sh") строк echo ###"
bad_syntax=""
for f in "$S"/*.sh "$S"/tools/*.sh; do bash -n "$f" 2>/dev/null || bad_syntax="$bad_syntax ${f#$S/}"; done
[ -z "$bad_syntax" ] && ok "все bash-наборы и инструменты проходят bash -n" || bad "bash -n" "$bad_syntax"
echo "== regression-selftest failures: $fail"
exit $((fail > 0))
