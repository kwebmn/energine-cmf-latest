#!/bin/bash
# Установка базы площадки с нуля установщиком (docs/INSTALL.md): снимает ВСЕ таблицы, представления и процедуры
# базы из конфига площадки и ставит заново — setup install (конфиг площадки уже есть: база и домен берутся из
# него) с новым случайным паролем администратора и setup demo; прежние загрузки площадки заменяются основой
# из htdocs/uploads и файлами демо. Пароль пишется в tests/local.php (режим 600, вне git) и не печатается.
#   bash tests/tools/rebuild.sh --yes-drop-everything
set -e
[ "${1:-}" = --yes-drop-everything ] || { echo "rebuild.sh снимает всю базу площадки; запуск: $0 --yes-drop-everything" >&2; exit 2; }
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
envsh=$(php8.5 "$R/tests/env.php" --shell); eval "$envsh"
M() { mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }

echo "== снимаем всё в $DB_NAME"
drops=$(M "SET SESSION group_concat_max_len = 65535; SELECT GROUP_CONCAT(CONCAT('DROP ', IF(TABLE_TYPE = 'VIEW', 'VIEW', 'TABLE'), ' IF EXISTS \`', TABLE_NAME, '\`') SEPARATOR '; ') FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()")
[ -n "$drops" ] && [ "$drops" != NULL ] && M "SET FOREIGN_KEY_CHECKS = 0; $drops; SET FOREIGN_KEY_CHECKS = 1;"
for r in $(M "SELECT CONCAT(ROUTINE_TYPE, ':', ROUTINE_NAME) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()"); do
  M "DROP ${r%%:*} IF EXISTS \`${r#*:}\`"
done

echo "== пароль администратора — в tests/local.php"
# пароль передаётся через окружение, не аргументом
ENERGINE_ADMIN_PASSWORD=$(php8.5 -r 'echo rtrim(strtr(base64_encode(random_bytes(18)), "+/", "-_"), "=");')
export ENERGINE_ADMIN_PASSWORD
(cd "$R" && php8.5 -r '
define("ROOT_DIR", getcwd());
$E = require "tests/env.php";
umask(0077);
file_put_contents("tests/local.php", "<?php\nreturn [\n    \"admin_email\" => " . var_export($E["ADMIN_EMAIL"], true)
    . ",\n    \"admin_password\" => " . var_export(getenv("ENERGINE_ADMIN_PASSWORD"), true)
    . ",\n    \"mailbox\" => " . var_export($E["MAILBOX"], true) . ",\n];\n");')

echo "== загрузки: основа и файлы демо"
rm -rf "$WEB/uploads"
cp -a "$R/htdocs/uploads" "$WEB/"
chown -R "$SITE_USER:$(id -gn "$SITE_USER")" "$WEB" "$(dirname "$R")"

echo "== setup install и setup demo"
setup() { (cd "$WEB" && runuser -u "$SITE_USER" -- php8.5 index.php setup "$@" < /dev/null 2>&1); }
inst=$(setup install --admin-email="$ADMIN_EMAIL" --admin-name=Admin) || { echo "$inst" | tail -8; exit 1; }
out=$(setup demo) || { echo "$out" | tail -8; exit 1; }
unset ENERGINE_ADMIN_PASSWORD
echo "таблиц: $(M "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()"), страниц: $(M 'SELECT COUNT(*) FROM share_sitemap')"
echo "адрес сайта: $(grep -m1 '^Готово: ' <<< "$inst" | cut -d' ' -f2-)"
chown -R "$SITE_USER:$(id -gn "$SITE_USER")" "$WEB" "$(dirname "$R")"
echo "== готово"
