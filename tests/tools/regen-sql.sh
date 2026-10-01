#!/bin/bash
# Файлы установки из перехода базы: нынешние sql/structure.sql, data.sql и demo.sql ставятся во временный экземпляр
# MariaDB (tempdb.sh), поверх — sql/cut/stage7.sql (его можно запускать повторно), и три файла выгружаются
# заново в прежнем формате:
#   sql/structure.sql — схема и хранимые процедуры (без DEFINER и счётчиков AUTO_INCREMENT);
#   sql/data.sql      — базовые данные пустого сайта: корень, служебные страницы и админка и всё, что под ними;
#   sql/demo.sql      — демо-контент поверх базовых данных.
# Так изменение базы пишется один раз — в переходе, — а новая установка получает то же (fresh-check.sh сверяет).
# Каждая строка базы попадает в data.sql или demo.sql, иначе — отказ (таблица, которой нет в списках ниже).
# sql/demo/uploads не трогается.
#   bash tests/tools/regen-sql.sh            — с переходом
#   REGEN_NO_MIGRATION=1 bash …/regen-sql.sh — без него (проверка генератора: файлы выходят те же)
# Выход: 0 — файлы записаны, 1 — не все строки выгружены, 2 — не выполнено.
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$R/tests/tools/tempdb.sh"
tempdb_start || exit 2
trap tempdb_stop EXIT
tempdb_create g || exit 2
for f in structure.sql data.sql demo.sql; do
  TM --default-character-set=utf8mb4 g < "$R/sql/$f" || { echo "импорт $f" >&2; exit 2; }
done
last=$(ls "$R"/sql/cut/stage*.sql | sed -E 's/.*stage([0-9]+)\.sql$/\1/' | sort -n | tail -1)
if [ -z "${REGEN_NO_MIGRATION:-}" ] && [ -f "$R/sql/cut/stage7.sql" ]; then
  TM --default-character-set=utf8mb4 g < "$R/sql/cut/stage7.sql" > /dev/null || { echo "stage7.sql" >&2; exit 2; }
else
  last=6
fi
Q() { TM -N g -e "$1"; }
# строка «sandbox mode» — команда клиента mariadb, для установщика на PDO это пустой запрос: убирается;
# время (TIMESTAMP) — в поясе сервера, как при загрузке файлов: иначе каждый прогон сдвигал бы его на смещение UTC
D() { mariadb-dump --no-defaults --socket="$SOCK" -u root --default-character-set=utf8mb4 --skip-comments --skip-dump-date --skip-tz-utc "$@" \
        | sed '/^\/\*M!999999\\- enable the sandbox mode \*\/ *$/d'; }
exists() { [ "$(Q "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'g' AND TABLE_NAME = '$1'")" = 1 ]; }

# страницы базы: корень, его служебные разделы и всё, что под ними (админка целиком)
BASE=$(Q "WITH RECURSIVE b AS (
  SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL
  UNION ALL
  SELECT s.smap_id FROM share_sitemap s JOIN b ON s.smap_pid = b.smap_id
   WHERE b.smap_id <> (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL)
      OR s.smap_segment IN ('admin', 'login', 'register', 'restore-password', 'profile', 'sitemap', 'google-sitemap', 'robots.txt')
) SELECT GROUP_CONCAT(smap_id ORDER BY smap_id) FROM b")
# администраторы (полный доступ к корню) — их создаёт установщик, в файлах их нет
ADMINS=$(Q "SELECT IFNULL(GROUP_CONCAT(DISTINCT ug.u_id), 0) FROM user_user_groups ug WHERE ug.group_id IN (
  SELECT group_id FROM share_access_level WHERE right_id = 3 AND smap_id = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL))")
REPO="upl_pid IS NULL AND upl_internal_type = 'repo'"

rows() { # таблица [условие] — строки INSERT по одной, в порядке ключа; таблицы, удалённой переходом, нет
  local t=$1; shift
  exists "$t" || return 0
  D --no-create-info --skip-extended-insert --complete-insert --order-by-primary --skip-triggers --compact \
    ${1:+--where="$1"} g "$t"
}
tables=$(Q "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'g'")
case "$((tables % 100))" in 11|12|13|14) word=таблиц ;; *) case "$((tables % 10))" in 1) word=таблица ;; 2|3|4) word=таблицы ;; *) word=таблиц ;; esac ;; esac

cd "$R/sql" || exit 2
{
  echo "-- Energine Simple: схема базы — $tables $word и хранимые процедуры. Ставится в пустую базу установщиком:"
  echo "-- php web/index.php setup install (docs/INSTALL.md). Получена из установки полной системы и sql/cut/stage1–$last.sql."
  D --no-data --routines --skip-triggers --skip-add-drop-table --skip-add-locks g \
    | sed -E 's/ AUTO_INCREMENT=[0-9]+//; s/DEFINER=`[^`]*`@`[^`]*` ?//g'
} > structure.sql.new

{
  echo "-- Energine Simple: базовые данные пустого сайта — языки, сайт, служебные страницы и админка, группы и права,"
  echo "-- переводы, почтовые шаблоны, корень файлового репозитория. Администратора создаёт установщик, адрес сайта — в конфиге."
  echo "SET NAMES utf8mb4;"
  echo "SET FOREIGN_KEY_CHECKS = 0;"
  for t in share_languages share_sites share_sites_translation share_sites_properties \
           user_groups user_group_rights share_lang_tags share_lang_tags_translation mail_templates mail_templates_translation; do
    rows "$t"
  done
  rows share_sitemap "smap_id IN ($BASE)"
  rows share_sitemap_translation "smap_id IN ($BASE)"
  rows share_access_level "smap_id IN ($BASE)"
  rows share_uploads "$REPO"
  echo "SET FOREIGN_KEY_CHECKS = 1;"
} > data.sql.new

{
  echo "-- Energine Simple: демо-контент simple.energine.org поверх базовых данных (sql/data.sql): разделы и тексты,"
  echo "-- галерея, демо-посетители, файлы репозитория (сами файлы — sql/demo/uploads)."
  echo "-- Ставится командой php web/index.php setup demo."
  echo "SET NAMES utf8mb4;"
  echo "SET FOREIGN_KEY_CHECKS = 0;"
  rows share_sitemap "smap_id NOT IN ($BASE)"
  rows share_sitemap_translation "smap_id NOT IN ($BASE)"
  rows share_access_level "smap_id NOT IN ($BASE)"
  for t in share_textblocks share_textblocks_translation share_sitemap_uploads; do
    rows "$t"
  done
  rows share_uploads "NOT ($REPO)"
  rows user_users "u_id NOT IN ($ADMINS)"
  rows user_user_groups "u_id NOT IN ($ADMINS)"
  echo "SET FOREIGN_KEY_CHECKS = 1;"
} > demo.sql.new

# каждая строка базы — ровно в одном из файлов
lost=0
for t in $(Q "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'g' ORDER BY 1"); do
  inDb=$(Q "SELECT COUNT(*) FROM \`$t\`")
  inFiles=$(cat data.sql.new demo.sql.new | grep -c "^INSERT INTO \`$t\` ")
  [ "$inDb" = "$inFiles" ] || { echo "таблица $t: в базе $inDb строк, в файлах $inFiles" >&2; lost=1; }
done
if [ "$lost" = 1 ]; then rm -f structure.sql.new data.sql.new demo.sql.new; exit 1; fi
for f in structure.sql data.sql demo.sql; do mv "$f.new" "$f"; done
chown --reference="$R" structure.sql data.sql demo.sql
wc -c structure.sql data.sql demo.sql
