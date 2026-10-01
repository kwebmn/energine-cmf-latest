#!/bin/bash
# Стенд для проверки кода без площадки: временная MariaDB (только сокет, без сети), установка из этого репозитория
# с демо, встроенный сервер PHP на 127.0.0.1. Конфиг, база и файлы площадки не читаются и не меняются: кодировка
# базы — из конфигов сервера (my_print_defaults), администратор стенда — со случайным паролем в local.php стенда.
#   STAND_MAILBOX=адрес bash tests/tools/stand.sh start — поднять стенд (адрес — локальный ящик для писем тестов)
#   bash tests/tools/stand.sh run КОМАНДА…            — команда с окружением стенда (env.php смотрит на стенд)
#   bash tests/tools/stand.sh stop                     — остановить и удалить
# Каталог — $STAND_DIR (по умолчанию /tmp/stand-<владелец репозитория>). Выход: 0 — сделано, 2 — не выполнено.
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE_USER=$(stat -c %U "$R")
D=${STAND_DIR:-/tmp/stand-$SITE_USER}
fail() { echo "stand: $*" >&2; exit 2; }
TM() { env -u MYSQL_PWD mariadb --no-defaults --socket="$D/s" -u root "$@"; }

stop() {
  [ -f "$D/env.sh" ] || { [ -d "$D" ] && fail "в $D нет env.sh — это не стенд, не трогаю"; return 0; }
  [ -s "$D/port" ] && pkill -f -- "-S 127.0.0.1:$(cat "$D/port") " 2>/dev/null
  if [ -s "$D/mysqld.pid" ]; then
    kill "$(cat "$D/mysqld.pid")" 2>/dev/null
    for _ in $(seq 100); do [ -e "$D/mysqld.pid" ] || break; sleep 0.1; done
  fi
  rm -rf -- "$D"
}

start() {
  [ -n "${STAND_MAILBOX:-}" ] || fail "задайте STAND_MAILBOX — локальный ящик для писем тестов"
  [ -e "$D" ] && fail "$D уже есть: сначала stop"
  mkdir -p "$D" && chmod 711 "$D" || fail "нет каталога $D"
  local cs co
  cs=$(my_print_defaults --mysqld | sed -n 's/^--character-set-server=//p' | tail -1)
  co=$(my_print_defaults --mysqld | sed -n 's/^--collation-server=//p' | tail -1)
  mariadb-install-db --no-defaults --user=root --datadir="$D/data" --auth-root-authentication-method=socket \
    --skip-test-db > "$D/install.log" 2>&1 || fail "mariadb-install-db: $(tail -3 "$D/install.log")"
  mariadbd --no-defaults --user=root --datadir="$D/data" --socket="$D/s" --pid-file="$D/mysqld.pid" --skip-networking \
    --character-set-server="${cs:-utf8mb4}" --collation-server="${co:-utf8mb4_general_ci}" \
    --innodb-buffer-pool-size=128M --log-error="$D/mysqld.log" &
  for _ in $(seq 150); do TM -e 'SELECT 1' > /dev/null 2>&1 && break; sleep 0.2; done
  TM -e 'SELECT 1' > /dev/null 2>&1 || fail "mariadbd не запустился: $(tail -3 "$D/mysqld.log")"
  chmod 777 "$D/s"
  local dbpw adminpw port
  dbpw=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
  adminpw=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
  TM <<< "CREATE DATABASE site CHARACTER SET ${cs:-utf8mb4} COLLATE ${co:-utf8mb4_general_ci};
    CREATE USER 'energine'@'localhost' IDENTIFIED BY '$dbpw'; GRANT ALL PRIVILEGES ON site.* TO 'energine'@'localhost';" \
    || fail "база стенда не создана"
  # копия точки входа, как в docs/INSTALL.md: ядро — ссылкой на репозиторий, каркас загрузок — копией,
  # статику раскладывает установка
  mkdir -p "$D/site/web" "$D/site/private" && ln -s "$R" "$D/site/private/energine" \
    && cp "$R/htdocs/index.php" "$R/htdocs/bootstrap.php" "$R/htdocs/auth.php" "$D/site/web/" \
    && cp -a "$R/htdocs/resizer" "$R/htdocs/uploads" "$D/site/web/" || fail "копия точки входа не создана"
  cat > "$D/site/web/router.php" <<'PHP'
<?php
// встроенный сервер PHP — как nginx площадки: файлы — как есть, адрес ресайзера — timthumb.php,
// остальное — index.php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (preg_match('~^/resizer/w([0-9]+)-h([0-9]+)/(.*)$~', $path, $m)) {
    $_GET = ['w' => $m[1], 'h' => $m[2], 'src' => $m[3], 'zc' => '2'];
    $_SERVER['QUERY_STRING'] = http_build_query($_GET);
    chdir(__DIR__ . '/resizer');
    require __DIR__ . '/resizer/timthumb.php';
    return true;
}
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false;
}
// значок сайта на площадке кладёт хостинг (ISPConfig), а не установка: на стенде — пустой
if ($path === '/favicon.ico') {
    header('Content-Type: image/x-icon');
    return true;
}
require __DIR__ . '/index.php';
PHP
  touch "$D/php-error.log"
  chown -hR "$SITE_USER" "$D/site" "$D/php-error.log"
  port=$(php8.5 -r '$s = stream_socket_server("tcp://127.0.0.1:0"); echo parse_url("tcp://" . stream_socket_get_name($s, false), PHP_URL_PORT);')
  echo "$port" > "$D/port"
  local setup=(runuser -u "$SITE_USER" -- env ENERGINE_DB_PASSWORD="$dbpw" ENERGINE_ADMIN_PASSWORD="$adminpw"
               php8.5 "$D/site/web/index.php" setup)
  "${setup[@]}" install --config="$D/site/web/system.config.php" --url="http://127.0.0.1:$port/" --db-socket="$D/s" \
    --db-name=site --db-user=energine --admin-email=claude-test-admin@example.org --admin-name=Admin \
    < /dev/null > "$D/setup.log" 2>&1 || fail "setup install: $(tail -3 "$D/setup.log")"
  "${setup[@]}" demo < /dev/null >> "$D/setup.log" 2>&1 || fail "setup demo: $(tail -3 "$D/setup.log")"
  # PDO и клиент mariadb тестов ходят на localhost — их сокет по умолчанию переводится на стенд
  mkdir -p "$D/php.d" && printf 'pdo_mysql.default_socket=%s\nmysqli.default_socket=%s\n' "$D/s" "$D/s" > "$D/php.d/stand.ini"
  # клиент берёт сокет площадки из своего конфига ([client] socket в /etc/mysql) — он сильнее MYSQL_UNIX_PORT;
  # обёртки ставят сокет стенда явно, а вызовы с --no-defaults (tempdb.sh) не трогают
  mkdir -p "$D/bin"
  local real n
  real=$(readlink -f "$(command -v mariadb)")
  for n in mysql mariadb; do
    cat > "$D/bin/$n" <<SH
#!/bin/bash
case "\${1:-}" in --no-defaults|--defaults-file=*|--defaults-extra-file=*|--print-defaults) exec $real "\$@" ;; esac
exec $real --socket='$D/s' "\$@"
SH
    chmod 755 "$D/bin/$n"
  done
  ( umask 077; cat > "$D/local.php" <<PHP
<?php
return ['admin_email' => 'claude-test-admin@example.org', 'admin_password' => '$adminpw',
    'mailbox' => '$STAND_MAILBOX', 'log' => '$D/php-error.log'];
PHP
  )
  cat > "$D/env.sh" <<SH
export ENERGINE_CONFIG='$D/site/web/system.config.php' ENERGINE_LOCAL='$D/local.php' ENERGINE_BASE='http://127.0.0.1:$port'
export ENERGINE_WEB='$D/site/web' MYSQL_UNIX_PORT='$D/s' PHP_INI_SCAN_DIR=':$D/php.d' PATH='$D/bin':"\$PATH"
SH
  # пределы — как у PHP-FPM площадки (его php.ini): иначе встроенный сервер режет загрузки по пределам CLI (2 МБ)
  local limits=() k v
  for k in upload_max_filesize post_max_size memory_limit max_execution_time; do
    v=$(sed -n "s/^$k[[:space:]]*=[[:space:]]*//p" /etc/php/8.5/fpm/php.ini 2>/dev/null | tail -1)
    [ -n "$v" ] && limits+=(-d "$k=$v")
  done
  ( cd "$D/site/web" && exec runuser -u "$SITE_USER" -- php8.5 -d log_errors=1 -d error_log="$D/php-error.log" "${limits[@]}" \
      -S "127.0.0.1:$port" -t . router.php > "$D/server.log" 2>&1 ) &
  for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.2; done
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")" = 200 ] || fail "сайт стенда не отвечает"
  echo "стенд: http://127.0.0.1:$port/ ($D)"
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  run) shift; [ -f "$D/env.sh" ] || fail "стенд не поднят: STAND_MAILBOX=… bash $0 start"
       . "$D/env.sh"; exec "$@" ;;
  *) echo "использование: $0 start|stop|run КОМАНДА…" >&2; exit 2 ;;
esac
