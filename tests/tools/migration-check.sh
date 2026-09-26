#!/bin/bash
# Переход базы на форк (sql/cut/stage5.sql) не трогает содержимое сайта. Временный экземпляр MariaDB
# (tempdb.sh): схема и базовые данные (sql/structure.sql, sql/data.sql) и «своё» содержимое сайта — текст
# главной, общий блок колонки, страница со своим XML в старой раскладке (контейнер mainMenuContainer):
#  - после stage5.sql тексты сайта те же — демо-тексты живут в sql/demo.sql, не в переходе;
#  - страница, чей XML сбрасывается на шаблон, названа в выводе скрипта;
#  - повторный прогон stage5.sql ничего не меняет.
# Переход на этап 6 (sql/cut/stage6.sql, мультисайт): база до этапа — файлы установки коммита PRE6 (последний
# коммит этапа 5г) с демо-контентом и свойствами сайта (общими и своими):
#  - после stage6.sql разделы с адресами (кроме переехавших «Настроек сайта»), права, тексты и новости те же,
#    у свойства побеждает значение сайта; таблиц и колонок мультисайта нет;
#  - повторный прогон stage6.sql ничего не меняет;
#  - база с двумя сайтами или двумя корнями — отказ до любых изменений, в выводе сказано, что сделать.
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

# --- этап 6
PRE6=9597483c
pre6() { # база в состоянии до этапа 6
  tempdb_create "$1" || return 1
  local f
  for f in structure.sql data.sql demo.sql; do
    git -C "$R" show "$PRE6:sql/$f" | TM --default-character-set=utf8mb4 "$1" || { echo "импорт $f ($PRE6)" >&2; return 1; }
  done
}
pre6 m6 || exit 2
TM --default-character-set=utf8mb4 m6 <<'SQL' || { echo "свойства сайта" >&2; exit 2; }
INSERT INTO share_sites_properties (site_id, prop_name, prop_value) VALUES (NULL, 'phone', 'общий'), (1, 'phone', 'свой'),
  (NULL, 'email', 'общий e-mail');
SQL
content6() { TM -N --default-character-set=utf8mb4 m6 -e "SELECT CONCAT_WS(' # ',
  (SELECT GROUP_CONCAT(CONCAT(smap_id, ':', IFNULL(smap_pid, '-'), ':', smap_segment) ORDER BY smap_id) FROM share_sitemap
    WHERE smap_content NOT IN ('main/sites.content.xml', 'main/site_settings.content.xml')),
  (SELECT GROUP_CONCAT(CONCAT(smap_id, ':', group_id, ':', right_id) ORDER BY smap_id, group_id) FROM share_access_level),
  (SELECT MD5(GROUP_CONCAT(tb_content ORDER BY tb_id, lang_id SEPARATOR ' | ')) FROM share_textblocks_translation),
  (SELECT MD5(GROUP_CONCAT(CONCAT(n.news_id, ':', n.smap_id, ':', t.news_title) ORDER BY n.news_id, t.lang_id))
     FROM apps_news n JOIN apps_news_translation t USING (news_id)))"; }
before6=$(content6)
out=$(TM --default-character-set=utf8mb4 m6 < "$R/sql/cut/stage6.sql" 2>&1) || bad "stage6.sql" "$(tail -3 <<< "$out")"
[ "$(content6)" = "$before6" ] && ok "stage6.sql: разделы с адресами, права, тексты и новости те же" \
  || bad "stage6.sql изменил содержимое сайта" "$(content6 | cut -c1-200)"
is6() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "ожидалось «$3», получено «$2»"; fi; }
is6 "stage6.sql: свойство сайта — своё значение важнее общего" \
  "$(TM -N --default-character-set=utf8mb4 m6 -e "SELECT GROUP_CONCAT(CONCAT(prop_name, '=', prop_value) ORDER BY prop_name) FROM share_sites_properties")" \
  "email=общий e-mail,phone=свой"
is6 "stage6.sql: таблиц мультисайта нет" "$(TM -N m6 -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'm6'
  AND TABLE_NAME IN ('share_domains', 'share_domain2site', 'share_groups2sites')")" 0
is6 "stage6.sql: колонок мультисайта нет" "$(TM -N m6 -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'm6'
  AND (TABLE_NAME, COLUMN_NAME) IN (('share_sitemap', 'site_id'), ('share_sites_properties', 'site_id'),
  ('share_sites', 'site_is_default'), ('share_sites', 'site_is_active'), ('share_sites', 'site_folder'), ('share_sites', 'site_order_num'))")" 0
fp6() { FP_SOCKET="$SOCK" FP_DB=m6 FP_USER=root php8.5 "$R/tests/tools/fingerprint.php"; }
first6=$(fp6)
TM --default-character-set=utf8mb4 m6 < "$R/sql/cut/stage6.sql" > /dev/null 2>&1 || bad "повторный stage6.sql"
[ "$(fp6)" = "$first6" ] && ok "повторный прогон stage6.sql ничего не меняет" || bad "повторный прогон stage6.sql меняет базу"
refuse6() { # база, поломка, слова отказа
  pre6 "$1" && TM "$1" <<< "$2" || { bad "подготовка $1"; return; }
  local out rc left
  out=$(TM --default-character-set=utf8mb4 "$1" < "$R/sql/cut/stage6.sql" 2>&1); rc=$?
  left=$(TM -N "$1" -e "SELECT (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$1' AND TABLE_NAME = 'share_domains')
    + (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '$1' AND TABLE_NAME = 'share_sitemap' AND COLUMN_NAME = 'site_id')")
  [ $rc -ne 0 ] && grep -q "$3" <<< "$out" && [ "$left" = 2 ] && ok "stage6.sql: $3 — отказ до изменений" \
    || bad "stage6.sql: $3" "код $rc, осталось $left из 2: $(tail -2 <<< "$out")"
}
refuse6 m6s "INSERT INTO share_sites (site_id) VALUES (2);" "не один сайт"
refuse6 m6r "UPDATE share_sitemap SET smap_pid = NULL WHERE smap_segment = 'login';" "не один корень"
echo "== migration-check failures: $fail"
[ "$fail" -eq 0 ]
