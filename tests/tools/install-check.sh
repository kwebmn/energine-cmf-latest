#!/bin/bash
# Проверка установщика (этап 5г) на временном экземпляре MariaDB (tempdb.sh): база и файлы площадки
# не трогаются. Установщик запускается от имени владельца площадки из копии точки входа — у неё свой
# конфиг (--config) и нет статики (--no-static); ядро — сам репозиторий.
#  1. setup install в пустую базу: 21 таблица (мультисайта, модуля apps и вложений разделов нет) и 3 хранимые процедуры, языки ru и ua, администратор в группе
#     администраторов (пароль сверяется с хэшем), адрес сайта в конфиге (домен с портом, корень; в базе доменов нет),
#     конфиг с режимом 600, служебные страницы
#     без демо-строк; паролей нет в выводе;
#  2. отказы до первого изменения базы: непустая база, неверный e-mail, нет пароля администратора;
#  3. пустой сайт отвечает — встроенный сервер PHP на 127.0.0.1 от имени владельца площадки: главная,
#     вход, регистрация, восстановление пароля, карта сайта; администратор входит и видит админку;
#     неизвестный адрес — 404; ссылок на демо-разделы нет; <base> — адрес из конфига; другое имя (Host) — 301 на него;
#     cookie на адресе с портом — без Domain;
#  4. установка со статикой: ссылки на файлы модулей и карта скриптов; модуль в конфиге без каталога —
#     setup linker отказывается до очистки статики;
#  5. вторая установка — с доменом площадки (--domain) — и setup demo поверх: отпечаток
#     (fingerprint.php) совпадает с базой площадки; повторное демо — отказ.
#   bash tests/tools/install-check.sh
# Каталог экземпляра — в INSTALL_TMP (по умолчанию tmp площадки: владельцу площадки нужен проход к сокету).
# INSTALL_DEBUG=каталог — сохранить туда страницы 404 и админки, cookies и журнал встроенного сервера.
# Выход: 0 — всё прошло, 1 — провалы (печатаются), 2 — проверка не выполнена.
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$R/tests/tools/tempdb.sh"
read -r WEB SITE_USER ADMIN_LOGIN < <(cd "$R" && php8.5 -r 'define("ROOT_DIR", getcwd()); $E = require "tests/env.php";
  echo $E["WEB"], " ", $E["SITE_USER"], " ", $E["ADMIN_EMAIL"], "\n";') || { echo "нет tests/env.php" >&2; exit 2; }
[ -n "$ADMIN_LOGIN" ] || { echo "в tests/local.php нет admin_email" >&2; exit 2; }

fail=0
ok() { echo "OK   $1"; }
bad() { echo "FAIL $1${2:+: $2}"; fail=$((fail + 1)); }
is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "ожидалось «$3», получено «$2»"; fi; }

TMPDIR=${INSTALL_TMP:-$(dirname "$WEB")/tmp} TEMPDB_ACCESS=$SITE_USER tempdb_start || exit 2
SRV=
trap '[ -n "$SRV" ] && kill "$SRV" 2>/dev/null; tempdb_stop' EXIT
tempdb_create site && tempdb_user site "$T/dbpw" || exit 2
# сокет открыт владельцу площадки (и группе хостинга): root временного экземпляра — только для root системы
runuser -u "$SITE_USER" -- env -u MYSQL_PWD mariadb --no-defaults --socket="$SOCK" -u root -e 'SELECT 1' > /dev/null 2>&1 \
  && bad "пользователь хостинга входит во временную базу как root без пароля" || ok "root временной базы — только для root системы"
# ошибка запроса (таблицы ещё нет) — пустой ответ: его и сверяют проверки
Q() { TM -N site -e "$1" 2>/dev/null; }
FP() { FP_SOCKET="$SOCK" FP_DB=site FP_USER=root php8.5 "$R/tests/tools/fingerprint.php"; }

tempsite "$SITE_USER" "$WEB" && chown "$SITE_USER" "$T/dbpw" || exit 2
PORT=$(php8.5 -r '$s = stream_socket_server("tcp://127.0.0.1:0"); echo parse_url("tcp://" . stream_socket_get_name($s, false), PHP_URL_PORT);')
URL="http://127.0.0.1:$PORT/"

# пароли — в переменных окружения, не в аргументах; в выводе их быть не должно
ENERGINE_DB_PASSWORD=$(cat "$T/dbpw")
ENERGINE_ADMIN_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
export ENERGINE_DB_PASSWORD ENERGINE_ADMIN_PASSWORD
setup() { tempsite_setup "$@"; }
INSTALL=(install --config="$S/web/system.config.php" --no-static --url="$URL" --db-socket="$SOCK" --db-name=site
         --db-user=energine --admin-email="$ADMIN_LOGIN" --admin-name=Admin)
secret_free() { ! grep -qF -e "$ENERGINE_DB_PASSWORD" -e "$ENERGINE_ADMIN_PASSWORD" <<< "$1"; }

echo "-- отказы до изменений"
out=$(ENERGINE_ADMIN_PASSWORD= setup "${INSTALL[@]}"); rc=$?
[ $rc -ne 0 ] && [ "$(Q 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = "site"')" = 0 ] \
  && ok "нет пароля администратора — отказ, база пуста" || bad "нет пароля администратора" "код $rc: $(tail -3 <<< "$out")"
out=$(setup install --config="$S/web/system.config.php" --no-static --url="$URL" --db-socket="$SOCK" --db-name=site \
  --db-user=energine --admin-email=not-an-email --admin-name=Admin); rc=$?
[ $rc -ne 0 ] && [ "$(Q 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = "site"')" = 0 ] \
  && ok "неверный e-mail администратора — отказ, база пуста" || bad "неверный e-mail" "код $rc: $(tail -3 <<< "$out")"
[ ! -e "$S/web/system.config.php" ] && ok "при отказе конфиг не записан" || { bad "при отказе записан конфиг"; rm -f "$S/web/system.config.php"; }
# логин (u_name) вмещает 50 символов: длиннее — отказ до изменений, а не сбой на середине
long="claude-$(printf 'x%.0s' $(seq 40))@example.org"
out=$(setup install --config="$S/web/system.config.php" --no-static --url="$URL" --db-socket="$SOCK" --db-name=site \
  --db-user=energine --admin-email="$long" --admin-name=Admin); rc=$?
[ $rc -ne 0 ] && [ "$(Q 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = "site"')" = 0 ] && [ ! -e "$S/web/system.config.php" ] \
  && ok "e-mail администратора длиннее 50 символов — отказ до изменений" || bad "длинный e-mail администратора" "код $rc: $(tail -2 <<< "$out")"
[ -e "$S/web/system.config.php" ] && rm -f "$S/web/system.config.php"
# сбой на середине (у пользователя базы нет права создавать процедуры): код 1, конфиг этого запуска удалён,
# сказано очистить базу; затем база пересоздаётся для основной установки
fresh_site() { TM <<< "DROP DATABASE \`site\`; CREATE DATABASE \`site\` CHARACTER SET $CS COLLATE $CO;
  GRANT ALL PRIVILEGES ON \`site\`.* TO 'energine'@'localhost';"; }
fresh_site && TM <<< "REVOKE CREATE ROUTINE ON \`site\`.* FROM 'energine'@'localhost';" || { bad "подготовка сбоя"; exit 1; }
out=$(setup "${INSTALL[@]}"); rc=$?
[ $rc -ne 0 ] && [ ! -e "$S/web/system.config.php" ] && grep -q "прервалась" <<< "$out" && grep -q "очистите" <<< "$out" \
  && ok "сбой на середине: код 1, конфиг этого запуска удалён, сказано очистить базу" \
  || bad "сбой на середине" "код $rc, конфиг $([ -e "$S/web/system.config.php" ] && echo остался || echo удалён): $(tail -3 <<< "$out")"
rm -f "$S/web/system.config.php"
fresh_site || { bad "пересоздание базы"; exit 1; }

echo "-- установка в пустую базу"
out=$(setup "${INSTALL[@]}"); rc=$?
is "setup install — код 0" "$rc" 0
[ $rc -eq 0 ] || echo "$out" | tail -8 | sed 's/^/     /'
secret_free "$out" && ok "паролей нет в выводе установщика" || bad "пароль в выводе установщика"
is "таблиц" "$(Q 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = "site"')" 21
is "хранимых процедур" "$(Q 'SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = "site"')" 3
is "языки" "$(Q 'SELECT GROUP_CONCAT(lang_abbr ORDER BY lang_id) FROM share_languages')" "ru,ua"
hash=$(Q "SELECT u_password FROM user_users WHERE u_name = '$ADMIN_LOGIN'")
is "пользователь один — администратор" "$(Q 'SELECT GROUP_CONCAT(u_name) FROM user_users')" "$ADMIN_LOGIN"
# группа администраторов — та, у которой полный доступ (right_id 3) к корню сайта
is "администратор в группе администраторов" "$(Q "SELECT COUNT(*) FROM user_user_groups ug JOIN user_users u USING (u_id)
  WHERE u.u_name = '$ADMIN_LOGIN' AND ug.group_id IN (SELECT group_id FROM share_access_level WHERE right_id = 3
  AND smap_id = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL))")" 1
[ -n "$hash" ] && php8.5 -r 'exit(password_verify(getenv("ENERGINE_ADMIN_PASSWORD"), $argv[1]) ? 0 : 1);' "$hash" \
  && ok "пароль администратора сверяется с хэшем" || bad "пароль администратора не сверяется с хэшем"
# адрес сайта — в конфиге: домен с нестандартным портом и корень; записей доменов в базе нет
is "конфиг: адрес сайта (домен с портом, корень)" "$(php8.5 -r 'define("ROOT_DIR", $argv[2]); $c = include $argv[1];
  echo $c["site"]["domain"] ?? "-", " ", $c["site"]["root"] ?? "-";' "$S/web/system.config.php" "$R" 2>/dev/null)" "127.0.0.1:$PORT /"
# мультисайта нет: ни таблиц доменов и привязки групп к сайтам, ни колонок сайта у страниц и свойств, ни флажков сайта
is "таблиц мультисайта нет" "$(Q "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'site'
  AND TABLE_NAME IN ('share_domains', 'share_domain2site', 'share_groups2sites')")" 0
is "колонок мультисайта нет" "$(Q "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'site' AND (TABLE_NAME, COLUMN_NAME) IN
  (('share_sitemap', 'site_id'), ('share_sites_properties', 'site_id'), ('share_sites', 'site_is_default'),
   ('share_sites', 'site_is_active'), ('share_sites', 'site_folder'), ('share_sites', 'site_order_num'))")" 0
is "конфиг: режим 600, владелец площадки" "$(stat -c '%a %U' "$S/web/system.config.php" 2>/dev/null)" "600 $SITE_USER"
# рабочему сайту отладка не нужна: с ней посетитель видит пути сервера и цепочку вызовов на странице ошибки
php8.5 -r 'define("ROOT_DIR", $argv[2]); $c = include $argv[1]; exit(empty($c["site"]["debug"]) ? 0 : 1);' \
  "$S/web/system.config.php" "$R" 2>/dev/null && ok "конфиг: режим отладки выключен" || bad "конфиг: режим отладки включён"
is "служебные страницы" "$(Q "SELECT GROUP_CONCAT(smap_segment ORDER BY smap_segment) FROM share_sitemap WHERE smap_pid IS NULL
  OR smap_pid = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL)")" \
  ",admin,google-sitemap,login,profile,register,restore-password,robots.txt,sitemap"
is "демо-строк нет (тексты, файлы кроме корня репозитория)" "$(Q 'SELECT CONCAT_WS(" ",
  (SELECT COUNT(*) FROM share_textblocks), (SELECT COUNT(*) FROM share_uploads))')" "0 1"

echo "-- повторная установка"
before=$(FP)
# конфиг уже есть: база и домен берутся из него, так что достаточно e-mail администратора
out=$(setup install --config="$S/web/system.config.php" --no-static --admin-email="$ADMIN_LOGIN" --admin-name=Admin); rc=$?
[ $rc -ne 0 ] && [ "$(FP)" = "$before" ] && ok "непустая база — отказ без изменений" \
  || bad "повторная установка" "код $rc: $(tail -3 <<< "$out")"
grep -q "пуст" <<< "$out" && ok "отказ объясняет: нужна пустая база" || bad "текст отказа" "$(tail -3 <<< "$out")"
# конфиг уже есть: параметры базы и другой домен не принимаются молча — отказ называет конфиг
out=$(setup install --config="$S/web/system.config.php" --no-static --db-name=site-other --admin-email="$ADMIN_LOGIN"); rc=$?
[ $rc -ne 0 ] && grep -q "Конфиг площадки уже есть" <<< "$out" && ok "конфиг уже есть — параметры базы (--db-*) отклонены" \
  || bad "конфиг уже есть и --db-*" "код $rc: $(tail -2 <<< "$out")"
out=$(setup install --config="$S/web/system.config.php" --no-static --domain=other.example --admin-email="$ADMIN_LOGIN"); rc=$?
[ $rc -ne 0 ] && grep -q "Конфиг площадки уже есть" <<< "$out" && ok "конфиг уже есть — другой домен отклонён" \
  || bad "конфиг уже есть и другой домен" "код $rc: $(tail -2 <<< "$out")"

echo "-- пустой сайт отвечает ($URL)"
# текущий каталог — web, как у PHP-FPM: ядро читает шаблоны по относительному пути templates/
(cd "$S/web" && exec runuser -u "$SITE_USER" -- php8.5 -S "127.0.0.1:$PORT" -t "$S/web" "$S/web/router.php") > "$T/server.log" 2>&1 &
SRV=$!
for _ in $(seq 50); do curl -s -o /dev/null "$URL" && break; sleep 0.2; done
jar="$T/cookies"
page() { curl -s -o "$T/page.html" -w '%{http_code}' -b "$jar" -c "$jar" "$URL$1"; }
for p in "" login/ register/ restore-password/ sitemap/; do
  code=$(page "$p")
  # страница темы (main#content), а не текст ошибки загрузки с кодом 200
  if [ "$code" = 200 ] && grep -q '<main id="content"' "$T/page.html" \
     && ! grep -qE 'Fatal error|Warning: |Notice: |Deprecated: |<title>Errors</title>' "$T/page.html"; then
    ok "/$p — 200"
  else bad "/$p" "код $code: $(grep -o '<title>[^<]*' "$T/page.html" | head -1)"; fi
done
page "" > /dev/null
is "<base> — адрес из конфига" "$(grep -o '<base href="[^"]*"' "$T/page.html" | head -1)" "<base href=\"$URL\""
# другое имя (www, IP, поддельный Host): GET и HEAD уходят на ту же страницу по адресу из конфига (301) — страницы
# и их формы живут только на адресе из конфига, где Origin формы совпадает с хостом запроса
is "Host: evil.example — 301 на ту же страницу по адресу из конфига" \
  "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -H "Host: evil.example" "${URL}login/?x=1")" "301 ${URL}login/?x=1"
is "HEAD по другому имени (www) — 301" "$(curl -s -I -o /dev/null -w '%{http_code}' -H "Host: www.127.0.0.1:$PORT" "$URL")" 301
is "адрес из конфига — без переадресации" "$(curl -s -o /dev/null -w '%{http_code}' "${URL}login/")" 200
demo=$(grep -oE 'href="[^"]*/(features|info)/' "$T/page.html" | head -3 | tr '\n' ' ')
[ -z "$demo" ] && ok "на главной нет ссылок на демо-разделы" || bad "ссылки на демо-разделы" "$demo"
is "неизвестный адрес — 404" "$(page claude-no-such-page/)" 404
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/page.html" "$INSTALL_DEBUG/404.html"
# cookie токена гостя и сессии на адресе с портом — без атрибута Domain (Domain=.127.0.0.1:порт браузер отбрасывает);
# cookie токена ставится первому запросу гостя — страница входа без cookie
curl -s -D "$T/login.hdr" -o /dev/null "${URL}login/"
page login/ > /dev/null
token=$(grep -o '<meta name="csrf-token" content="[^"]*"' "$T/page.html" | sed 's/.*content="//;s/"$//')
# пароль — через stdin (@-), не аргументом
printf '%s' "$ENERGINE_ADMIN_PASSWORD" | curl -s -D "$T/auth.hdr" -o /dev/null -b "$jar" -c "$jar" -e "${URL}login/" -H "X-CSRF-Token: $token" \
  --data-urlencode "user[login]=1" --data-urlencode "user[username]=$ADMIN_LOGIN" \
  --data-urlencode "user[password]@-" "${URL}auth.php"
grep -qi '^set-cookie: nrgn_csrf=' "$T/login.hdr" && grep -qi '^set-cookie: NRGNSID=' "$T/auth.hdr" \
  && ! grep -qi '^set-cookie:.*domain=' "$T/login.hdr" "$T/auth.hdr" \
  && ok "cookie токена и сессии на адресе с портом — без Domain" \
  || bad "cookie на адресе с портом" "$(grep -hi '^set-cookie:' "$T/login.hdr" "$T/auth.hdr" | cut -c1-90 | tr '\r\n' '  ')"
code=$(page admin/)
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/page.html" "$INSTALL_DEBUG/admin.html" && cp "$jar" "$INSTALL_DEBUG/cookies.txt"
[ "$code" = 200 ] && grep -q 'admin' "$T/page.html" && grep -qi 'users\|пользовател' "$T/page.html" \
  && ok "администратор входит, /admin/ — 200" || bad "вход администратора и /admin/" "код $code"
grep -qE 'PHP (Fatal|Warning|Notice|Deprecated)' "$T/server.log" && bad "журнал встроенного сервера" "$(grep -m3 -E 'PHP ' "$T/server.log")"
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/server.log" "$INSTALL_DEBUG/server.log"
kill "$SRV" 2>/dev/null; SRV=

echo "-- установка со статикой"
# так ставится настоящий сайт (без --no-static): статика ложится в web копии — ссылками на файлы модулей,
# карта скриптов пишется; страница и скрипт отдаются
S2="$T/full"
tempsite_empty "$SITE_USER" "$S2" && tempdb_create site3 && TM <<< "GRANT ALL PRIVILEGES ON \`site3\`.* TO 'energine'@'localhost';" \
  || { bad "копия без статики"; exit 1; }
out=$(runuser -u "$SITE_USER" -- php8.5 "$S2/web/index.php" setup install --config="$S2/web/system.config.php" --url="$URL" \
  --db-socket="$SOCK" --db-name=site3 --db-user=energine --admin-email="$ADMIN_LOGIN" --admin-name=Admin < /dev/null 2>&1); rc=$?
is "setup install со статикой — код 0" "$rc" 0
[ $rc -eq 0 ] || echo "$out" | tail -5 | sed 's/^/     /'
links=$(find "$S2/web/scripts" -maxdepth 1 -name '*.js' -type l 2>/dev/null | wc -l)
files=$(find "$S2/web/scripts" -maxdepth 1 -name '*.js' -type f 2>/dev/null | wc -l)
[ "$links" -gt 0 ] && [ "$files" = 0 ] && [ ! -e "$S2/web/system.jsmap.php" ] \
  && ok "статика — ссылками на файлы модулей ($links скриптов), карты зависимостей скриптов нет (этап 9)" \
  || bad "статика" "ссылок $links, файлов-копий $files, карта $([ -e "$S2/web/system.jsmap.php" ] && echo есть || echo нет)"
(cd "$S2/web" && exec runuser -u "$SITE_USER" -- php8.5 -S "127.0.0.1:$PORT" -t "$S2/web" "$S2/web/router.php") > "$T/server2.log" 2>&1 &
SRV=$!
for _ in $(seq 50); do curl -s -o /dev/null "$URL" && break; sleep 0.2; done
code=$(curl -s -o "$T/page2.html" -w '%{http_code}' "$URL")
js=$(curl -s -o /dev/null -w '%{http_code}' "${URL}scripts/Energine.js")
[ "$code" = 200 ] && grep -q '<main id="content"' "$T/page2.html" && [ "$js" = 200 ] \
  && ok "сайт со своей статикой отвечает: главная и scripts/Energine.js — 200" || bad "сайт со своей статикой" "главная $code, скрипт $js"
# этап 9: битая ссылка в web/scripts (скрипт убран из кода, а setup linker ещё не запускали) не роняет страницы:
# в import map её нет, остальное на месте
ln -s "$S2/web/scripts/claude-nowhere.js" "$S2/web/scripts/claude-dangling.js"
code=$(curl -s -o "$T/page3.html" -w '%{http_code}' "$URL")
[ "$code" = 200 ] && grep -q '"Energine":' "$T/page3.html" && ! grep -q 'claude-dangling' "$T/page3.html" \
  && ok "битая ссылка в web/scripts — страница 200, в import map её нет" || bad "битая ссылка в web/scripts" "код $code"
rm -f "$S2/web/scripts/claude-dangling.js"
kill "$SRV" 2>/dev/null; SRV=
# этап 9: setup linker убирает устаревшую карту зависимостей скриптов (её писали установщики до этапа 9)
printf '<?php return [];' > "$S2/web/system.jsmap.php" && chown "$SITE_USER" "$S2/web/system.jsmap.php"
runuser -u "$SITE_USER" -- php8.5 "$S2/web/index.php" setup linker < /dev/null > /dev/null 2>&1
[ ! -e "$S2/web/system.jsmap.php" ] && ok "setup linker убирает устаревшую карту зависимостей скриптов" \
  || bad "устаревшая карта зависимостей скриптов" "осталась после setup linker"
# модуль в конфиге без каталога (так выглядит конфиг площадки после этапа 7: модуль apps убран из ядра) —
# setup linker отказывается до любых изменений, каталоги статики не очищаются
C2="$S2/web/system.config.php"
links=$(find "$S2/web/scripts" -maxdepth 1 -name '*.js' -type l 2>/dev/null | wc -l)
sed -i "/^ *'seo' *=>/a\\        'apps'      => \$energine_release . '/core/modules/apps'," "$C2" && chown "$SITE_USER" "$C2" && chmod 600 "$C2"
out=$(runuser -u "$SITE_USER" -- php8.5 "$S2/web/index.php" setup linker < /dev/null 2>&1); rc=$?
after=$(find "$S2/web/scripts" -maxdepth 1 -name '*.js' -type l 2>/dev/null | wc -l)
grep -q "core/modules/apps'" "$C2" && [ $rc -ne 0 ] && grep -q "core/modules/apps" <<< "$out" && [ "$links" -gt 0 ] \
  && [ "$after" = "$links" ] && ok "модуль в конфиге без каталога — setup linker отказывается, статика не тронута" \
  || bad "модуль в конфиге без каталога" "код $rc, ссылок на скрипты было $links, стало $after: $(tail -2 <<< "$out")"
sed -i "/^ *'apps' *=> /d" "$C2" && chown "$SITE_USER" "$C2" && chmod 600 "$C2"

echo "-- установка с доменом площадки и демо поверх"
# вторая база: адрес сайта — как у площадки (--domain), затем демо; сверка с базой площадки
tempdb_create site2 && TM <<< "GRANT ALL PRIVILEGES ON \`site2\`.* TO 'energine'@'localhost';" || { bad "вторая база"; exit 1; }
out=$(setup install --config="$S/web/system2.config.php" --no-static --domain="$HOST" --db-socket="$SOCK" --db-name=site2 \
  --db-user=energine --admin-email="$ADMIN_LOGIN" --admin-name=Admin); rc=$?
is "setup install --domain — код 0" "$rc" 0
[ $rc -eq 0 ] || echo "$out" | tail -5 | sed 's/^/     /'
out=$(setup demo --config="$S/web/system2.config.php" --no-static); rc=$?
is "setup demo — код 0" "$rc" 0
[ $rc -eq 0 ] || echo "$out" | tail -5 | sed 's/^/     /'
out=$(setup demo --config="$S/web/system2.config.php" --no-static); rc=$?
[ $rc -ne 0 ] && grep -q "свежую установку" <<< "$out" && ok "повторное демо — отказ" || bad "повторное демо" "код $rc: $(tail -2 <<< "$out")"
(cd "$R" && php8.5 tests/tools/fingerprint.php) > "$T/live.txt" \
  && FP_SOCKET="$SOCK" FP_DB=site2 FP_USER=root php8.5 "$R/tests/tools/fingerprint.php" > "$T/fresh.txt" || { bad "отпечатки"; exit 1; }
if diff -q "$T/live.txt" "$T/fresh.txt" > /dev/null; then ok "установка и демо == база площадки: таблиц $(wc -l < "$T/live.txt")"
else bad "установка и демо != база площадки" "$(diff "$T/live.txt" "$T/fresh.txt" | grep '^[<>]' | awk '{print $2}' | sort -u | tr '\n' ' ')"; fi

echo "== install-check failures: $fail"
[ "$fail" -eq 0 ]
