# Energine Simple, этап 7 — чистое ядро: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** свести движок simple к ядру — без модуля `apps`, без галереи и вложений разделов, без мёртвого кода, CodeMirror и своего календаря — с зелёной проверкой на каждом шаге и одной выкладкой на simple.energine.org в конце.

**Architecture:** работа идёт в рабочем клоне `/var/www/clients/client1/web97/private/stage7/energine` (ветка `main`); живое дерево `/var/www/clients/client1/web97/private/energine` не меняется до задачи 9. Проверка — на стенде (`tests/tools/stand.sh`): временная MariaDB, установка клона с демо, встроенный сервер PHP; тесты смотрят на стенд через переменные окружения `env.php`. Изменения базы пишутся один раз — в переходе `sql/cut/stage7.sql`; файлы установки пересобирает `tests/tools/regen-sql.sh`.

**Tech Stack:** PHP 8.5, MariaDB, XSLT (ext-xsl), MooTools 1.5.2 (сжатая сборка), Jodit, bash-тесты и PHP-тесты проекта, Playwright (аудиты в `tests/audit`).

**Spec:** `docs/superpowers/specs/2026-10-01-energine-simple-stage7-core-design.md`

## Global Constraints

- Не трогать: font-awesome, модель прав, переводы (модель и неиспользуемые строки — кроме строк удалённых частей), регистрацию посетителей, `?debug`, `?struct`, кеш структуры базы, таймер, интерфейс `IFileRepository`, инструменты установщика для переводов и файлов.
- XSLT, MooTools (`mootools.min.js`), имена модулей и пространства имён остаются.
- Удаляется: модуль `apps`, галерея и вложения разделов, `OGPrimitive`, мёртвый код (спецификация §3.3), CodeMirror и `datepicker`.
- Изменения базы — только через `sql/cut/stage7.sql`; повторный прогон ничего не меняет.
- Ни один тест не запускается без стенда: `bash tests/tools/stand.sh run …`. `tests/tools/rebuild.sh` и `tests/setup-linker.sh` из клона не запускаются.
- Пароли не пишутся в код, документы, вывод и коммиты; хук `.githooks/pre-commit` остаётся включённым.
- Тестовые записи называются `claude-test*`/`claude-*` и убираются тестами; тестовые письма — только в локальный ящик (`STAND_MAILBOX`).
- Коммит в конце каждой задачи; последняя строка сообщения — `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Живой сайт, его база и файлы меняются только в задаче 9 — после отдельного «да» владельца и с резервной копией.

## Обозначения

- Все команды — из корня клона: `cd /var/www/clients/client1/web97/private/stage7/energine`.
- `L` — журнал и логи плана (каталог не в git; в каждой команде, где он нужен, задаётся заново):
  `L=/var/www/clients/client1/web97/private/stage7/energine/.superpowers/sdd/2026-10-01-energine-simple-stage7-core`
- Номера строк из описи — на коммите `f5f66ff8` (код тот же, что на `563115cd`).

## Review Focus

- **Раздел со своим XML или шаблоном удалённой части** (например, страница на `news.content.xml` или с `smap_content_xml`, где назван `NewsFeed`): после `stage7.sql` раздел открывается текстовой страницей (200), назван в выводе, содержимое не потеряно. Тест — проверка `stage7.sql` в `tests/tools/migration-check.sh` (задача 4, дополняется в задаче 5).
- **Формы всех гридов после удаления вкладки вложений:** каждая форма добавления и правки открывается и сохраняется. Тест — `smoke-roundtrip.php` и обход `audit/crawl.js` по `crawl-singles.txt` (задача 5).
- **Устаревшая карта скриптов:** `system.jsmap.php` после удаления файлов не ссылается на них, страницы админки не получают 404 на скрипты. Тест — `audit/crawl.js` (неудачные запросы) после `setup linker && setup scriptMap` (задачи 2, 4, 5, 7).
- **Дата из встроенного поля браузера** (`YYYY-MM-DD`, `YYYY-MM-DDTHH:MM`) принимается сервером: дата рождения в профиле сохраняется, фильтр журнала по дате работает. Тест — `smoke-profile.php` с датой рождения и проверка фильтра журнала в `audit/grids.js` (задача 7).
- **Шаблоны писем после удаления писем обратной связи:** письма регистрации и восстановления пароля уходят и открываются в редакторе. Тест — `smoke-mail.php` (задача 3, ожидание двух шаблонов — задача 4).

---

### Task 1: Стенд и замер до начала

**Files:**
- Create: `tests/tools/stand.sh`
- Modify: `tests/env.php` (переопределения `ENERGINE_WEB`, `ENERGINE_LOCAL`, `ENERGINE_BASE`), `tests/env-guard.sh` (снимать новые переменные), `tests/README.md` (раздел «Стенд»)

**Interfaces:**
- Produces: `bash tests/tools/stand.sh start|stop|run КОМАНДА…`; после `start` — каталог стенда `$STAND_DIR` (по умолчанию `/tmp/stand-<владелец клона>`) с `env.sh`, `local.php`, `site/web`, `php-error.log`. `run` выполняет команду с `ENERGINE_CONFIG`, `ENERGINE_LOCAL`, `ENERGINE_BASE`, `ENERGINE_WEB`, `MYSQL_UNIX_PORT`, `PHP_INI_SCAN_DIR`.
- `env.php`: `getenv('ENERGINE_WEB')`, `getenv('ENERGINE_LOCAL')`, `getenv('ENERGINE_BASE')` — если не заданы, поведение прежнее.

- [ ] **Step 1: Переопределения в `env.php`**

В `tests/env.php` строки
```php
$web = dirname($root, 2) . '/web';
$configFile = getenv('ENERGINE_CONFIG') ?: $web . '/system.config.php';
$localFile = __DIR__ . '/local.php';
```
заменить на
```php
// стенд (tests/tools/stand.sh) подменяет каталог web, конфиг, учётные данные и адрес; без переменных — площадка
$web = getenv('ENERGINE_WEB') ?: dirname($root, 2) . '/web';
$configFile = getenv('ENERGINE_CONFIG') ?: $web . '/system.config.php';
$localFile = getenv('ENERGINE_LOCAL') ?: __DIR__ . '/local.php';
```
и строку `'BASE' => 'https://' . $config['site']['domain'],` — на
```php
    'BASE' => getenv('ENERGINE_BASE') ?: 'https://' . $config['site']['domain'],
```
В `tests/env-guard.sh` в команде `env -u DB_NAME -u DB_USER -u DB_HOST -u MYSQL_PWD` добавить `-u ENERGINE_WEB -u ENERGINE_LOCAL -u ENERGINE_BASE`.

- [ ] **Step 2: Написать `tests/tools/stand.sh`**

```bash
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
  # копия точки входа: ядро — ссылкой на репозиторий, статику раскладывает установка
  mkdir -p "$D/site/web/uploads" "$D/site/private" && ln -s "$R" "$D/site/private/energine" \
    && cp "$R/htdocs/index.php" "$R/htdocs/bootstrap.php" "$R/htdocs/auth.php" "$D/site/web/" \
    && cp -a "$R/htdocs/resizer" "$D/site/web/" || fail "копия точки входа не создана"
  cat > "$D/site/web/router.php" <<'PHP'
<?php
// встроенный сервер PHP: файлы — как есть, остальное — index.php, как у nginx площадки
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file(__DIR__ . $path)) {
    return false;
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
  ( umask 077; cat > "$D/local.php" <<PHP
<?php
return ['admin_email' => 'claude-test-admin@example.org', 'admin_password' => '$adminpw',
    'mailbox' => '$STAND_MAILBOX', 'log' => '$D/php-error.log'];
PHP
  )
  cat > "$D/env.sh" <<SH
export ENERGINE_CONFIG='$D/site/web/system.config.php' ENERGINE_LOCAL='$D/local.php' ENERGINE_BASE='http://127.0.0.1:$port'
export ENERGINE_WEB='$D/site/web' MYSQL_UNIX_PORT='$D/s' PHP_INI_SCAN_DIR=':$D/php.d'
SH
  ( cd "$D/site/web" && exec runuser -u "$SITE_USER" -- php8.5 -d log_errors=1 -d error_log="$D/php-error.log" \
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
```

- [ ] **Step 3: Поднять стенд и проверить, что тесты смотрят на него**

```bash
cd /var/www/clients/client1/web97/private/stage7/energine
STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run php8.5 tests/env.php --shell | grep -E '^export (BASE|WEB|DB_HOST|DB_NAME)='
```
Expected: `стенд: http://127.0.0.1:<порт>/ (/tmp/stand-web97)`; `BASE='http://127.0.0.1:<порт>'`, `WEB='/tmp/stand-web97/site/web'`, `DB_NAME='site'`. Без стенда `php8.5 tests/env.php --shell` в клоне печатает «env.php: нет файла …/private/web/system.config.php» и выходит с кодом 2.

- [ ] **Step 4: Замер до начала на стенде**

```bash
L=/var/www/clients/client1/web97/private/stage7/energine/.superpowers/sdd/2026-10-01-energine-simple-stage7-core
mkdir -p "$L"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/baseline-regression.log" 2>&1; echo "exit $?"
bash tests/tools/stand.sh run bash tests/env-guard.sh
grep -E '^(FAIL|== )' "$L/baseline-regression.log" | sort | uniq -c
```
Expected: `env-guard: ok`. Регрессия проходит на нынешнем коде; если на стенде падают проверки, которые зависят только от площадки (HTTPS, домен без порта, ящик ISPConfig), — каждая записывается в журнал как известное отличие стенда (`Task 1: Ruling: …`), и дальше сравнение идёт с этим списком. Падение функции сайта — ошибка стенда или кода: разобрать до шага 5.

- [ ] **Step 5: Обход браузером на стенде**

```bash
cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node crawl.js crawl-guest.txt crawl-admin.txt crawl-singles.txt "'"$L"'/baseline-crawl.json"'; echo "exit $?"
```
Expected: exit 0; ошибок JS и неудачных запросов нет (известные отличия стенда — в журнал).

- [ ] **Step 6: Описание стенда в `tests/README.md` и коммит**

В `tests/README.md` после раздела «Откуда тесты берут адрес, базу и пароли» добавить:
```markdown
## Стенд

`tests/tools/stand.sh` поднимает сайт из этого репозитория без площадки: временная MariaDB (сокет, без сети),
установка с демо, встроенный сервер PHP на 127.0.0.1. Конфиг, база и файлы площадки не читаются.

    STAND_MAILBOX=<локальный ящик> bash tests/tools/stand.sh start
    bash tests/tools/stand.sh run bash tests/regression.sh
    bash tests/tools/stand.sh stop

`run` задаёт для `env.php` адрес, конфиг, учётные данные и каталог `web` стенда (`ENERGINE_BASE`,
`ENERGINE_CONFIG`, `ENERGINE_LOCAL`, `ENERGINE_WEB`), а PDO и клиенту `mariadb` — сокет базы стенда.
```
```bash
git add tests/tools/stand.sh tests/env.php tests/env-guard.sh tests/README.md docs/superpowers/plans/2026-10-01-energine-simple-stage7-core.md
git commit -m "Этап 7: стенд для проверки без площадки, план этапа

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Мёртвые файлы, зависимости composer, установщик

**Files:**
- Delete: `core/modules/share/scripts/{mootools.js,mootools.ext.js,Menu.js,GridManagerModal.js,TextBlockSource.js}`, `core/modules/share/stylesheets/{errors.css,mootools-colorpicker.css}`, `core/modules/share/config/{GridModal.component.xml,TextBlockSource.component.xml}`, `core/modules/share/gears/{ComponentProxyBuilder,EventHandler,FieldRow,FormBuilder,JSONPCustomBuilder,JSONUploadBuilder}.php`, `only_for_doc.php`, `core/modules/share/components/{PageInfo,Remover,SiteProperties,TextBlockSource}.php`, `core/modules/share/transformers/base.xslt`, `core/modules/share/templates/content/default.content.xml`, `core/modules/share/templates/layout/new.layout.xml`, `setup/JSqueeze.php`, `cli/`, `jambalaya/`, `image-cache/`, `tests/smoke.sh`, неиспользуемые картинки (список — шаг 3)
- Modify: `setup/Setup.php` (без JSqueeze и `MODE_COPY`), `setup/index.php` (только CLI), `core/modules/share/components/DataSet.php` (без `source()`), `core/modules/share/config/TextBlock.component.xml` (без состояния `source`), `core/modules/share/transformers/text.xslt` (без шаблонов источника), `core/modules/share/transformers/document.xslt` (без шаблона `SiteProperties`), `composer.json`, `composer.lock`, `.gitignore`, `tests/env-guard.sh`, `tests/no-traces.sh`
- Test: `tests/no-traces.sh` категория `dead`

**Interfaces:**
- Consumes: стенд (задача 1).
- Produces: `Setup::linkCore($globPattern, $module, $level = 1)` и `Setup::linkSite($globPattern, $dir)` — без параметра режима; категория `dead` в `no-traces.sh`.

- [ ] **Step 1: Категория `dead` в `no-traces.sh` (падающая проверка)**

В заголовок `tests/no-traces.sh` добавить строку `# Этап 7 — ядро: dead apps gallery editors`, в список `mods` по умолчанию — `dead`, а после строк этапа 6:
```bash
# этап 7: мёртвый код ядра (спецификация этапа 7, §3.3)
CODE[dead]='JSqueeze|MODE_COPY|ComponentProxyBuilder|EventHandler|FieldRow|\bFormBuilder\b|JSONPCustomBuilder|JSONUploadBuilder|\bPageInfo\b|\bRemover\b|components\\SiteProperties\b|TextBlockSource|GridManagerModal|GridModal|mootools\.ext|mootools-colorpicker|base\.xslt|new\.layout\.xml|default\.content\.xml'
FILES[dead]='core/modules/share/scripts/mootools.js core/modules/share/scripts/mootools.ext.js core/modules/share/scripts/Menu.js core/modules/share/scripts/GridManagerModal.js core/modules/share/stylesheets/errors.css core/modules/share/stylesheets/mootools-colorpicker.css setup/JSqueeze.php cli jambalaya image-cache tests/smoke.sh'
```
Из `CODE_DIRS` убрать `cli`.

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh code dead`
Expected: выход 1, найдены файлы и ссылки категории `dead`.

- [ ] **Step 2: Удалить мёртвые файлы**

Для каждого файла из списка Files перед удалением — проверка ссылок (имя файла без расширения во всём коде, XML, XSLT, JS, `web/system.jsmap.php` стенда):
```bash
for n in mootools.ext Menu GridManagerModal GridModal TextBlockSource ComponentProxyBuilder EventHandler FieldRow FormBuilder JSONPCustomBuilder JSONUploadBuilder PageInfo Remover SiteProperties base.xslt default.content new.layout errors.css mootools-colorpicker JSqueeze only_for_doc jambalaya; do
  printf '%-22s ' "$n"; git grep -l -w -F "$n" -- core site htdocs setup configs | grep -v -e "/$n\." | tr '\n' ' '; echo
done
```
Ссылки, которые останутся после удаления, — только в файлах, удаляемых этим же шагом, и в правках шага 4. Иначе файл не удаляется, в журнал — `Task 2: Ruling`. Затем:
```bash
git rm -q core/modules/share/scripts/mootools.js core/modules/share/scripts/mootools.ext.js core/modules/share/scripts/Menu.js \
  core/modules/share/scripts/GridManagerModal.js core/modules/share/scripts/TextBlockSource.js \
  core/modules/share/stylesheets/errors.css core/modules/share/stylesheets/mootools-colorpicker.css \
  core/modules/share/config/GridModal.component.xml core/modules/share/config/TextBlockSource.component.xml \
  core/modules/share/gears/ComponentProxyBuilder.php core/modules/share/gears/EventHandler.php core/modules/share/gears/FieldRow.php \
  core/modules/share/gears/FormBuilder.php core/modules/share/gears/JSONPCustomBuilder.php core/modules/share/gears/JSONUploadBuilder.php \
  core/modules/share/components/PageInfo.php core/modules/share/components/Remover.php core/modules/share/components/SiteProperties.php \
  core/modules/share/components/TextBlockSource.php core/modules/share/transformers/base.xslt \
  core/modules/share/templates/content/default.content.xml core/modules/share/templates/layout/new.layout.xml \
  setup/JSqueeze.php tests/smoke.sh
git rm -rq cli jambalaya image-cache
git rm -q $(git ls-files | grep -E '(^|/)only_for_doc\.php$')
```
`Scrollbar.js` и его картинки удаляются, только если `git grep -n "Scrollbar" -- core` показывает одни комментарии; иначе остаются (журнал).

- [ ] **Step 3: Неиспользуемые картинки**

```bash
for f in $(git ls-files 'core/*/images/*' 'site/*/images/*' 'core/*/templates/icons/*'); do
  b=$(basename "$f"); git grep -q -F "$b" -- core site htdocs setup configs ':!*.gif' ':!*.png' ':!*.jpg' || echo "$f"
done > /tmp/stand-unused-images.txt; wc -l < /tmp/stand-unused-images.txt
```
Expected: около 68 файлов (опись: иконки шаблонов кроме `empty.icon.gif` и `divisions_list.icon.gif`, `toolbar/*.gif` кроме `separator.gif` и `structure.gif`, старые значки и стрелки календаря и дерева, `energine_logo.png`). Иконки модулей `apps` и `gallery.icon.gif` удаляются в задачах 4 и 5 — их из списка убрать. Затем `git rm -q $(cat /tmp/stand-unused-images.txt)`.

- [ ] **Step 4: Правки внутри файлов**

`setup/Setup.php`: удалить `require_once('JSqueeze.php');`, константы `MODE_SYMLINK` и `MODE_COPY` с их комментариями; `linkCore` и `linkSite` — без параметра режима и без ветки копирования:
```php
    private function linkCore($globPattern, $module, $level = 1) {
        $fileList = glob($globPattern);
        if (!empty($fileList)) {
            foreach ($fileList as $fo) {
                if (is_dir($fo)) {
                    $dir = $module . DIRECTORY_SEPARATOR . basename($fo);
                    if (!file_exists($dir)) {
                        mkdir($dir);
                        $this->text('Создаем директорию ', $dir);
                    }
                    $this->linkCore($fo . DIRECTORY_SEPARATOR . '*', $dir, $level + 1);
                } else {
                    //Если одним из низших по приоритету модулей был уже создан симлинк
                    //то затираем его нафиг
                    if (file_exists($dest = $module . DIRECTORY_SEPARATOR . basename($fo))) {
                        unlink($dest);
                    }
                    $this->text('Создаем симлинк ', $fo, ' --> ', $dest);
                    if (!@symlink($fo, $dest)) {
                        throw new \Exception('Не удалось создать символическую ссылку с ' . $fo . ' на ' . $dest);
                    }
                }
            }
        }
    }
```
```php
    private function linkSite($globPattern, $dir) {
        $fileList = glob($globPattern);
        if (!empty($fileList)) {
            foreach ($fileList as $fo) {
                $fo_stripped = str_replace(SITE_DIR, '', $fo);
                list(, , $module) = explode(DIRECTORY_SEPARATOR, $fo_stripped);
                $new_dir = implode(DIRECTORY_SEPARATOR, array($dir, $module));
                if (!file_exists($new_dir)) {
                    mkdir($new_dir);
                }
                $linkPath = implode(DIRECTORY_SEPARATOR, array($dir, $module, basename($fo_stripped)));
                $this->text('Создаем симлинк ', $fo, ' --> ', $linkPath);
                if (!@symlink($fo, $linkPath)) {
                    throw new \Exception('Не удалось создать символическую ссылку с ' . $fo . ' на ' . $linkPath);
                }
            }
        }
    }
```
В `linkerAction` убрать аргумент `self::MODE_SYMLINK,` у обоих вызовов. Docblock-и обоих методов — без `@param string $mode`.

`setup/Setup.php::checkEnvironment`: удалить проверку
```php
        if (!$this->isFromConsole && !$this->config['site']['debug']) {
            throw new \Exception('Нет. С отключенным режимом отладки я работать не буду, и не просите. Запускайте меня после того как исправите в конфиге ["site"]["debug"] с 0 на 1.');
        }
```
и строку `@throws` с этим текстом в docblock.

`setup/index.php`: блок от `$acceptableActions = array(` до закрывающей скобки разбора аргументов заменить на
```php
// установщик запускается только из CLI (bootstrap.php подключает его при PHP_SAPI === 'cli'):
// php index.php setup ДЕЙСТВИЕ [АРГУМЕНТЫ…]
$isConsole = true;
$args = array_slice($argv, 2);
$action = $args ? array_shift($args) : 'install';
$additionalArgs = $args ? array_combine(range(1, count($args)), $args) : array();
```
(ключи `$additionalArgs` — с 1, как было после `unset($additionalArgs[0])`).

`DataSet.php`: удалить метод `source()` и регистрацию состояния `source` (опись: строки 395 и 655–663 на `f5f66ff8`); `TextBlock.component.xml`: удалить `<state name="source">…</state>`; `text.xslt`: удалить шаблоны режима источника (опись: строки 46–99); `document.xslt`: удалить пустой шаблон компонента `SiteProperties` (опись: строка 258).

`composer.json`: из `require` удалить `"symfony/console": "^7.4"`; затем
```bash
COMPOSER_ALLOW_SUPERUSER=1 php8.5 /usr/bin/composer update --no-interaction --no-progress 2>&1 | tail -3
```
Expected: `vendor/` без `symfony` и `psr`, `composer.lock` без пакетов. Если composer требует сеть — `composer.lock` правится до `"packages": []`, `composer dump-autoload` (журнал).

`.gitignore`: удалить строки `/image-cache/*` и `!/image-cache/readme.txt`. `tests/env-guard.sh`: из списка скриптов убрать `smoke.sh`.

- [ ] **Step 5: Проверка**

```bash
git ls-files '*.php' | xargs -n 50 php8.5 -l 2>&1 | grep -v '^No syntax errors' | head
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/no-traces.sh code dead; echo "exit $?"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t2-regression.log" 2>&1; grep -E '^(FAIL|== )' "$L/t2-regression.log" | sort | uniq -c
```
Expected: синтаксических ошибок нет; стенд поднимается заново (установка раскладывает статику без удалённых файлов); `no-traces dead` — выход 0; регрессия — как в замере задачи 1. Обход `crawl.js` — без неудачных запросов.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "Этап 7: мёртвый код ядра — файлы без ссылок, JSqueeze и копирование статики, symfony/console

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Тесты переводятся на ядро

**Files:**
- Modify: `tests/smoke-csrf.php`, `tests/smoke-antispam.php`, `tests/smoke-rights.php`, `tests/smoke-editing.php`, `tests/menu.php`, `tests/smoke-mail.php`, `tests/smoke-write.sh`, `tests/smoke-roundtrip.php`, `tests/smoke-final.sh`, `tests/cleanup-mail.php`, `tests/regression.sh`, `tests/paths-all.txt`, `tests/paths-guest.txt`, `tests/audit/{crawl-guest,crawl-admin,crawl-singles}.txt`, `tests/audit/editors.js`, `tests/audit/editors-db.php`, `tests/audit/theme.js`, `tests/audit/theme-db.php`, `tests/audit/grids.js`, `tests/audit/grids-db.php`

**Interfaces:**
- Consumes: стенд (задача 1), разделы ядра: `register` (1278), `users` (1345), `mail-templates` (3644), `structure` (1279), `sitemap` (3631); демо: `info` (3627), `features` (3709), `features/content` (3710).
- Produces: тесты без обращений к `apps_*`, `/news/`, `/contacts/`, `/media/`, `news-editor`, `feedback-editor`; зелёные на нынешнем коде.

Правило: каждая проверка новостей или обратной связи либо переносится на функцию ядра с тем же смыслом (таблица ниже), либо удаляется вместе с функцией, которую проверяла (save-text новостей, форма обратной связи, галерея, лента).

| Файл | Было | Станет |
|---|---|---|
| `smoke-csrf.php` | токен со страницы `/contacts/`; отправка обратной связи без токена и с чужим токеном | токен со страницы `/register/`; `POST /register/save-new-user/` без токена и с чужим токеном — 422, пользователь не создан |
| `smoke-csrf.php` | «страница обратной связи не выдаёт адреса получателей» | удаляется (обратной связи нет) |
| `smoke-csrf.php` | сохранение новости без токена / с токеном гостя / с токеном формы | сохранение имени тестового пользователя `MARK-…@localhost` в `/admin/users/single/userEditor/<id>/edit/` → `…/save`: поле `user_users[u_fullname]` |
| `smoke-csrf.php` | удаление обращения GET-ом — отказ, POST-ом — принято | удаление тестового пользователя: GET `…/userEditor/<id>/delete/` — 422, POST — пользователь удалён (после проверки `activate`) |
| `smoke-csrf.php` | `return=/news/` | `return=/sitemap/` |
| `smoke-antispam.php` | обратная связь и регистрация | только регистрация (часть обратной связи и её очистка удаляются) |
| `smoke-rights.php` | группа с правом 2 на `news-editor`, строки `newsRepo/get-data` | группа с правом 2 на `mail-templates`, строки `/admin/mail-templates/single/mailTemplateEditor/get-data/page-1` |
| `smoke-editing.php` | save-text заголовка новости (строки 56–86 на `f5f66ff8`) | удаляется: `DBDataSet::saveText` нужен только новостям и уходит в задаче 4 |
| `menu.php` | флаг меню у `contacts` | флаг меню у `info` (сообщения — «Справка» вместо «Контакты») |
| `smoke-mail.php` | блок «feedback form» | удаляется |
| `smoke-write.sh` | «news: add, view, delete» | удаляется |
| `smoke-roundtrip.php` | формы `feedback recipient`, `news`; раздел 3594 | формы удаляются; раздел — 3627 (`$rights(3627)`) |
| `smoke-final.sh` | 404 и архив `news/…`; карта сайта ждёт `news contacts features`; формы `news-editor`, `feedback-editor`; раздел 3594 | 404 и архив новостей удаляются; карта ждёт `info features`; формы удаляются; раздел — 3627 |
| `cleanup-mail.php` | `DELETE FROM apps_feedback …` | строка удаляется |
| `regression.sh` | переключение получателей обратной связи на `MAILBOX` и `restore()` | удаляется; заголовок блока — `### mail` |
| списки адресов | `news/`, `contacts/`, `media/`, `admin/news-editor/…`, `admin/feedback-editor/…`, `admin/news-categories/` | удаляются |
| `audit/editors.js` | Jodit в форме новости (`#news_text_rtf_1`), страница `news/` для правки на странице, шаг 9 (заголовок новости) | Jodit в форме раздела: описание `#smap_description_rtf_1` в `admin/structure/single/divEditor/3710/edit/`; правка на странице — `features/content/`; шаг 9 удаляется |
| `audit/editors-db.php` | `news-id`, `news-get`, `news-snap`, `news-restore`, `news-rtf` по `apps_news_translation` | `page-id` (3710), `page-get`, `page-snap`, `page-restore`, `page-rtf` по `share_sitemap_translation.smap_description_rtf` |
| `audit/theme.js`, `theme-db.php` | страницы «лента новостей», «новость», «галерея», «обратная связь», листалка ленты, og:image новости, `news-add/remove` | удаляются; остальные страницы и проверки темы — как были |
| `audit/grids.js`, `grids-db.php` | грид и форма просмотра обратной связи, выбор раздела новости | удаляются |

- [ ] **Step 1: Правки по таблице** — каждый файл правится так, чтобы оставшиеся проверки шли по разделам ядра и демо из Interfaces; новые проверки `smoke-csrf.php` используют уже имеющиеся в нём функции (`tokens`, `formData`, `http`, `check`, `login`, `logout`) и созданного им пользователя `MARK-<pid>@localhost` (удаляется очисткой).

- [ ] **Step 2: В тестах не осталось удаляемых частей**

```bash
git grep -n -E "apps_|news|feedback|contacts|/media/|gallery|NewsFeed|newsRepo" -- tests ':!tests/tools/migration-check.sh' ':!tests/no-traces.sh' ':!tests/README.md'
```
Expected: пусто (кроме `tests/tools/fingerprint.php`, `install-check.sh`, `regen-sql.sh` — их правит задача 4).

- [ ] **Step 3: Тесты зелёные на нынешнем коде**

```bash
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t3-regression.log" 2>&1; grep -E '^(FAIL|== )' "$L/t3-regression.log" | sort | uniq -c
cd tests/audit && for t in editors grids theme; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/t3-$t.log" 2>&1; echo "$t exit $?"; done
```
Expected: регрессия — как в замере задачи 1, все аудиты — exit 0.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "Этап 7: тесты — на разделах ядра, без новостей и обратной связи"` (с `Co-Authored-By`).

### Task 4: Удаление модуля `apps` и первая часть `stage7.sql`

**Files:**
- Delete: `core/modules/apps/` целиком; `site/modules/main/templates/content/{news_categories_editor,news_repository,feedback_recipients_editor}.content.xml`; `core/modules/share/components/LinkingEditor.php`; `core/modules/share/config/SiteDivisionSelector.component.xml`; `core/modules/share/scripts/DivSelector.js`
- Create: `sql/cut/stage7.sql`
- Modify: `site/modules/main/transformers/main.xslt` (без `apps/include.xslt`), `core/modules/share/templates/content/main.content.xml` (без `topNews`), `site/modules/main/transformers/energine.xslt` и `site/modules/main/stylesheets/main.css` (без блоков ленты и новостей), `core/modules/share/stylesheets/singlemode.css` (без `.apps_feedback`), `core/modules/share/transformers/form.xslt` (без ветки `FeedbackForm`), `core/modules/share/components/DivisionEditor.php` (без `selector()`), `core/modules/share/config/{DivisionEditor,SiteDivisionEditor}.component.xml` (без состояния `selector`), `core/modules/share/transformers/divisionEditor.xslt` (без шаблонов выбора раздела), `core/modules/share/components/DBDataSet.php` (без `saveText()`), `core/modules/share/templates/content/mail_templates_editor.content.xml` (контейнер `mainContainer`), конфиг модулей в `configs/system.config.default.php` и шаблоне установщика (без `apps`), `setup/Setup.php::demoAction` (демо узнаётся по `share_textblocks`), `tests/tools/{fingerprint.php,install-check.sh,regen-sql.sh,migration-check.sh}`, `tests/smoke-mail.php` (2 шаблона), `tests/no-traces.sh` (категория `apps`), `sql/structure.sql`, `sql/data.sql`, `sql/demo.sql` (пересборкой)

**Interfaces:**
- Consumes: тесты задачи 3; `regen-sql.sh` и `migration-check.sh` с окружением стенда.
- Produces: `sql/cut/stage7.sql` (часть «apps»), 22 таблицы.

- [ ] **Step 1: Категория `apps` и проверка перехода (падающие)**

В `tests/no-traces.sh`:
```bash
CODE[apps]='Energine\\apps\\|modules/apps/|\bapps_(news|feedback)|NewsFeed|NewsRepository|NewsEditor|NewsCategories|FeedbackForm|FeedbackList|FeedbackRecipients|LinkingEditor|DivSelector|SiteDivisionSelector|topNews|news-editor|news-categories|feedback-editor|newsContainer|saveText'
FILES[apps]='core/modules/apps core/modules/share/components/LinkingEditor.php core/modules/share/scripts/DivSelector.js core/modules/share/config/SiteDivisionSelector.component.xml'
```
и по базе — по образцу категорий этапа 6: таблиц `apps_%` нет, разделов с `smap_segment IN ('news-editor','news-categories','feedback-editor','recipients')` и шаблонов `news*.content.xml`, `feedback*.content.xml`, `main/news_*.content.xml`, `main/feedback_*.content.xml` нет, почтовых шаблонов `feedback_form%` нет.

В `tests/tools/migration-check.sh` — блок «переход на этап 7»: база из файлов установки коммита `f5f66ff8` (`git show f5f66ff8:sql/structure.sql` и т. д.) с демо, в неё добавлены раздел со своим XML (`smap_content_xml` с `Energine\apps\components\NewsFeed`) и раздел на `default.content.xml`; после `stage7.sql`:
- таблиц `apps_%` нет; разделов админки новостей и обратной связи нет; шаблонов писем `feedback_form%` нет;
- раздел со своим XML и разделы на шаблонах новостей и обратной связи — на `textblock.content.xml`, их `smap_id` названы в выводе; `share_textblocks` и `share_textblocks_translation` не изменились;
- раздел на `default.content.xml` — на `main.content.xml`;
- повторный прогон ничего не меняет (отпечаток `fingerprint.php` до и после второго прогона одинаков).

Run: `bash tests/tools/stand.sh run bash tests/tools/migration-check.sh; bash tests/tools/stand.sh run bash tests/no-traces.sh all apps`
Expected: оба — выход 1 (нет `stage7.sql`, следы `apps` есть).

- [ ] **Step 2: `sql/cut/stage7.sql` — часть «apps»**

```sql
-- Переход базы на этап 7 (ядро): модуль apps удаляется. Повторный прогон ничего не меняет.
-- Внешние ключи share_sitemap, mail_templates и share_lang_tags — ON DELETE CASCADE: вместе со строкой уходят
-- подразделы, переводы, права, текстовые блоки.
SET NAMES utf8mb4;

-- разделы админки новостей и обратной связи (feedback_list.content.xml — только у админки): удаляются
DELETE FROM share_sitemap WHERE smap_content IN ('main/news_repository.content.xml', 'main/news_categories_editor.content.xml',
  'feedback_list.content.xml', 'main/feedback_recipients_editor.content.xml');

-- разделы сайта на шаблонах удалённых частей и со своим XML, где они названы, — текстовые страницы
-- (содержимое остаётся); их номера — в выводе
SELECT CONCAT('этап 7: раздел ', smap_id, ' (', smap_segment, ') переведён на textblock.content.xml') AS `переход`
  FROM share_sitemap
  WHERE smap_content IN ('news.content.xml', 'feedback_form.content.xml')
     OR smap_content_xml LIKE '%apps\\\\components\\\\%' OR smap_layout_xml LIKE '%apps\\\\components\\\\%';
UPDATE share_sitemap SET smap_content = 'textblock.content.xml', smap_content_xml = NULL
  WHERE smap_content IN ('news.content.xml', 'feedback_form.content.xml')
     OR smap_content_xml LIKE '%apps\\\\components\\\\%';
UPDATE share_sitemap SET smap_layout_xml = NULL WHERE smap_layout_xml LIKE '%apps\\\\components\\\\%';
UPDATE share_sitemap SET smap_content = 'main.content.xml' WHERE smap_content = 'default.content.xml';
UPDATE share_sitemap SET smap_layout = 'default.layout.xml' WHERE smap_layout = 'new.layout.xml';

-- почтовые шаблоны обратной связи (переводы — каскадом)
DELETE FROM mail_templates WHERE template_sysname IN ('feedback_form', 'feedback_form_admin');

-- строки переводов, которые использовали только новости и обратная связь (список — шаг 3)
-- STAGE7-APPS-CONSTANTS

DROP TABLE IF EXISTS apps_news_uploads, apps_news_translation, apps_news,
  apps_feedback, apps_feedback_recipient_translation, apps_feedback_recipient;
```
Шаблоны админки сверяются с `sql/data.sql` (`smap_content` разделов 1332, 3727, 3630, 3637); при расхождении — правка и `Task 4: Ruling`.

- [ ] **Step 3: Список констант переводов «apps»**

```bash
bash tests/tools/stand.sh run php8.5 -r '
$E = require "tests/env.php"; $p = new PDO("mysql:host={$E["DB_HOST"]};dbname={$E["DB_NAME"]};charset=utf8", $E["DB_USER"], $E["MYSQL_PWD"]);
foreach ($p->query("SELECT ltag_name FROM share_lang_tags ORDER BY ltag_name")->fetchAll(PDO::FETCH_COLUMN) as $n)
  if (preg_match("/NEWS|FEED|RCP_|FEEDBACK|TOPNEWS|READ_MORE|BACK_TO_LIST|DIVISIONS|BTN_MOVE_CANCEL|BTN_RETURN_LIST|NO_EMAIL_ENTERED/", $n)) echo $n, "\n";' > /tmp/stand-apps-constants.txt
while read c; do git grep -q -w "$c" -- core/modules/share core/modules/user core/modules/seo site htdocs setup && echo "используется: $c"; done < /tmp/stand-apps-constants.txt
```
Expected: список констант новостей и обратной связи; «используется» — только для констант, которые остаются в ядре (они из списка убираются). Оставшийся список вписывается в `stage7.sql` вместо маркера `-- STAGE7-APPS-CONSTANTS` одной строкой (переводы — каскадом):
```bash
php8.5 -r '$n = array_filter(array_map("trim", file("/tmp/stand-apps-constants.txt")));
echo "DELETE FROM share_lang_tags WHERE ltag_name IN (", implode(", ", array_map(fn($c) => "\x27$c\x27", $n)), ");\n";'
```

- [ ] **Step 4: Удалить код `apps` и связанные части ядра**

```bash
git rm -rq core/modules/apps
git rm -q site/modules/main/templates/content/news_categories_editor.content.xml site/modules/main/templates/content/news_repository.content.xml \
  site/modules/main/templates/content/feedback_recipients_editor.content.xml core/modules/share/components/LinkingEditor.php \
  core/modules/share/config/SiteDivisionSelector.component.xml core/modules/share/scripts/DivSelector.js
git grep -n -E "apps|topNews|FeedbackForm|selector|saveText|newsContainer" -- core site setup configs | grep -v "^core/modules/share/scripts/codemirror"
```
По каждой оставшейся строке — правка из списка Modify: удалить include и блоки, метод `DivisionEditor::selector()` (опись: строки 636–641) и `<state name="selector">` в обоих конфигах редактора разделов, шаблоны DivSelector в `divisionEditor.xslt`, `DBDataSet::saveText()` (строки 714–… до конца метода), модуль `apps` в списке модулей конфигов; `newsContainer` → `mainContainer`. В `Setup::demoAction` проверка «демо уже установлено» — `SELECT COUNT(*) FROM share_textblocks`.

- [ ] **Step 5: Файлы установки из перехода**

`tests/tools/regen-sql.sh`: переход — `sql/cut/stage7.sql` (вместо `stage6.sql`); из списков таблиц удалить `apps_news apps_news_translation apps_news_uploads apps_feedback apps_feedback_recipient apps_feedback_recipient_translation`. `tests/tools/fingerprint.php`: из `$skipCols` удалить `feed_date`, `news_date`. `tests/tools/install-check.sh`: таблиц — 22; «демо-строк нет» — `share_textblocks` и `share_uploads` (`"0 1"`).
```bash
bash tests/tools/stand.sh run bash tests/tools/regen-sql.sh; echo "exit $?"
git diff --stat -- sql/
```
Expected: exit 0; `structure.sql` без таблиц `apps_*`; `data.sql` без разделов админки новостей и обратной связи и писем `feedback_form*`; `demo.sql` без строк `apps_*`, разделы `news` и `contacts` — на `textblock.content.xml` (их удаление из демо — задача 5).

- [ ] **Step 6: Проверка**

```bash
git ls-files '*.php' | xargs -n 50 php8.5 -l 2>&1 | grep -v '^No syntax errors' | head
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/no-traces.sh all apps; echo "no-traces $?"
bash tests/tools/stand.sh run bash tests/tools/migration-check.sh; echo "migration $?"
bash tests/tools/stand.sh run bash tests/tools/install-check.sh; echo "install $?"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t4-regression.log" 2>&1; grep -E '^(FAIL|== )' "$L/t4-regression.log" | sort | uniq -c
```
Expected: все — выход 0 (кроме известных отличий стенда из задачи 1); `smoke-mail.php` видит 2 шаблона писем (ожидание `== 2` вместо `== 4` правится в этом шаге); обход `crawl.js` — без неудачных запросов.

- [ ] **Step 7: Commit** — `git add -A && git commit -m "Этап 7: модуль apps удалён — новости, обратная связь, выбор раздела; stage7.sql"` (с `Co-Authored-By`).

### Task 5: Удаление галереи и вложений, вторая часть `stage7.sql`, демо

**Files:**
- Delete: `core/modules/share/gears/AttachmentManager.php`, `core/modules/share/components/AttachmentEditor.php`, `core/modules/share/config/AttachmentEditor.component.xml`, `core/modules/share/scripts/AttachmentEditor.js`, `core/modules/share/components/PageMedia.php`, `core/modules/share/templates/content/media_textblock.content.xml`, `core/modules/share/scripts/Carousel.js`, `core/modules/share/stylesheets/carousel.css`, `core/modules/share/gears/OGPrimitive.php`, `core/modules/share/templates/icons/gallery.icon.gif`; файлы `sql/demo/uploads/public/*` кроме `13662314846.png`
- Modify: `core/modules/share/components/Grid.php` (без `attachments()`, `linkExtraManagers()` и их вызовов; опись: 507–508, 745–764, 1166–1181), `core/modules/share/gears/GridConfig.php` (без состояния `attachments`; опись: 33), `core/modules/share/gears/ExtendedSaver.php` (без блока `_uploads`; опись: 77–91), `core/modules/share/gears/QAL.php` (без `getUploadsTablename`), `core/modules/share/components/PageList.php` (без `allAttachments` и вложений; опись: 113–122), `core/modules/share/config/PageList.component.xml` (без поля `attachments`), `core/modules/share/config/ChildDivisions.component.xml` (без поля `AttachedFiles`), `core/modules/share/transformers/fields.xslt` (без раздела 6 «Обработка attachments»; опись: 730–822), `core/modules/share/scripts/Form.js` (без `Form.AttachmentSelector`; опись: 170–172, 611–конец), `core/modules/share/stylesheets/toolbar.css` (без `.toolbar_attachmentEditor`), `site/modules/main/transformers/energine.xslt` (без миниатюр меню и PageMedia; опись: 217–231, 270–278), `site/modules/main/stylesheets/main.css` (без `.menu_image`, `.media_box`, `.gallery*`), `core/modules/share/gears/Registry.php` (без `getOGObject`), `core/modules/share/gears/Document.php` (без блока OG; опись: 283–290), `core/modules/share/transformers/document.xslt` (режим `og` — только `og:url`), `sql/cut/stage7.sql`, `sql/demo.sql` и `sql/demo/uploads`, `tests/tools/{regen-sql.sh,install-check.sh}`, `tests/no-traces.sh` (категория `gallery`), `tests/smoke-final.sh` и `tests/audit/grids-db.php` (файл `13662314846.png` остаётся)

**Interfaces:**
- Consumes: `stage7.sql` задачи 4.
- Produces: 21 таблица; демо без новостей, контактов, галереи и подстраниц «Возможностей» про новости и медиа.

- [ ] **Step 1: Категория `gallery` и проверки перехода (падающие)**

```bash
CODE[gallery]='AttachmentManager|AttachmentEditor|AttachmentSelector|attachmentEditor|PageMedia|media_textblock|Carousel|carousel\.css|share_sitemap_uploads|getUploadsTablename|linkExtraManagers|allAttachments|AttachedFiles|OGPrimitive|getOGObject|\.gallery|media_box|menu_image'
FILES[gallery]='core/modules/share/gears/AttachmentManager.php core/modules/share/components/AttachmentEditor.php core/modules/share/components/PageMedia.php core/modules/share/scripts/Carousel.js core/modules/share/gears/OGPrimitive.php'
```
По базе — таблицы `share_sitemap_uploads` нет, разделов на `media_textblock.content.xml` нет. В `migration-check.sh` блок этапа 7 дополняется: раздел на `media_textblock.content.xml` после `stage7.sql` — на `textblock.content.xml` и назван в выводе; таблицы `share_sitemap_uploads` нет.

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh all gallery; bash tests/tools/stand.sh run bash tests/tools/migration-check.sh`
Expected: оба — выход 1.

- [ ] **Step 2: `stage7.sql` — часть «галерея»**

Перед `DROP TABLE` в `sql/cut/stage7.sql`:
```sql
-- галерея и вложения разделов
SELECT CONCAT('этап 7: раздел ', smap_id, ' (', smap_segment, ') переведён на textblock.content.xml') AS `переход`
  FROM share_sitemap WHERE smap_content = 'media_textblock.content.xml';
UPDATE share_sitemap SET smap_content = 'textblock.content.xml' WHERE smap_content = 'media_textblock.content.xml';
```
и в `DROP TABLE IF EXISTS …` добавить `share_sitemap_uploads`; в первый `SELECT`/`UPDATE` перехода — `smap_content_xml LIKE '%PageMedia%'`. Константы переводов галереи и вложений — тем же способом, что в задаче 4, шаг 3, с выражением `GALLERY|ATTACH|MEDIA_TEXTBLOCK|IMG_FILENAME_IMG`.

- [ ] **Step 3: Удалить код** — `git rm` файлов из Delete; правки из Modify; затем
```bash
git grep -n -E "Attachment|attachments|_uploads\b|PageMedia|Carousel|OGPrimitive|getOGObject|gallery|media_box|menu_image" -- core site setup
```
Expected: пусто, кроме `share_uploads` (файловый репозиторий — ядро) и `uploads`-путей.

- [ ] **Step 4: Демо**

`sql/demo.sql`: удалить разделы `news` (3594), `contacts` (3626), `media` (3708), подстраницы «Возможностей» `news` (3711) и `media` (3718) — со строками `share_sitemap_translation`, `share_access_level`, `share_textblocks` и `share_textblocks_translation` этих разделов; строки `share_uploads` демо, кроме записи файла `13662314846.png`; тексты главной и «Возможностей» (`share_textblocks_translation`), где упоминаются новости, галерея и обратная связь, — без этих упоминаний. Файлы `sql/demo/uploads/public/*`, кроме `13662314846.png`, — `git rm`. Затем:
```bash
REGEN_NO_MIGRATION=1 bash tests/tools/stand.sh run bash tests/tools/regen-sql.sh; echo "exit $?"
```
Expected: exit 0, файлы выходят те же (генератор сверяет правку демо).

- [ ] **Step 5: Проверка** — как в задаче 4, шаг 6, плюс `no-traces all gallery` и `audit/theme.js`, `audit/grids.js`; `install-check.sh` — таблиц 21.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "Этап 7: галерея и вложения разделов удалены, OG без картинок вложений, демо — ядро"` (с `Co-Authored-By`).

### Task 6: Мёртвый код внутри файлов

**Files:**
- Modify: `core/modules/share/components/Grid.php` (без `moveTo_old`, `exportCSV`, `prepareCSVString`), `core/modules/share/components/DataSet.php` (без `downloadFile`), `core/modules/share/gears/Utils.php` (без `array_push_after`/`arrayPushAfter`, `dump_log`/`dumpLog`, `ddump_log`/`ddumpLog`, `simple_log`/`simpleLog`, `simplify`, `splitDate`, `strftimeFormat`, `strReplaceOpt`), `core/modules/share/gears/QAL.php` (без `funcExists`, `procExists`, `getTables`, `getLastError`), `core/modules/share/gears/Response.php` (без сжатия `site.compress`), `core/modules/share/gears/XSLTTransformer.php` (без ветки `xslcache`), `core/modules/share/transformers/fields.xslt` (без шаблонов типов color, money, float, image только для чтения, `copy_site_structure`), `tests/no-traces.sh` (выражение категории `dead` дополняется именами удалённых методов)

- [ ] **Step 1: Падающая проверка** — в `CODE[dead]` добавить `|moveTo_old|exportCSV|prepareCSVString|downloadFile|arrayPushAfter|array_push_after|dumpLog|dump_log|ddumpLog|simpleLog|simple_log|strftimeFormat|strReplaceOpt|splitDate|funcExists|procExists|getLastError|site\.compress|xslcache|copy_site_structure`. Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh code dead` — Expected: выход 1.

- [ ] **Step 2: Проверка вызовов перед удалением**

```bash
for m in moveTo_old exportCSV prepareCSVString downloadFile arrayPushAfter array_push_after dumpLog dump_log ddumpLog ddump_log simpleLog simple_log simplify splitDate strftimeFormat strReplaceOpt funcExists procExists getTables getLastError; do
  printf '%-20s %s\n' "$m" "$(git grep -n -w "$m" -- core site setup htdocs | grep -v -E "function $m\b" | wc -l)"; done
```
Expected: 0 у каждого; ненулевое — метод остаётся (журнал).

- [ ] **Step 3: Удалить методы и ветки** из списка Files; шаблоны `fields.xslt` — только для типов, которых нет в `FieldDescription::FIELD_TYPE_*`, порождаемых ядром (проверка: `git grep -n "FIELD_TYPE_COLOR\|FIELD_TYPE_MONEY\|FIELD_TYPE_FLOAT" -- core` — только объявления констант, `Saver` и `Filter`).

- [ ] **Step 4: Проверка** — `php -l`, `no-traces code dead` — 0, регрессия и `crawl.js` — как в замере.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Этап 7: мёртвые методы ядра — CSV-экспорт, старый перенос, функции Utils и QAL, сжатие и xslcache"` (с `Co-Authored-By`).

### Task 7: CodeMirror и календарь — обычные поля

**Files:**
- Delete: `core/modules/share/scripts/codemirror/`, `core/modules/share/scripts/datepicker.js`, `core/modules/share/stylesheets/datepicker.css` и картинки календаря без ссылок
- Modify: `core/modules/share/transformers/form.xslt` (поле `code` — `<textarea class="code">` без подключения CodeMirror; опись: 38–47), `core/modules/share/transformers/text.xslt` и `divisionEditor.xslt` (без подключения CodeMirror), `core/modules/share/scripts/Form.js` (без инициализации CodeMirror; опись: 139), `core/modules/share/transformers/fields.xslt` (поля `date` и `datetime` — `<input type="date">` и `<input type="datetime-local">`; опись: 351–395), `core/modules/share/scripts/Filters.js` (фильтр даты — встроенное поле; опись: 380), `core/modules/share/scripts/Energine.js` (без `createDatePicker*`), `core/modules/share/scripts/ValidForm.js` (без загрузки `datepicker`), сохранение дат на сервере (`Saver`/`FieldDescription`), если формат значения поля браузера (`YYYY-MM-DD`, `YYYY-MM-DDTHH:MM`) не принимается; `core/modules/share/stylesheets/form.css` (моноширинный `textarea.code`), `tests/smoke-profile.php` (дата рождения из формы), `tests/audit/grids.js` (фильтр журнала по дате), `tests/no-traces.sh` (категория `editors`)

- [ ] **Step 1: Падающие проверки**

`tests/no-traces.sh`:
```bash
CODE[editors]='CodeMirror|codemirror|[Dd]atepicker|DatePicker|createDatePicker'
FILES[editors]='core/modules/share/scripts/codemirror core/modules/share/scripts/datepicker.js core/modules/share/stylesheets/datepicker.css'
```
(и `--exclude-dir=codemirror` из `EXCLUDE` убрать). `tests/smoke-profile.php` — сохранение профиля с `user_users[u_bdate]=1990-02-03` (значение встроенного поля даты) и проверка `u_bdate` в базе. `tests/audit/grids.js` — в журнале действий фильтр по дате через встроенное поле: строк с датой в выбранный день больше 0.

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh code editors; bash tests/tools/stand.sh run php8.5 tests/smoke-profile.php`
Expected: no-traces — выход 1; профиль — FAIL на дате, если сервер не принимает формат встроенного поля, иначе PASS (тогда проверка закрепляет поведение; журнал).

- [ ] **Step 2: Заменить поля и удалить библиотеки** — по списку Files; `setup linker && setup scriptMap` выполняет установка стенда при перезапуске.

- [ ] **Step 3: Проверка** — `no-traces code editors` — 0; регрессия; `editors.js` (поле шаблона письма — `textarea`, сохранение без изменений), `grids.js` (фильтр по дате), `crawl.js` — без неудачных запросов.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "Этап 7: поля кода — textarea, даты — встроенные поля браузера; CodeMirror и datepicker удалены"` (с `Co-Authored-By`).

### Task 8: Документы и итоговая проверка на стенде

**Files:**
- Modify: `README.md` (ядро вместо сайта-визитки; что вырезано на этапе 7), `docs/INSTALL.md` (без `cli/`, демо — ядро), `docs/superpowers/specs/2026-09-26-energine-simple-design.md` (ссылка на спецификацию этапа 7 в разделах «Что входит» и «Этапы»), `tests/README.md` (порядок регрессии без обратной связи; 21 таблица; стенд), `tests/no-traces.sh` (категории этапа 7 в списке по умолчанию)

- [ ] **Step 1: Документы** — правки по списку; в текстах нет ссылок на new.energine.org и учётных данных.

- [ ] **Step 2: Полная проверка на чистом стенде**

```bash
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/no-traces.sh all; echo "no-traces $?"
bash tests/tools/stand.sh run bash tests/tools/install-check.sh; echo "install $?"
bash tests/tools/stand.sh run bash tests/tools/migration-check.sh; echo "migration $?"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/final-regression.log" 2>&1; grep -E '^(FAIL|== )' "$L/final-regression.log" | sort | uniq -c
bash tests/tools/stand.sh run php8.5 tests/raw-constants.php; echo "raw-constants $?"
cd tests/audit
bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node crawl.js crawl-guest.txt crawl-admin.txt crawl-singles.txt "'"$L"'/final-crawl.json"'; echo "crawl $?"
for t in editors grids theme; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/final-$t.log" 2>&1; echo "$t $?"; done
cd ../..
```
Expected: все — 0, регрессия — как в замере задачи 1 без новых провалов.

- [ ] **Step 3: Размер результата** — `git diff --stat 563115cd -- core site setup | tail -1`, число строк кода (`php`, `js`, `xslt`, `xml`, `css`) и таблиц — в отчёт этапа.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "Этап 7: документы и итоговая проверка"` (с `Co-Authored-By`).

### Task 9: Выкладка на simple.energine.org

Требует отдельного «да» владельца и разрешений на команды ниже (они читают и меняют базу и файлы площадки).

- [ ] **Step 1: Резервная копия** — база площадки (`mariadb-dump`), `web/uploads` и коммит живого дерева — в `private/backup/stage7-<дата>/`.
- [ ] **Step 2: Код** — в живом дереве: `git fetch <клон> main && git merge --ff-only FETCH_HEAD`; `vendor/` — из клона (`rsync -a --delete`); владелец — web97.
- [ ] **Step 3: База** — `sql/cut/stage7.sql` на базе площадки; затем демо-разделы удалённых частей (3594, 3626, 3708, 3711, 3718) и демо-строки `share_uploads` — как в `demo.sql` (сверка — `fresh-check.sh`).
- [ ] **Step 4: Статика** — в `web/` площадки от web97: `php8.5 index.php setup linker` и `setup scriptMap`.
- [ ] **Step 5: Проверка на площадке** — `bash tests/regression.sh`, аудиты, `bash tests/tools/fresh-check.sh` (совпадение с новой установкой с демо).
- [ ] **Step 6: Откат при провале** — `git reset --hard <прежний HEAD>` в живом дереве, база — из копии шага 1, `setup linker && setup scriptMap`.
