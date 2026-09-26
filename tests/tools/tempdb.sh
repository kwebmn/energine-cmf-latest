# Временный экземпляр MariaDB для проверок установки: свой каталог и сокет, без сети. База площадки
# только читается — настройки сервера (кодировка, сравнение, sql_mode) и домен берутся у неё.
# Подключается через source:
#   . tests/tools/tempdb.sh
#   tempdb_start || exit 2; trap tempdb_stop EXIT
#   TM -e 'SELECT 1'                  — клиент mariadb к временному экземпляру (root через сокет)
# После tempdb_start заданы: T — каталог экземпляра, SOCK — сокет, CS, CO, SQLMODE — настройки сервера
# площадки, HOST — домен площадки, R — корень репозитория.
# TEMPDB_ACCESS=пользователь — каталог экземпляра проходим для него (встроенный сервер PHP, установщик);
# короткий TMPDIR обязателен: путь сокета ограничен 107 символами.

R="${R:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

tempdb_fail() { echo "tempdb: $*" >&2; return 2; }

TM() { env -u MYSQL_PWD mariadb --no-defaults --socket="$SOCK" -u root "$@"; }

tempdb_start() {
  T=$(mktemp -d "${TMPDIR:-/tmp}/f.XXXX") || return 2
  SOCK="$T/s"
  [ ${#SOCK} -le 107 ] || { tempdb_fail "путь сокета длиннее 107 символов, задайте короткий TMPDIR: $SOCK"; return 2; }
  if [ -n "${TEMPDB_ACCESS:-}" ]; then
    # каталог — только проход (без чтения списка): сокет и файлы, выданные пользователю, доступны по имени
    chmod 711 "$T" || return 2
  fi
  local settings
  settings=$(cd "$R" && php8.5 -r '
define("ROOT_DIR", getcwd());
$E = require "tests/env.php";
$p = new PDO("mysql:host={$E["DB_HOST"]};dbname={$E["DB_NAME"]};charset=utf8", $E["DB_USER"], $E["MYSQL_PWD"]);
$v = $p->query("SELECT @@character_set_server, @@collation_server, @@sql_mode")->fetch(PDO::FETCH_NUM);
echo implode("\n", [...$v, parse_url($E["BASE"], PHP_URL_HOST)]), "\n";') || { tempdb_fail "нет настроек сервера площадки"; return 2; }
  { read -r CS; read -r CO; read -r SQLMODE; read -r HOST; } <<< "$settings"
  # root экземпляра входит только через сокет от root системы (unix_socket): сокет открыт владельцу площадки,
  # а в каталоге хостинга его видят и соседние пользователи — пароль root им не нужен был бы вовсе
  mariadb-install-db --no-defaults --user=root --datadir="$T/data" --auth-root-authentication-method=socket \
    --skip-test-db > "$T/install.log" 2>&1 || { tempdb_fail "mariadb-install-db: $(tail -3 "$T/install.log")"; return 2; }
  mariadbd --no-defaults --user=root --datadir="$T/data" --socket="$SOCK" --pid-file="$T/mysqld.pid" \
    --skip-networking --character-set-server="$CS" --collation-server="$CO" --sql-mode="$SQLMODE" \
    --innodb-buffer-pool-size=256M --secure-file-priv="$T" --log-error="$T/error.log" &
  for _ in $(seq 150); do TM -e 'SELECT 1' > /dev/null 2>&1 && break; sleep 0.2; done
  TM -e 'SELECT 1' > /dev/null 2>&1 || { tempdb_fail "временный mariadbd не запустился: $(tail -3 "$T/error.log")"; return 2; }
  # сокет — всем, кто дошёл до него по имени (каталог выше закрыт от чтения)
  [ -n "${TEMPDB_ACCESS:-}" ] && chmod 777 "$SOCK"
  return 0
}

tempdb_stop() {
  [ -n "${T:-}" ] || return 0
  if [ -s "$T/mysqld.pid" ]; then
    kill "$(cat "$T/mysqld.pid")" 2>/dev/null
    for _ in $(seq 100); do [ -e "$T/mysqld.pid" ] || break; sleep 0.1; done
  fi
  rm -rf "$T"
}

# tempdb_create БАЗА — пустая база с настройками сервера площадки
tempdb_create() { TM -e "CREATE DATABASE \`$1\` CHARACTER SET $CS COLLATE $CO"; }

# tempdb_user БАЗА ФАЙЛ — пользователь базы для PHP (не root: root входит только через сокет от root);
# его имя — «energine», случайный пароль пишется в ФАЙЛ (режим 600) и не печатается
tempdb_user() {
  local pw
  pw=$(head -c 18 /dev/urandom | base64 | tr '+/' '-_')
  ( umask 077; printf '%s' "$pw" > "$2" ) || return 2
  # через stdin: пароль не попадает в аргументы процесса
  TM <<< "CREATE USER 'energine'@'localhost' IDENTIFIED BY '$pw'; GRANT ALL PRIVILEGES ON \`$1\`.* TO 'energine'@'localhost';"
}

# tempsite ПОЛЬЗОВАТЕЛЬ WEB — копия точки входа площадки в $T/site (переменная S): свои index.php, bootstrap.php,
# auth.php и конфиг; статика, шаблоны и карта скриптов — ссылками на WEB площадки, ядро — ссылкой на репозиторий;
# владелец — ПОЛЬЗОВАТЕЛЬ (владелец площадки, переменная SITE_USER). Установщик и встроенный сервер PHP работают
# из копии: конфиг и файлы площадки не трогаются.
tempsite() {
  SITE_USER=$1
  local web=$2 d
  S="$T/site"
  mkdir -p "$S/web/uploads" "$S/private" && ln -s "$R" "$S/private/energine" \
    && cp "$R/htdocs/index.php" "$R/htdocs/bootstrap.php" "$R/htdocs/auth.php" "$S/web/" || return 2
  # статика и карта скриптов — площадки (установка с --no-static их не раскладывает)
  for d in images scripts stylesheets templates resizer system.jsmap.php; do ln -s "$web/$d" "$S/web/$d" || return 2; done
  cat > "$S/web/router.php" <<'PHP'
<?php
// встроенный сервер PHP: файлы (статика, auth.php) — как есть, остальное — index.php, как у nginx площадки
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false;
}
require __DIR__ . '/index.php';
PHP
  chown -hR "$SITE_USER" "$S"
}

# tempsite_setup АРГУМЕНТЫ… — php index.php setup … из копии от имени владельца площадки;
# пароли — только из окружения (ENERGINE_DB_PASSWORD, ENERGINE_ADMIN_PASSWORD), вывод — вместе с ошибками
tempsite_setup() { runuser -u "$SITE_USER" -- php8.5 "$S/web/index.php" setup "$@" < /dev/null 2>&1; }

# tempsite_empty ПОЛЬЗОВАТЕЛЬ КАТАЛОГ — копия точки входа без статики: её раскладывает сама установка (setup install
# без --no-static). Статика площадки сюда не ссылается — setup linker чистит каталоги статики, и ссылки на площадку
# он вычистил бы у неё самой.
tempsite_empty() {
  local owner=$1 dir=$2
  mkdir -p "$dir/web/uploads" "$dir/private" && ln -s "$R" "$dir/private/energine" \
    && cp "$R/htdocs/index.php" "$R/htdocs/bootstrap.php" "$R/htdocs/auth.php" "$dir/web/" \
    && cp -a "$R/htdocs/resizer" "$dir/web/" && cp "$S/web/router.php" "$dir/web/" || return 2
  chown -hR "$owner" "$dir"
}
