#!/bin/bash
# Установка базы площадки с нуля по docs/INSTALL.md: снимает ВСЕ таблицы, представления и процедуры
# базы из конфига площадки и ставит заново — восемь файлов полной системы, переходные скрипты
# sql/cut/stage*.sql по порядку, случайный пароль администратора (в tests/local.php),
# setup install, HTTPS-домен, загрузки из архива без файлов из sql/cut/stage*.files.
#   bash tests/tools/rebuild.sh --yes-drop-everything
# Архив загрузок: DEMO_UPLOADS (по умолчанию — снимок демо-стенда new.energine.org).
set -e
[ "$1" = --yes-drop-everything ] || { echo "rebuild.sh снимает всю базу площадки; запуск: $0 --yes-drop-everything" >&2; exit 2; }
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEMO_UPLOADS=${DEMO_UPLOADS:-/var/www/clients/client1/web93/private/project/backup/uploads-demo-20260914-164112.tar.gz}
envsh=$(php8.5 "$R/tests/env.php" --shell); eval "$envsh"
# входные данные проверяются до того, как что-то снято: без архива площадка осталась бы без загрузок
[ -r "$DEMO_UPLOADS" ] && tar tzf "$DEMO_UPLOADS" > /dev/null 2>&1 \
  || { echo "нет архива загрузок или он не читается: $DEMO_UPLOADS — база и файлы не тронуты" >&2; exit 2; }
HOST=${BASE#https://}
M() { mysql -N --default-character-set=utf8mb4 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "$1"; }

echo "== снимаем всё в $DB_NAME"
drops=$(M "SET SESSION group_concat_max_len = 65535; SELECT GROUP_CONCAT(CONCAT('DROP ', IF(TABLE_TYPE = 'VIEW', 'VIEW', 'TABLE'), ' IF EXISTS \`', TABLE_NAME, '\`') SEPARATOR '; ') FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()")
[ -n "$drops" ] && [ "$drops" != NULL ] && M "SET FOREIGN_KEY_CHECKS = 0; $drops; SET FOREIGN_KEY_CHECKS = 1;"
for r in $(M "SELECT CONCAT(ROUTINE_TYPE, ':', ROUTINE_NAME) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()"); do
  M "DROP ${r%%:*} IF EXISTS \`${r#*:}\`"
done

echo "== база: восемь файлов и переходные скрипты"
cd "$R/sql"
for f in starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql \
         starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo.content.sql $(ls cut/stage*.sql | sort -V); do
  mysql --default-character-set=utf8 -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$f"
done
echo "таблиц: $(M "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()"), страниц: $(M 'SELECT COUNT(*) FROM share_sitemap')"

echo "== пароль администратора"
cd "$R"
php8.5 -r '
define("ROOT_DIR", getcwd());
$E = require "tests/env.php";
$pw = rtrim(strtr(base64_encode(random_bytes(18)), "+/", "-_"), "=");
$pdo = new PDO("mysql:host={$E["DB_HOST"]};dbname={$E["DB_NAME"]};charset=utf8", $E["DB_USER"], $E["MYSQL_PWD"]);
$st = $pdo->prepare("UPDATE user_users SET u_password = ? WHERE u_name = ?");
$st->execute([password_hash($pw, PASSWORD_DEFAULT), $E["ADMIN_EMAIL"]]);
umask(0077);
file_put_contents("tests/local.php", "<?php\nreturn [\n    \"admin_email\" => " . var_export($E["ADMIN_EMAIL"], true) . ",\n    \"admin_password\" => " . var_export($pw, true) . ",\n    \"mailbox\" => " . var_export($E["MAILBOX"], true) . ",\n];\n");
echo "строк: ", $st->rowCount(), "\n";'

echo "== загрузки"
rm -rf "$WEB/uploads"
tar xzf "$DEMO_UPLOADS" -C "$WEB/"
for list in $(ls "$R"/sql/cut/stage*.files 2>/dev/null | sort -V); do (cd "$WEB" && xargs -a "$list" rm -f); done
chown -R "$SITE_USER:$(id -gn "$SITE_USER")" "$WEB" "$(dirname "$R")"

echo "== setup install"
(cd "$WEB" && runuser -u "$SITE_USER" -- php8.5 index.php setup install > /dev/null)
M "INSERT IGNORE INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES ('https', 443, '$HOST', '/');
   INSERT IGNORE INTO share_domain2site (domain_id, site_id) SELECT domain_id, 1 FROM share_domains WHERE domain_host = '$HOST';"
echo "домены: $(M "SELECT GROUP_CONCAT(CONCAT(domain_protocol, ':', domain_port, ' ', domain_host)) FROM share_domains")"
chown -R "$SITE_USER:$(id -gn "$SITE_USER")" "$WEB" "$(dirname "$R")"
echo "== готово"
