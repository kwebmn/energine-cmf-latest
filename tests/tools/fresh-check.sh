#!/bin/bash
# Сверка установки с нуля с базой площадки, не трогая её: временный mariadbd (tempdb.sh), установщик из копии
# точки входа от имени владельца площадки — setup install с доменом площадки и setup demo поверх, — затем
# отпечатки (tests/tools/fingerprint.php) временной базы и базы площадки сравниваются.
#   bash tests/tools/fresh-check.sh
# Выход: 0 — совпало; 1 — различия (печатаются таблицы); 2 — проверка не выполнена.
# FRESH_OUT=каталог — сохранить туда оба отпечатка и diff; FP_ROWS=таблица,… — строки этих таблиц вместо хэшей.
# Каталог экземпляра — в FRESH_TMP (по умолчанию tmp площадки: владельцу площадки нужен проход к сокету).
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FP="$R/tests/tools/fingerprint.php"
. "$R/tests/tools/tempdb.sh"
fail() { echo "fresh-check: $*" >&2; exit 2; }
read -r WEB OWNER ADMIN_LOGIN < <(cd "$R" && php8.5 -r 'define("ROOT_DIR", getcwd()); $E = require "tests/env.php";
  echo $E["WEB"], " ", $E["SITE_USER"], " ", $E["ADMIN_EMAIL"], "\n";') || fail "нет tests/env.php"

TMPDIR=${FRESH_TMP:-$(dirname "$WEB")/tmp} TEMPDB_ACCESS=$OWNER tempdb_start || exit 2
trap tempdb_stop EXIT
tempdb_create fresh && tempdb_user fresh "$T/dbpw" || fail "временная база"
tempsite "$OWNER" "$WEB" && chown "$OWNER" "$T/dbpw" || fail "копия точки входа"
# пароли — в окружении, не в аргументах; пароль администратора временной базы — случайный
ENERGINE_DB_PASSWORD=$(cat "$T/dbpw")
ENERGINE_ADMIN_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
export ENERGINE_DB_PASSWORD ENERGINE_ADMIN_PASSWORD
out=$(tempsite_setup install --config="$S/web/system.config.php" --no-static --domain="$HOST" --db-socket="$SOCK" \
  --db-name=fresh --db-user=energine --admin-email="$ADMIN_LOGIN" --admin-name=Admin) || fail "setup install: $(tail -3 <<< "$out")"
out=$(tempsite_setup demo --config="$S/web/system.config.php" --no-static) || fail "setup demo: $(tail -3 <<< "$out")"

(cd "$R" && php8.5 "$FP") > "$T/live.txt" || fail "отпечаток базы площадки"
FP_SOCKET="$SOCK" FP_DB=fresh FP_USER=root php8.5 "$FP" > "$T/fresh.txt" || fail "отпечаток временной базы"
diff "$T/live.txt" "$T/fresh.txt" > "$T/diff.txt"; rc=$?
if [ -n "${FRESH_OUT:-}" ]; then mkdir -p "$FRESH_OUT" && cp "$T/live.txt" "$T/fresh.txt" "$T/diff.txt" "$FRESH_OUT/"; fi
case $rc in
  0) echo "установка с нуля == база площадки: таблиц $(wc -l < "$T/live.txt")"; exit 0 ;;
  1) echo "различия в таблицах: $(grep '^[<>]' "$T/diff.txt" | awk '{print $2}' | sort -u | tr '\n' ' ')"; exit 1 ;;
  *) fail "diff" ;;
esac
