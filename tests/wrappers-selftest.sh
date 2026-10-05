#!/bin/bash
# Самотест обёрток статического анализа (tests/phpstan.sh, tests/jscheck.sh): провал инструмента — не «0 ошибок»,
# а его собственное сообщение; кеш PHPStan после запуска от root принадлежит владельцу площадки (как и всё дерево).
# Подмены для проверки: PHPSTAN_NEON — другой конфиг, JSCHECK_TSC — другая команда вместо npx … tsc.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
ok()  { echo "OK   $1"; }
bad() { echo "FAIL $1${2:+: $2}"; fail=1; }

# 1. сломанный конфиг PHPStan: в выводе — сообщение PHPStan, а не «0 ошибок»
printf 'parameters:\n    level: [\n' > "$T/broken.neon"
out=$(cd "$R" && PHPSTAN_NEON="$T/broken.neon" bash tests/phpstan.sh 2>&1)
if echo "$out" | grep -q "^FAIL" && ! echo "$out" | grep -q "0 ошибок" && echo "$out" | grep -qi "neon\|parse\|error\|ошибк"; then
  ok "phpstan.sh: сломанный конфиг — провал с сообщением PHPStan"
else bad "phpstan.sh: сломанный конфиг — нет сообщения PHPStan" "$(echo "$out" | head -3 | tr '\n' ' ')"; fi

# 2. npx/tsc не отработал (сеть, npm): в выводе — его сообщение, а не «0 ошибок типов»
printf '#!/bin/sh\necho "npm ERR! сеть недоступна" >&2; exit 1\n' > "$T/fake-npx.sh" && chmod +x "$T/fake-npx.sh"
out=$(cd "$R" && JSCHECK_TSC="$T/fake-npx.sh" bash tests/jscheck.sh 2>&1)
if echo "$out" | grep -q "^FAIL" && ! echo "$out" | grep -q "0 ошибок" && echo "$out" | grep -q "npm ERR!"; then
  ok "jscheck.sh: сбой npx — провал с сообщением npm"
else bad "jscheck.sh: сбой npx — нет сообщения npm" "$(echo "$out" | head -3 | tr '\n' ' ')"; fi

# 3. владелец кеша PHPStan после настоящего запуска — владелец дерева (регрессия идёт от root)
if [ -f "$R/tools/phpstan.phar" ]; then
  (cd "$R" && bash tests/phpstan.sh > /dev/null 2>&1) || true
  owner=$(stat -c %U "$R")
  alien=$(find "$R/tests/phpstan/cache" ! -user "$owner" 2>/dev/null | head -3 | sed "s|$R/||" | tr '\n' ' ')
  [ -z "$alien" ] && ok "кеш PHPStan принадлежит $owner" || bad "в кеше PHPStan файлы не владельца $owner" "$alien"
else
  echo "SKIP нет tools/phpstan.phar — владелец кеша не проверен"
fi

echo "== wrappers-selftest failures: $fail"
exit $fail
