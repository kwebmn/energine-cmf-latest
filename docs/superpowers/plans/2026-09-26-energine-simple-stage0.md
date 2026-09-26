# Energine Simple — этап 0: репозиторий и исходная установка. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** На `simple.energine.org` работает текущая полная система Energine, собранная из единого
репозитория форка, и все тесты проходят на этой площадке. Это точка отсчёта для вырезания.

**Architecture:** Репозиторий `web97/private/energine` клонируется из ядра на `web93`
(ветка `new.energine.org` → `main`). В его корень переезжает проект с `web93`: сайт, setup, sql,
cli, htdocs, тесты. Ядро и проект живут в одном дереве, симлинки модулей не нужны.
Площадка повторяет раскладку `web93`: `web/` — точка входа, конфиг площадки вне git,
база `c1senergine` из тех же восьми SQL-файлов. Тесты перестают знать про конкретную площадку:
адрес, база и пути берутся из конфига, учётные данные — из `tests/local.php` вне git.

**Tech Stack:** PHP 8.5 (FPM-пул `web97`), MariaDB 10.11, nginx/ISPConfig, git, composer,
bash, Playwright + Chrome для обхода браузером.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — раздел 4
«Репозиторий и раскладка на сервере», раздел 8 «Проверка», раздел 9, этап 0.

## Global Constraints

- Конфиги веб-сервера (nginx, PHP-FPM, ISPConfig) не менять.
- Всё в `/var/www/clients/client1/web97` принадлежит `web97:client1`: git от root, после него `chown -R web97:client1`.
- Команды приложения (`setup`, composer, cli) выполняются от `web97`: `runuser -u web97 -- …`.
- PHP — `php8.5`.
- Пароли базы и администратора не попадают ни в git, ни в вывод команд. Они хранятся только в `configs/system.config.simple.energine.org.php` и `tests/local.php` (оба вне git, режим 600).
- Тестовые письма наружу не уходят: на время прогона получатели переключаются на локальный ящик `web97@loki.kweb.biz`.
- `web93` (new.energine.org) только читается, ничего там не меняется.
- База `c1senergine`, пользователь `c1newenergine`.

## Review Focus

1. **`setup linker` на общей раскладке** может удалить или подменить настоящие каталоги модулей в `core/modules`. Ожидание: модули остаются на месте, в `web/` появляются ссылки. Тест — задача 3.
2. **Пароль из локального конфига попадает в коммит.** На `web93` тесты хранили его прямо в коде. Ожидание: коммит с паролем отклоняется. Тесты — задача 1 (ручная проверка перед первым коммитом) и задача 4 (хук на временном клоне).
3. **Тесты бьют не в ту площадку**, потому что где-то остался адрес или путь `web93`. Ожидание: прогон на `web97` не меняет базу `web93`. Тест — задача 4, число записей журнала действий `web93` до и после прогона.
4. **Тестовое письмо уходит наружу.** Ожидание: все `To:` в локальном ящике, получатели после прогона восстановлены. Тест — задача 4.
5. **Свежий клон без конфигов** (другая машина, другой разработчик). Ожидание: `tests/env.php` падает с понятным сообщением, хук коммита не мешает работать. Тест — задача 4.

---

### Task 1: Репозиторий форка с проектом в корне

**Files:**
- Create: `web97/private/energine/` — клон ядра, ветка `main`
- Move (`git mv`, чтобы сохранить историю): `starter/{site,sql,cli,htdocs,configs,jambalaya,image-cache}` → корень, `starter/composer.json` → `composer.json`
- Overwrite: содержимое этих каталогов — версиями из `web93/private/project` и `web93/web`
- Create: `setup/` (из `web93/private/project/setup`), `.githooks/secret-scan.php`, `.githooks/pre-commit`, `docs/` (спецификация, этот план, `docs/new.energine.org/{INSTALL,DEMO}.md`)
- Modify: `.gitignore`, `htdocs/bootstrap.php`, `configs/system.config.default.php`
- Delete: остаток `starter/`

**Interfaces:**
- Produces: раскладку, от которой зависят задачи 2–5. `ROOT_DIR` — корень репозитория, `CORE_REL_DIR = '../private/energine/core'`, `SITE_REL_DIR = '../private/energine/site'`, `setup_dir = ROOT_DIR . '/setup'`.
- Produces: `php8.5 .githooks/secret-scan.php [--config=ФАЙЛ]... (--staged | ПУТЬ...)`. Выход 0 — чисто, 1 — найден пароль (печатает только имена файлов), 2 — ошибка запуска.

- [ ] **Step 1: Клонировать ядро и завести ветку `main`**

```bash
cd /var/www/clients/client1/web97/private
git clone --branch new.energine.org /var/www/clients/client1/web93/private/energine energine
cd energine
git checkout -b main
git remote rename origin full
git config --global --add safe.directory /var/www/clients/client1/web97/private/energine
git log --oneline -1
```
Expected: `b156abd4 share: HTMLCap помечен устаревшим`

- [ ] **Step 2: Перенести стартер в корень и наложить версии с web93**

```bash
cd /var/www/clients/client1/web97/private/energine
P=/var/www/clients/client1/web93/private/project
W=/var/www/clients/client1/web93/web
for d in site sql cli htdocs configs jambalaya image-cache; do git mv starter/$d $d; done
git rm -q composer.json && git mv starter/composer.json composer.json
for d in site sql cli jambalaya image-cache; do rsync -a --delete $P/$d/ $d/; done
cp -a $P/setup setup
cp $P/configs/system.config.default.php configs/
cp $P/composer.json $P/composer.lock .
cp $W/index.php $W/bootstrap.php $W/auth.php htdocs/
rsync -a --delete $W/resizer/ htdocs/resizer/
git rm -rq starter
ls
```
Expected: в корне `cli composer.json composer.lock configs core htdocs image-cache jambalaya LICENSE README.md setup site sql`, каталога `starter` нет. Конфиг площадки с паролем (`system.config.new.energine.org.php`) не копировался.

- [ ] **Step 3: Пути под общую раскладку**

`htdocs/bootstrap.php` — три строки:
```php
define('ROOT_DIR', realpath(HTDOCS_DIR.'/../private/energine'));
define('CORE_REL_DIR', '../private/energine/core');
define('SITE_REL_DIR', '../private/energine/site');
```
`configs/system.config.default.php`:
```php
    // путь к директории setup; ядро лежит в том же репозитории, что и проект
    'setup_dir' => ($energine_release = ROOT_DIR) . '/setup',
```
Модули в шаблоне остаются `$energine_release . '/core/modules/…'`.

Run: `grep -rn "private/project\|PATH TO CORE" htdocs configs cli setup site`
Expected: только комментарии (например, `cli/mail_sender.php:14`), в коде — ничего.

- [ ] **Step 4: `.gitignore`**

Дописать в корневой `.gitignore`:
```gitignore
/vendor/
/configs/system.config.*.php
!/configs/system.config.default.php
/tests/local.php
/tests/**/*-cookies.txt
/tests/**/*.out
/tests/audit/crawl-*.json
```

- [ ] **Step 5: Проверка секретов — сначала тест**

`.githooks/secret-scan.php`:
```php
<?php
// Ищет пароли из локальных конфигов (база, администратор) в файлах или в индексе git.
// php8.5 .githooks/secret-scan.php [--config=ФАЙЛ]... (--staged | ПУТЬ...)
// Выход: 0 — чисто, 1 — найдено (печатаются только имена файлов), 2 — ошибка запуска.
$root = dirname(__DIR__);
$configs = [];
$paths = [];
$staged = false;
foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--config=')) $configs[] = substr($arg, 9);
    elseif ($arg === '--staged') $staged = true;
    else $paths[] = $arg;
}
if (!$configs) {
    $configs[] = getenv('ENERGINE_CONFIG') ?: dirname($root, 2) . '/web/system.config.php';
}
$secrets = [];
foreach ($configs as $file) {
    if (!is_file($file)) continue;
    if (!defined('ROOT_DIR')) define('ROOT_DIR', $root);
    $c = include $file;
    $secrets[] = $c['database']['password'] ?? '';
}
if (is_file($local = $root . '/tests/local.php')) {
    $secrets[] = (include $local)['admin_password'] ?? '';
}
$secrets = array_values(array_filter($secrets, fn($s) => strlen($s) >= 6));
if (!$secrets) {
    fwrite(STDERR, "secret-scan: локальных конфигов нет, проверять нечего\n");
    exit(0);
}
if ($staged) {
    exec('git -C ' . escapeshellarg($root) . ' diff --cached --name-only --diff-filter=ACMR', $paths, $rc);
    if ($rc) exit(2);
}
$found = 0;
foreach ($paths as $path) {
    $body = $staged
        ? shell_exec('git -C ' . escapeshellarg($root) . ' show ' . escapeshellarg(':' . $path))
        : (is_file($path) ? file_get_contents($path) : '');
    foreach ($secrets as $s) {
        if ($body !== null && str_contains((string)$body, $s)) {
            echo $path, "\n";
            $found = 1;
            break;
        }
    }
}
exit($found);
```

`.githooks/pre-commit`:
```sh
#!/bin/sh
# Не даёт закоммитить пароль базы или администратора из локальных конфигов.
root=$(git rev-parse --show-toplevel)
if ! php8.5 "$root/.githooks/secret-scan.php" --staged; then
    echo "pre-commit: в индексе пароль из локального конфига, коммит отменён" >&2
    exit 1
fi
```

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

Тест, что скан видит пароль: временный файл в scratchpad, пароль в вывод не попадает.
```bash
T=$(mktemp -d)
php8.5 -r 'define("ROOT_DIR","/var/www/clients/client1/web93/private/project"); $c=include ROOT_DIR."/configs/system.config.new.energine.org.php"; file_put_contents($argv[1]."/probe.txt", "x ".$c["database"]["password"]." y");' "$T"
php8.5 .githooks/secret-scan.php --config=/var/www/clients/client1/web93/private/project/configs/system.config.new.energine.org.php "$T/probe.txt"; echo "exit=$?"
rm -rf "$T"
```
Expected: печатается путь `…/probe.txt`, `exit=1`.

- [ ] **Step 6: Скан всего, что пойдёт в первый коммит**

```bash
git add -A
php8.5 .githooks/secret-scan.php --config=/var/www/clients/client1/web93/private/project/configs/system.config.new.energine.org.php --staged; echo "exit=$?"
```
Expected: `exit=0`, ни одного файла. Тестов в этом коммите нет: в них пароль, они переезжают в задаче 4 уже без него.

- [ ] **Step 7: Документы**

```bash
mv /var/www/clients/client1/web97/private/docs/superpowers docs/
mkdir -p docs/new.energine.org
cp $P/INSTALL-new.energine.org.md docs/new.energine.org/INSTALL.md
cp $P/DEMO-new.energine.org.md docs/new.energine.org/DEMO.md
rmdir /var/www/clients/client1/web97/private/docs
git add -A
php8.5 .githooks/secret-scan.php --config=/var/www/clients/client1/web93/private/project/configs/system.config.new.energine.org.php --staged; echo "exit=$?"
```
Expected: `exit=0`.

- [ ] **Step 8: Коммит и владелец**

```bash
git commit -q -F - <<'EOF'
Форк: проект new.energine.org в корне репозитория ядра

Стартер перенесён из starter/ в корень через git mv, поверх наложены версии
проекта с new.energine.org (сайт, setup, sql, cli, htdocs, шаблон конфига).
Ядро и проект в одном дереве: ROOT_DIR — корень репозитория, симлинки модулей
не нужны. Хук pre-commit не пускает в git пароли из локальных конфигов.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014VfkKLsoZXLNEkkw2511kd
EOF
chown -R web97:client1 /var/www/clients/client1/web97/private
git log --oneline -2
```
Expected: новый коммит поверх `b156abd4`.

---

### Task 2: Площадка simple.energine.org — файлы, конфиг, база

**Files:**
- Create: `web97/web/{index.php,bootstrap.php,auth.php,resizer/,uploads/}` (копии из `htdocs/` и архива загрузок)
- Create: `web97/web/system.config.php` → симлинк на `web97/private/energine/configs/system.config.simple.energine.org.php`
- Create: `configs/system.config.simple.energine.org.php` (вне git, 600)
- Create: `tests/local.php` (вне git, 600)

**Interfaces:**
- Consumes: раскладку из задачи 1.
- Produces: рабочий конфиг площадки и заполненную базу `c1senergine`. Администратор `demo@energine.org` со случайным паролем из `tests/local.php` (`admin_password`).

- [ ] **Step 1: Точка входа и загрузки**

```bash
R=/var/www/clients/client1/web97/private/energine
W97=/var/www/clients/client1/web97/web
cp -a $R/htdocs/index.php $R/htdocs/bootstrap.php $R/htdocs/auth.php $W97/
cp -a $R/htdocs/resizer $W97/
tar xzf /var/www/clients/client1/web93/private/project/backup/uploads-demo-20260914-164112.tar.gz -C $W97/
ln -s $R/configs/system.config.simple.energine.org.php $W97/system.config.php
```

- [ ] **Step 2: Конфиг площадки** (копия конфига web93, пароль в вывод не попадает)

```bash
cp /var/www/clients/client1/web93/private/project/configs/system.config.new.energine.org.php $R/configs/system.config.simple.energine.org.php
chmod 600 $R/configs/system.config.simple.energine.org.php
```
Правки в копии:
- `$energine_release = ROOT_DIR;` вместо `dirname(ROOT_DIR) . '/energine'`;
- `'setup_dir' => ROOT_DIR . '/setup'` без изменений;
- `'domain' => 'simple.energine.org'`;
- `'db' => 'c1senergine'` (пользователь и пароль те же).

Run (конфиг без раздела `database`):
```bash
php8.5 -r 'define("ROOT_DIR","/var/www/clients/client1/web97/private/energine"); $c=include ROOT_DIR."/configs/system.config.simple.energine.org.php"; echo $c["site"]["domain"], " ", $c["database"]["db"], " ", $c["setup_dir"], " ", $c["modules"]["share"], "\n";'
```
Expected: `simple.energine.org c1senergine /var/www/clients/client1/web97/private/energine/setup /var/www/clients/client1/web97/private/energine/core/modules/share`

- [ ] **Step 3: Зависимости**

```bash
chown -R web97:client1 /var/www/clients/client1/web97/private /var/www/clients/client1/web97/web
cd $R && runuser -u web97 -- env HOME=/var/www/clients/client1/web97/tmp COMPOSER_HOME=/var/www/clients/client1/web97/.composer php8.5 /usr/bin/composer install --no-dev
```
Expected: `vendor/autoload.php` есть, ошибок нет.

- [ ] **Step 4: База — восемь файлов в порядке `docs/new.energine.org/INSTALL.md`**

```bash
cd $R/sql
export MYSQL_PWD="$(php8.5 -r 'define("ROOT_DIR","/var/www/clients/client1/web97/private/energine"); echo (include ROOT_DIR."/configs/system.config.simple.energine.org.php")["database"]["password"];')"
for f in starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo.content.sql; do
  echo "== $f"; mysql --default-character-set=utf8 -u c1newenergine c1senergine < $f || break
done
mysql -N -u c1newenergine c1senergine -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='c1senergine'; SELECT COUNT(*) FROM share_sitemap;"
unset MYSQL_PWD
```
Expected: восемь `== …` без ошибок, `120` таблиц, `83` страницы.

- [ ] **Step 5: Пароль администратора и `tests/local.php`**

Пароль `demo` опубликован на new.energine.org, а здесь полная система с конструктором форм
и репозиторием виджетов, поэтому на этой площадке пароль случайный. Одна команда: пароль
генерируется, пишется в `tests/local.php` (600), его хэш — в базу; сам пароль не печатается.
```bash
cd $R
php8.5 -r '
define("ROOT_DIR", getcwd());
$d = (include ROOT_DIR . "/configs/system.config.simple.energine.org.php")["database"];
$pw = rtrim(strtr(base64_encode(random_bytes(18)), "+/", "-_"), "=");
$pdo = new PDO("mysql:host={$d["host"]};dbname={$d["db"]};charset=utf8", $d["username"], $d["password"]);
$st = $pdo->prepare("UPDATE user_users SET u_password = ? WHERE u_name = ?");
$st->execute([password_hash($pw, PASSWORD_DEFAULT), "demo@energine.org"]);
umask(0077);
file_put_contents("tests/local.php", "<?php\n// Учётные данные тестов этой площадки. Не в git.\nreturn [\n    \"admin_email\" => \"demo@energine.org\",\n    \"admin_password\" => " . var_export($pw, true) . ",\n    \"mailbox\" => \"web97@loki.kweb.biz\",\n];\n");
echo $st->rowCount(), "\n";'
stat -c '%a' tests/local.php
```
Expected: `1`, `600`.

---

### Task 3: `setup linker` не трогает модули, лежащие в `core/modules`; `setup install`

**Files:**
- Modify: `setup/Setup.php` — `linkerAction()`, цикл «создаём симлинки модулей»
- Test: `tests/setup-linker.sh`

**Interfaces:**
- Consumes: площадку из задачи 2.
- Produces: `web/{images,scripts,stylesheets,templates/*}` со ссылками, `web/system.jsmap.php`, записи доменов `simple.energine.org` для `http:80` и `https:443`.

- [ ] **Step 1: Тест**

`tests/setup-linker.sh`:
```bash
#!/bin/bash
# setup linker на общей раскладке: модули остаются настоящими каталогами, в web/ появляются ссылки.
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$(dirname "$(dirname "$R")")/web"
USER_="$(stat -c %U "$R")"
fail=0
out=$(cd "$WEB" && runuser -u "$USER_" -- php8.5 index.php setup linker 2>&1)
echo "$out" | grep -qiE 'warning|exception|fatal' && { echo "FAIL linker output: $(echo "$out" | grep -iE 'warning|exception|fatal' | head -3)"; fail=1; }
for m in share user apps seo; do
  [ -d "$R/core/modules/$m" ] && [ ! -L "$R/core/modules/$m" ] || { echo "FAIL core/modules/$m is not a real directory"; fail=1; }
done
[ -f "$R/core/modules/share/components/Grid.php" ] || { echo "FAIL core files missing"; fail=1; }
t=$(readlink -f "$WEB/scripts/Energine.js")
[ "$t" = "$R/core/modules/share/scripts/Energine.js" ] || { echo "FAIL web/scripts/Energine.js -> $t"; fail=1; }
[ $fail = 0 ] && echo "== setup-linker: ok"
exit $fail
```

- [ ] **Step 2: Запустить тест и увидеть падение**

Run: `bash tests/setup-linker.sh`
Expected: `FAIL linker output: … unlink(…/core/modules/share): Is a directory …`.
Каталоги модулей при этом не удаляются: `unlink()` на каталоге ничего не делает.

- [ ] **Step 3: Исправление в `linkerAction()`** — перед `if (file_exists($symlinked_dir) || is_link($symlinked_dir))`:

```php
            // ядро и проект в одном репозитории: модуль уже лежит там, куда вела бы ссылка
            if (is_dir($symlinked_dir) && !is_link($symlinked_dir)
                && realpath($symlinked_dir) === realpath($module_path)) {
                $this->text('Модуль на месте: ', $symlinked_dir);
                continue;
            }
```

- [ ] **Step 4: Тест проходит**

Run: `bash tests/setup-linker.sh`
Expected: `== setup-linker: ok`

- [ ] **Step 5: `setup install` и HTTPS-домен**

```bash
cd /var/www/clients/client1/web97/web
runuser -u web97 -- php8.5 index.php setup install
```
Затем добавить запись `https:443` и её связь с сайтом, пароль берётся из конфига:
```bash
export MYSQL_PWD="$(php8.5 -r 'define("ROOT_DIR","/var/www/clients/client1/web97/private/energine"); echo (include ROOT_DIR."/configs/system.config.simple.energine.org.php")["database"]["password"];')"
mysql -u c1newenergine c1senergine -e "INSERT IGNORE INTO share_domains (domain_protocol, domain_port, domain_host, domain_root) VALUES ('https', 443, 'simple.energine.org', '/'); INSERT IGNORE INTO share_domain2site (domain_id, site_id) SELECT domain_id, 1 FROM share_domains WHERE domain_host='simple.energine.org'; SELECT domain_id, domain_protocol, domain_port, domain_host FROM share_domains;"
unset MYSQL_PWD
```
Expected: две записи `simple.energine.org` — `http 80` и `https 443`.

- [ ] **Step 6: Сайт отвечает**

```bash
chown -R web97:client1 /var/www/clients/client1/web97/private /var/www/clients/client1/web97/web
for u in / /news/ /catalog/ /features/ /login/ /admin/; do printf "%-12s %s\n" $u "$(curl -s -o /dev/null -w '%{http_code}' https://simple.energine.org$u)"; done
```
Expected: `200` у всех адресов, кроме `/admin/` (гостю — страница входа, код `403` или `200`, как на new.energine.org).

- [ ] **Step 7: Коммит**

```bash
cd /var/www/clients/client1/web97/private/energine
git add setup/Setup.php tests/setup-linker.sh
git commit -q -F - <<'EOF'
setup: linker не трогает модули, которые уже лежат в core/modules

Когда ядро и проект в одном репозитории, путь модуля из конфига совпадает
с местом ссылки. Раньше linker пытался удалить каталог модуля и поставить
на его место ссылку на самого себя.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014VfkKLsoZXLNEkkw2511kd
EOF
chown -R web97:client1 /var/www/clients/client1/web97/private
```

---

### Task 4: Тесты, не привязанные к площадке

**Files:**
- Create: `tests/env.php`, `tests/local.php.example`
- Copy from `web93/private/project/tests`: все файлы, кроме артефактов прогонов (`*.png`, `*-cookies.txt`, `*.out`, `smoke-write.json`, `audit/crawl-final*`)
- Modify: `tests/testlib.php`, `regression.sh`, `smoke.sh`, `smoke-final.sh`, `smoke-write.sh`, `smoke-log.sh`, `smoke-editing.php`, `smoke-roundtrip.php`, `smoke-mail.php`, `smoke-forms.php`, `smoke-ads.php`, `cleanup-mail.php`, `audit/crawl.js`, `README.md`

**Interfaces:**
- Produces: `tests/env.php`. При `require` возвращает массив, `php8.5 tests/env.php --shell` печатает `export КЛЮЧ='…'`. Ключи:
  - `BASE`, `B` (то же, для bash-скриптов), `ROOT`, `WEB`, `LOG`;
  - `DB_HOST`, `DB_NAME`, `DB_USER`, `MYSQL_PWD`;
  - `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `MAILBOX`, `MAILBOX_FILE`, `SITE_USER`.
- Produces: в `testlib.php` константы `BASE`, `WEB`, `MAILBOX`, `MAILBOX_FILE`, `DB_NAME`, `SITE_USER`; функции `pdo()`, `login()`, `http()` с прежними сигнатурами.

- [ ] **Step 1: Скопировать тесты без артефактов**

```bash
R=/var/www/clients/client1/web97/private/energine
rsync -a --exclude '*.png' --exclude '*-cookies.txt' --exclude '*.out' --exclude 'smoke-write.json' --exclude 'crawl-final*' \
  /var/www/clients/client1/web93/private/project/tests/ $R/tests/
```

- [ ] **Step 2: `tests/env.php`**

```php
<?php
// Настройки тестов. Адрес, база и пути берутся из конфига площадки (web/system.config.php),
// учётные данные администратора и почтовый ящик — из tests/local.php (не в git).
// php8.5 env.php --shell печатает то же самое как export-строки для bash.
$root = dirname(__DIR__);
if (!defined('ROOT_DIR')) define('ROOT_DIR', $root);
$web = dirname($root, 2) . '/web';
$configFile = getenv('ENERGINE_CONFIG') ?: $web . '/system.config.php';
$localFile = __DIR__ . '/local.php';
foreach ([$configFile => 'конфиг площадки', $localFile => 'tests/local.php (образец — local.php.example)'] as $f => $what) {
    if (!is_file($f)) {
        fwrite(STDERR, "env.php: нет файла $f — $what\n");
        exit(2);
    }
}
$config = include $configFile;
$local = include $localFile;
$db = $config['database'];
$mailbox = $local['mailbox'];
$env = [
    'BASE' => 'https://' . $config['site']['domain'],
    'ROOT' => $root,
    'WEB' => $web,
    'LOG' => $local['log'] ?? '/var/log/ispconfig/httpd/' . $config['site']['domain'] . '/error.log',
    'DB_HOST' => $db['host'],
    'DB_NAME' => $db['db'],
    'DB_USER' => $db['username'],
    'MYSQL_PWD' => $db['password'],
    'ADMIN_EMAIL' => $local['admin_email'],
    'ADMIN_PASSWORD' => $local['admin_password'],
    'MAILBOX' => $mailbox,
    'MAILBOX_FILE' => '/var/mail/' . strstr($mailbox, '@', true),
    'SITE_USER' => posix_getpwuid(fileowner($root))['name'],
];
$env['B'] = $env['BASE'];
if (PHP_SAPI === 'cli' && realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (in_array('--shell', $argv, true)) {
        foreach ($env as $k => $v) echo 'export ', $k, '=', escapeshellarg((string)$v), "\n";
    }
    exit(0);
}
return $env;
```

`tests/local.php.example`:
```php
<?php
// Скопировать в local.php (в git не попадает) и заполнить.
return [
    'admin_email' => 'demo@energine.org',
    'admin_password' => '',
    // локальный ящик сервера: тестовые письма не должны уходить наружу
    'mailbox' => 'web97@loki.kweb.biz',
];
```

- [ ] **Step 3: Тест `env.php`**

```bash
cd $R/tests
php8.5 env.php --shell | sed -E "s/^(export (MYSQL_PWD|ADMIN_PASSWORD))=.*/\1=***/"
ENERGINE_CONFIG=/nonexistent php8.5 env.php --shell; echo "exit=$?"
```
Expected: первая команда печатает `BASE='https://simple.energine.org'`, `DB_NAME='c1senergine'`, `MAILBOX_FILE='/var/mail/web97'`, `SITE_USER='web97'`, пароли — `***`. Вторая — `env.php: нет файла /nonexistent — конфиг площадки`, `exit=2`.

- [ ] **Step 4: Перевести тесты на `env.php`**

Замены (было → стало):

| Файл | Было | Стало |
|---|---|---|
| `testlib.php` | `const BASE = 'https://new.energine.org';` | `$E = require __DIR__ . '/env.php';` и `define` для `BASE`, `WEB`, `MAILBOX`, `MAILBOX_FILE`, `DB_NAME`, `SITE_USER` |
| `testlib.php` | `new PDO('mysql:host=localhost;dbname=c1newenergine…', 'c1newenergine', '…'` | `new PDO("mysql:host={$GLOBALS['E']['DB_HOST']};dbname={$GLOBALS['E']['DB_NAME']};charset=utf8", $GLOBALS['E']['DB_USER'], $GLOBALS['E']['MYSQL_PWD']` |
| `testlib.php` | `'username' => 'demo@energine.org', 'password' => '…'` | `'username' => $GLOBALS['E']['ADMIN_EMAIL'], 'password' => $GLOBALS['E']['ADMIN_PASSWORD']` |
| `smoke-editing.php`, `smoke-roundtrip.php` | `$B = 'https://new.energine.org';`, PDO и логин с литералами, `CURLOPT_REFERER => 'https://new.energine.org/login/'` | `$E = require __DIR__ . '/env.php'; $B = $E['BASE'];`, PDO и логин из `$E`, `CURLOPT_REFERER => "$B/login/"` |
| `regression.sh`, `smoke.sh`, `smoke-final.sh`, `smoke-write.sh`, `smoke-log.sh` | `LOG=…`, `B=…`, `WEB=…`, `export MYSQL_PWD='…'` | `eval "$(php8.5 "$(dirname "${BASH_SOURCE[0]}")/env.php" --shell)" \|\| exit 1` |
| те же | `mysql … -u c1newenergine c1newenergine` | `mysql … -h "$DB_HOST" -u "$DB_USER" "$DB_NAME"` |
| те же | `'user[username]=demo@energine.org'`, `'user[password]=demo'` | `"user[username]=$ADMIN_EMAIL"`, `"user[password]=$ADMIN_PASSWORD"` |
| `smoke-write.sh:86` | `password_verify("demo", $argv[1])` | `password_verify(getenv("ADMIN_PASSWORD"), $argv[1])` |
| `smoke-write.sh` | `u_id=22` | `u_id=$ADMIN_ID`, где `ADMIN_ID=$(q "SELECT u_id FROM user_users WHERE u_name='$ADMIN_EMAIL'")` |
| `smoke-log.sh` | `s#/var/www/clients/client1/web93/private/energine/core/modules/##; s#/var/www/clients/client1/web93/##` | `s#$ROOT/core/modules/##; s#$(dirname "$(dirname "$ROOT")")/##` |
| `regression.sh` | ящик `web93@loki.kweb.biz`, `/var/mail/web93`; `/tmp/page-order-before.sql` | `$MAILBOX`, `$MAILBOX_FILE`; `ORDER=$(mktemp)` |
| `regression.sh` | восстановление получателей литералом `demo@energine.org` | исходные значения читаются до переключения и возвращаются ими же |
| `smoke-mail.php` | `MBOX`, `TEST_EMAIL`, `PROJECT`, `WEB` литералами; `c1newenergine.form_…`; `runuser -u web93` | `MAILBOX_FILE`, `MAILBOX`, `ROOT`, `WEB` из `env.php`; `DB_NAME . '.form_…'`; `runuser -u ' . SITE_USER` |
| `smoke-forms.php` | `'web93@loki.kweb.biz'` | `MAILBOX` |
| `smoke-ads.php` | `'/var/www/clients/client1/web93/web/templates/…'` | `WEB . '/templates/…'` |
| `cleanup-mail.php` | `web93@loki.kweb.biz`, `/var/mail/web93`, `…/web93/web/uploads/tmp/mailout.txt` | `MAILBOX`, `MAILBOX_FILE`, `WEB . '/uploads/tmp/mailout.txt'` |
| `audit/crawl.js` | `BASE = 'https://new.energine.org/'`, пароль `'demo'`, путь к Playwright в кеше npx | `process.env.BASE + '/'`, `process.env.ADMIN_EMAIL` и `process.env.ADMIN_PASSWORD`, `require(process.env.PLAYWRIGHT \|\| '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright')` |
| `audit/crawl-*.txt` | `https://new.energine.org/…` | пути от корня (`/admin/…`), `crawl.js` приклеивает `BASE` |

Run:
```bash
grep -rnE 'web93|new\.energine\.org|c1newenergine|MYSQL_PWD=.|password\]=demo' $R/tests | grep -vE '^\S+:[0-9]+:\s*(//|#)'
```
Expected: пусто, кроме генераторов `tests/demo/*` (они пишут SQL для `demo.content.sql` и в прогон не входят).

- [ ] **Step 5: Тест хука на временном клоне**

```bash
T=$(mktemp -d)
git clone -q $R "$T/c" && cd "$T/c" && git config core.hooksPath .githooks
php8.5 -r '$d=(function(){define("ROOT_DIR","/var/www/clients/client1/web97/private/energine"); return (include ROOT_DIR."/configs/system.config.simple.energine.org.php")["database"];})(); file_put_contents("probe.txt", "x ".$d["password"]." y");'
git add probe.txt
ENERGINE_CONFIG=/var/www/clients/client1/web97/web/system.config.php git commit -qm probe; echo "exit=$?"
git reset -q probe.txt && rm -f probe.txt && echo "other" > probe.txt && git add probe.txt
ENERGINE_CONFIG=/var/www/clients/client1/web97/web/system.config.php git commit -qm probe2; echo "exit=$?"
ENERGINE_CONFIG=/nonexistent git commit -qm probe3 --allow-empty; echo "exit=$?"
cd / && rm -rf "$T"
```
Expected: `pre-commit: в индексе пароль из локального конфига, коммит отменён`, `exit=1`; потом `exit=0`; без конфига — `secret-scan: локальных конфигов нет, проверять нечего`, `exit=0`.

- [ ] **Step 6: Полный прогон на simple.energine.org, web93 не затронут**

```bash
w93() { php8.5 -r 'define("ROOT_DIR","/var/www/clients/client1/web93/private/project"); $d=(include ROOT_DIR."/configs/system.config.new.energine.org.php")["database"]; $p=new PDO("mysql:host={$d["host"]};dbname={$d["db"]}",$d["username"],$d["password"]); echo implode(" ", $p->query("SELECT (SELECT COUNT(*) FROM share_action_log), (SELECT COUNT(*) FROM user_users), (SELECT MAX(smap_id) FROM share_sitemap)")->fetch(PDO::FETCH_NUM)), "\n";'; }
W93_BEFORE=$(w93)
bash $R/tests/regression.sh 2>&1 | tee /tmp/claude-0/-var-www-clients-client1-web93-web/8b0e8b61-14e5-4dfd-881d-64d27a8541e9/scratchpad/stage0-regression.log | grep -E '^(###|==|---)|FAIL'
echo "web93: before=$W93_BEFORE after=$(w93)"
```
Expected: у каждого набора `== … failures: 0`, раздел `### PHP log since line …` пуст, получатели восстановлены, в `/var/mail/web97` только адреса `@loki.kweb.biz`. Счётчики `web93` после прогона совпадают с `W93_BEFORE`.

Если набор падает из-за данных площадки (другой id записи), тест должен искать запись по признаку, как `smoke-ads.php`, а не по номеру.

- [ ] **Step 7: Обход браузером**

```bash
cd $R/tests/audit
eval "$(php8.5 ../env.php --shell)"
node crawl.js crawl-guest.txt crawl-admin.txt crawl-singles.txt /tmp/claude-0/-var-www-clients-client1-web93-web/8b0e8b61-14e5-4dfd-881d-64d27a8541e9/scratchpad/crawl-stage0.json | tail -5
```
Expected: `243` адреса, `0` ошибок JS, `0` ответов 400+.

- [ ] **Step 8: README тестов и коммит**

В `tests/README.md`: откуда тесты берут адрес, базу и пароли (`env.php`, `local.php`); как запускать обход с `eval "$(php8.5 ../env.php --shell)"`; ящик площадки вместо `web93@loki.kweb.biz`.
```bash
cd $R
git add tests .githooks
git status --short | head -40
git commit -q -F - <<'EOF'
tests: наборы new.energine.org без привязки к площадке

Адрес, база и пути берутся из конфига площадки, учётные данные администратора
и почтовый ящик — из tests/local.php вне git (образец — local.php.example).
Пароли из кода тестов убраны. Прогон на simple.energine.org проходит без
расхождений, база new.energine.org при этом не меняется.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014VfkKLsoZXLNEkkw2511kd
EOF
chown -R web97:client1 /var/www/clients/client1/web97/private
```
Expected: хук пропускает коммит, в `git show --stat HEAD` нет `local.php`.

---

### Task 5: Документ установки форка

**Files:**
- Create: `docs/INSTALL.md`
- Modify: `README.md` — первый абзац: что это за форк и где спецификация

- [ ] **Step 1: `docs/INSTALL.md`**

Разделы:
- раскладка на ISPConfig: таблица путей `web/`, `private/energine`, конфиг площадки, `tests/local.php`;
- развёртывание: команды задач 2–3 по порядку (копирование `htdocs`, конфиг, composer, восемь SQL-файлов, пароль администратора, `setup install`, HTTPS-домен);
- проверка: `tests/regression.sh`, обход, `tests/setup-linker.sh`;
- секреты: что где лежит, как работает хук и почему его не отключать.

- [ ] **Step 2: Проверка**

Run: `php8.5 .githooks/secret-scan.php docs/INSTALL.md README.md; echo "exit=$?"`
Expected: `exit=0`

- [ ] **Step 3: Коммит**

```bash
git add docs/INSTALL.md README.md
git commit -q -F - <<'EOF'
docs: установка форка на ISPConfig (этап 0)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014VfkKLsoZXLNEkkw2511kd
EOF
chown -R web97:client1 /var/www/clients/client1/web97/private
git log --oneline main ^full/new.energine.org
```
Expected: четыре коммита этапа 0 поверх `new.energine.org`.
