#!/bin/bash
# Переход базы на форк (sql/cut/stage5.sql) не трогает содержимое сайта. Временный экземпляр MariaDB
# (tempdb.sh): схема и базовые данные (sql/structure.sql, sql/data.sql) и «своё» содержимое сайта — текст
# главной, общий блок колонки, страница со своим XML в старой раскладке (контейнер mainMenuContainer):
#  - после stage5.sql тексты сайта те же — демо-тексты живут в sql/demo.sql, не в переходе;
#  - страница, чей XML сбрасывается на шаблон, названа в выводе скрипта;
#  - повторный прогон stage5.sql ничего не меняет.
#   bash tests/tools/migration-check.sh
# Выход: 0 — всё прошло, 1 — провалы, 2 — проверка не выполнена. Каталог экземпляра — в TMPDIR.
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$R/tests/tools/tempdb.sh"
fail=0
ok() { echo "OK   $1"; }
bad() { echo "FAIL $1${2:+: $2}"; fail=$((fail + 1)); }
tempdb_start || exit 2
trap tempdb_stop EXIT
tempdb_create m || exit 2
for f in structure.sql data.sql; do
  TM --default-character-set=utf8mb4 m < "$R/sql/$f" || { echo "импорт $f" >&2; exit 2; }
done
TM --default-character-set=utf8mb4 m <<'SQL' || { echo "содержимое сайта" >&2; exit 2; }
INSERT INTO share_textblocks (smap_id, tb_num) SELECT smap_id, '1' FROM share_sitemap WHERE smap_pid IS NULL;
SET @home := LAST_INSERT_ID();
INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content)
  SELECT @home, lang_id, CONCAT('<p>Свой текст главной, ', lang_abbr, '</p>') FROM share_languages;
INSERT INTO share_textblocks (smap_id, tb_num) VALUES (NULL, 'sidebarTextBlock');
SET @side := LAST_INSERT_ID();
INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content)
  SELECT @side, lang_id, CONCAT('<p>Свой текст колонки, ', lang_abbr, '</p>') FROM share_languages;
UPDATE share_sitemap SET smap_content_xml = '<content><container name="mainMenuContainer"/></content>' WHERE smap_segment = 'login';
SQL
texts() { TM -N --default-character-set=utf8mb4 m -e "SELECT GROUP_CONCAT(tb_content ORDER BY tb_id, lang_id SEPARATOR ' | ')
  FROM share_textblocks_translation"; }
before=$(texts)
out=$(TM --default-character-set=utf8mb4 m < "$R/sql/cut/stage5.sql" 2>&1) || bad "stage5.sql" "$(tail -3 <<< "$out")"
after=$(texts)
[ "$after" = "$before" ] && ok "тексты сайта после stage5.sql те же" || bad "stage5.sql изменил тексты сайта" "$after"
grep -qw "login" <<< "$out" && ok "stage5.sql называет страницу, чей XML сброшен на шаблон" \
  || bad "stage5.sql не называет страницу со сброшенным XML" "$(head -5 <<< "$out")"
[ "$(TM -N m -e "SELECT COUNT(*) FROM share_sitemap WHERE smap_content_xml LIKE '%mainMenuContainer%'")" = 0 ] \
  && ok "XML в старой раскладке сброшен на шаблон" || bad "XML в старой раскладке остался"
fp() { FP_SOCKET="$SOCK" FP_DB=m FP_USER=root php8.5 "$R/tests/tools/fingerprint.php"; }
first=$(fp)
TM --default-character-set=utf8mb4 m < "$R/sql/cut/stage5.sql" > /dev/null 2>&1 || bad "повторный stage5.sql"
[ "$(fp)" = "$first" ] && ok "повторный прогон stage5.sql ничего не меняет" || bad "повторный прогон stage5.sql меняет базу"
echo "== migration-check failures: $fail"
[ "$fail" -eq 0 ]
