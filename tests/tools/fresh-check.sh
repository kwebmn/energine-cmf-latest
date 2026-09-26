#!/bin/bash
# Сверка установки с нуля, не трогая базу площадки: временный mariadbd (свой каталог и сокет, без сети)
# получает файлы установки в порядке docs/INSTALL.md и строки доменов, которые делает setup install;
# его отпечаток (tests/tools/fingerprint.php) сравнивается с отпечатком базы площадки.
#   bash tests/tools/fresh-check.sh
# Выход: 0 — совпало; 1 — различия (печатаются таблицы); 2 — проверка не выполнена.
# FRESH_OUT=каталог — сохранить туда оба отпечатка и diff; FP_ROWS=таблица,… — строки этих таблиц вместо хэшей.
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FP="$R/tests/tools/fingerprint.php"
# короткие имена: путь сокета ограничен 107 символами
T=$(mktemp -d "${TMPDIR:-/tmp}/f.XXXX") || exit 2
SOCK="$T/s"
stop() {
  if [ -s "$T/mysqld.pid" ]; then
    kill "$(cat "$T/mysqld.pid")" 2>/dev/null
    for _ in $(seq 100); do [ -e "$T/mysqld.pid" ] || break; sleep 0.1; done
  fi
  rm -rf "$T"
}
trap stop EXIT
fail() { echo "fresh-check: $*" >&2; exit 2; }
[ ${#SOCK} -le 107 ] || fail "путь сокета длиннее 107 символов, задайте короткий TMPDIR: $SOCK"
M() { env -u MYSQL_PWD mariadb --no-defaults --socket="$SOCK" -u root "$@"; }

# настройки, от которых зависят схема и данные, — как у сервера площадки; адрес и корень сайта — из конфига
settings=$(cd "$R" && php8.5 -r '
define("ROOT_DIR", getcwd());
$E = require "tests/env.php";
$p = new PDO("mysql:host={$E["DB_HOST"]};dbname={$E["DB_NAME"]};charset=utf8", $E["DB_USER"], $E["MYSQL_PWD"]);
$v = $p->query("SELECT @@character_set_server, @@collation_server, @@sql_mode")->fetch(PDO::FETCH_NUM);
echo implode("\n", [...$v, parse_url($E["BASE"], PHP_URL_HOST)]), "\n";') || fail "нет настроек сервера площадки"
{ read -r CS; read -r CO; read -r SQLMODE; read -r HOST; } <<< "$settings"

mariadb-install-db --no-defaults --user=root --datadir="$T/data" --auth-root-authentication-method=normal \
  --skip-test-db > "$T/install.log" 2>&1 || fail "mariadb-install-db: $(tail -3 "$T/install.log")"
mariadbd --no-defaults --user=root --datadir="$T/data" --socket="$SOCK" --pid-file="$T/mysqld.pid" \
  --skip-networking --character-set-server="$CS" --collation-server="$CO" --sql-mode="$SQLMODE" \
  --innodb-buffer-pool-size=256M --secure-file-priv="$T" --log-error="$T/error.log" &
for _ in $(seq 150); do M -e 'SELECT 1' > /dev/null 2>&1 && break; sleep 0.2; done
M -e 'SELECT 1' > /dev/null 2>&1 || fail "временный mariadbd не запустился: $(tail -3 "$T/error.log")"

M -e "CREATE DATABASE fresh CHARACTER SET $CS COLLATE $CO" || fail "CREATE DATABASE"
cd "$R/sql" || fail "нет каталога sql"
for f in starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql \
         starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo.content.sql $(ls cut/stage*.sql | sort -V); do
  M --default-character-set=utf8 fresh < "$f" 2> "$T/import.err" || fail "импорт $f: $(tail -3 "$T/import.err")"
done
# setup install (updateSitesTable) и rebuild.sh: домен площадки по http и https
M fresh -e "
  SET @n := (SELECT COUNT(*) FROM share_domains);
  SET @first := (SELECT domain_host FROM share_domains LIMIT 1);
  UPDATE share_domains SET domain_host = '$HOST', domain_root = '/' WHERE @n = 1 OR (@n > 1 AND @first = '');
  INSERT INTO share_domains (domain_host, domain_root) SELECT '$HOST', '/' FROM DUAL WHERE @n = 0;
  INSERT INTO share_domain2site (site_id, domain_id) SELECT 1, LAST_INSERT_ID() FROM DUAL WHERE @n = 0;
  INSERT IGNORE INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES ('https', 443, '$HOST', '/');
  INSERT IGNORE INTO share_domain2site (domain_id, site_id) SELECT domain_id, 1 FROM share_domains WHERE domain_host = '$HOST';" \
  || fail "строки доменов"

(cd "$R" && php8.5 "$FP") > "$T/live.txt" || fail "отпечаток базы площадки"
FP_SOCKET="$SOCK" FP_DB=fresh FP_USER=root php8.5 "$FP" > "$T/fresh.txt" || fail "отпечаток временной базы"
diff "$T/live.txt" "$T/fresh.txt" > "$T/diff.txt"; rc=$?
if [ -n "${FRESH_OUT:-}" ]; then mkdir -p "$FRESH_OUT" && cp "$T/live.txt" "$T/fresh.txt" "$T/diff.txt" "$FRESH_OUT/"; fi
case $rc in
  0) echo "установка с нуля == база площадки: таблиц $(wc -l < "$T/live.txt")"; exit 0 ;;
  1) echo "различия в таблицах: $(grep '^[<>]' "$T/diff.txt" | awk '{print $2}' | sort -u | tr '\n' ' ')"; exit 1 ;;
  *) fail "diff" ;;
esac
