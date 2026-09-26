#!/bin/bash
# Проверка установщика (этап 5г) на временном экземпляре MariaDB (tempdb.sh): база и файлы площадки
# не трогаются. Установщик запускается от имени владельца площадки из копии точки входа — у неё свой
# конфиг (--config) и нет статики (--no-static); ядро — сам репозиторий.
#  1. setup install в пустую базу: 31 таблица и 3 хранимые процедуры, языки ru и ua, администратор в группе
#     администраторов (пароль сверяется с хэшем), адрес сайта, конфиг с режимом 600, служебные страницы
#     без демо-строк; паролей нет в выводе;
#  2. отказы до первого изменения базы: непустая база, неверный e-mail, нет пароля администратора;
#  3. пустой сайт отвечает — встроенный сервер PHP на 127.0.0.1 от имени владельца площадки: главная,
#     вход, регистрация, восстановление пароля, карта сайта; администратор входит и видит админку;
#     неизвестный адрес — 404; ссылок на демо-разделы нет;
#  4. вторая установка — с доменом площадки (--domain: http и https) — и setup demo поверх: отпечаток
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
# ошибка запроса (таблицы ещё нет) — пустой ответ: его и сверяют проверки
Q() { TM -N site -e "$1" 2>/dev/null; }
FP() { FP_SOCKET="$SOCK" FP_DB=site FP_USER=root php8.5 "$R/tests/tools/fingerprint.php"; }

# копия точки входа: свои index.php, bootstrap.php, auth.php и конфиг; ядро и шаблоны — ссылками
S="$T/site"
mkdir -p "$S/web/uploads" "$S/private" && ln -s "$R" "$S/private/energine" \
  && cp "$R/htdocs/index.php" "$R/htdocs/bootstrap.php" "$R/htdocs/auth.php" "$S/web/" || exit 2
# статика и карта скриптов — площадки (--no-static их не раскладывает, раскладка — дело setup linker и scriptMap)
for d in images scripts stylesheets templates resizer system.jsmap.php; do ln -s "$WEB/$d" "$S/web/$d" || exit 2; done
cat > "$S/web/router.php" <<'PHP'
<?php
// встроенный сервер PHP: файлы (статика, auth.php) — как есть, остальное — index.php, как у nginx площадки
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false;
}
require __DIR__ . '/index.php';
PHP
chown -hR "$SITE_USER" "$S" && chown "$SITE_USER" "$T/dbpw" || exit 2
PORT=$(php8.5 -r '$s = stream_socket_server("tcp://127.0.0.1:0"); echo parse_url("tcp://" . stream_socket_get_name($s, false), PHP_URL_PORT);')
URL="http://127.0.0.1:$PORT/"

# пароли — в переменных окружения, не в аргументах; в выводе их быть не должно
ENERGINE_DB_PASSWORD=$(cat "$T/dbpw")
ENERGINE_ADMIN_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
export ENERGINE_DB_PASSWORD ENERGINE_ADMIN_PASSWORD
setup() { runuser -u "$SITE_USER" -- php8.5 "$S/web/index.php" setup "$@" < /dev/null 2>&1; }
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

echo "-- установка в пустую базу"
out=$(setup "${INSTALL[@]}"); rc=$?
is "setup install — код 0" "$rc" 0
[ $rc -eq 0 ] || echo "$out" | tail -8 | sed 's/^/     /'
secret_free "$out" && ok "паролей нет в выводе установщика" || bad "пароль в выводе установщика"
is "таблиц" "$(Q 'SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = "site"')" 31
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
is "адрес сайта" "$(Q "SELECT CONCAT(d.domain_protocol, '://', d.domain_host, ':', d.domain_port, d.domain_root) FROM share_domains d
  JOIN share_domain2site USING (domain_id)")" "http://127.0.0.1:$PORT/"
is "конфиг: режим 600, владелец площадки" "$(stat -c '%a %U' "$S/web/system.config.php" 2>/dev/null)" "600 $SITE_USER"
is "служебные страницы" "$(Q "SELECT GROUP_CONCAT(smap_segment ORDER BY smap_segment) FROM share_sitemap WHERE smap_pid IS NULL
  OR smap_pid = (SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL)")" \
  ",admin,google-sitemap,login,profile,register,restore-password,robots.txt,sitemap"
is "демо-строк нет (новости, тексты, получатели, файлы кроме корня репозитория)" "$(Q 'SELECT CONCAT_WS(" ",
  (SELECT COUNT(*) FROM apps_news), (SELECT COUNT(*) FROM share_textblocks), (SELECT COUNT(*) FROM apps_feedback_recipient),
  (SELECT COUNT(*) FROM share_uploads))')" "0 0 0 1"

echo "-- повторная установка"
before=$(FP)
out=$(setup "${INSTALL[@]}"); rc=$?
[ $rc -ne 0 ] && [ "$(FP)" = "$before" ] && ok "непустая база — отказ без изменений" \
  || bad "повторная установка" "код $rc: $(tail -3 <<< "$out")"
grep -q "пуст" <<< "$out" && ok "отказ объясняет: нужна пустая база" || bad "текст отказа" "$(tail -3 <<< "$out")"

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
demo=$(grep -oE 'href="[^"]*/(news|media|features|info|contacts)/' "$T/page.html" | head -3 | tr '\n' ' ')
[ -z "$demo" ] && ok "на главной нет ссылок на демо-разделы" || bad "ссылки на демо-разделы" "$demo"
is "неизвестный адрес — 404" "$(page claude-no-such-page/)" 404
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/page.html" "$INSTALL_DEBUG/404.html"
page login/ > /dev/null
token=$(grep -o '<meta name="csrf-token" content="[^"]*"' "$T/page.html" | sed 's/.*content="//;s/"$//')
# пароль — через stdin (@-), не аргументом
printf '%s' "$ENERGINE_ADMIN_PASSWORD" | curl -s -o /dev/null -b "$jar" -c "$jar" -e "${URL}login/" -H "X-CSRF-Token: $token" \
  --data-urlencode "user[login]=1" --data-urlencode "user[username]=$ADMIN_LOGIN" \
  --data-urlencode "user[password]@-" "${URL}auth.php"
code=$(page admin/)
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/page.html" "$INSTALL_DEBUG/admin.html" && cp "$jar" "$INSTALL_DEBUG/cookies.txt"
[ "$code" = 200 ] && grep -q 'admin' "$T/page.html" && grep -qi 'users\|пользовател' "$T/page.html" \
  && ok "администратор входит, /admin/ — 200" || bad "вход администратора и /admin/" "код $code"
grep -qE 'PHP (Fatal|Warning|Notice|Deprecated)' "$T/server.log" && bad "журнал встроенного сервера" "$(grep -m3 -E 'PHP ' "$T/server.log")"
[ -n "${INSTALL_DEBUG:-}" ] && cp "$T/server.log" "$INSTALL_DEBUG/server.log"
kill "$SRV" 2>/dev/null; SRV=

echo "-- установка с доменом площадки и демо поверх"
# вторая база: адрес сайта — как у площадки (--domain: http и https), затем демо; сверка с базой площадки
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
