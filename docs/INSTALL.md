# Energine Simple — установка

Состояние: **этап 0**. Из репозитория форка собирается полная система Energine, как на
new.energine.org, — это точка отсчёта, от которой вырезается лишнее. Что и в каком порядке
вырезается, описано в спецификации: `docs/superpowers/specs/2026-09-26-energine-simple-design.md`.

Площадка: `simple.energine.org` (ISPConfig, `web97`), база `c1senergine`.

## Раскладка на ISPConfig

Document root ISPConfig фиксирован (`web/`), а `open_basedir` пускает PHP только в `web/`,
`private/` и `tmp/`. Поэтому код лежит в `private/`, а в `web/` — только точка входа.

| Путь (от `/var/www/clients/client1/webNN`) | Что это |
|---|---|
| `web/index.php`, `bootstrap.php`, `auth.php`, `resizer/` | точка входа, копии из `htdocs/` репозитория |
| `web/uploads/` | файлы площадки (в git только каркас `htdocs/uploads`) |
| `web/system.config.php` | симлинк на `private/energine/configs/system.config.<домен>.php` |
| `web/images`, `scripts`, `stylesheets`, `templates`, `system.jsmap.php` | генерирует `setup`, руками не править |
| `private/energine/` | репозиторий: ядро `core/`, сайт `site/`, `setup/`, `sql/`, `cli/`, `tests/`, `docs/` |
| `private/energine/configs/system.config.<домен>.php` | конфиг площадки с паролем базы, режим 600, вне git |
| `private/energine/tests/local.php` | учётные данные тестов, режим 600, вне git |

Ядро и проект — одно дерево: `ROOT_DIR` указывает на корень репозитория, модули лежат
в `core/modules` без симлинков. `setup linker` их не трогает (`tests/setup-linker.sh`).

Всё принадлежит `webNN:client1`: в vhost стоит `disable_symlinks if_not_owner`, nginx
отдаёт файл по симлинку, только если у ссылки и цели один владелец. Команды приложения
запускаются от владельца: `runuser -u webNN -- …`. Git — от root, после него
`chown -R webNN:client1 private web`.

Конфиги веб-сервера не трогаются. Нужна только переадресация на `index.php`
(`try_files $uri $uri/ @rewrites` → `rewrite ^ /index.php last`) — её задают в ISPConfig
в поле nginx-директив сайта.

## Развёртывание

Команды для `simple.energine.org`. Для другой площадки поменяйте `web97`, домен и базу.

```sh
H=/var/www/clients/client1/web97
R=$H/private/energine
```

1. **Репозиторий** и хук, который не пускает пароли в коммиты. Git работает от root,
   а после `chown` репозиторий принадлежит владельцу площадки, поэтому root должен ему
   доверять:
   ```sh
   git clone <адрес репозитория> $R
   git -C $R config core.hooksPath .githooks
   git config --global --add safe.directory $R
   ```
2. **Точка входа:**
   ```sh
   cp $R/htdocs/index.php $R/htdocs/bootstrap.php $R/htdocs/auth.php $H/web/
   cp -a $R/htdocs/resizer $H/web/
   cp -a $R/htdocs/uploads $H/web/
   ```
3. **Конфиг площадки** — из шаблона. Заполнить `database` и `site.domain`, режим 600:
   ```sh
   cp $R/configs/system.config.default.php $R/configs/system.config.simple.energine.org.php
   chmod 600 $R/configs/system.config.simple.energine.org.php
   ln -s $R/configs/system.config.simple.energine.org.php $H/web/system.config.php
   chown -R web97:client1 $H/private $H/web
   ```
4. **Зависимости:**
   ```sh
   cd $R && runuser -u web97 -- env HOME=$H/tmp COMPOSER_HOME=$H/.composer php8.5 /usr/bin/composer install --no-dev
   ```
5. **База.** Восемь файлов по порядку. Пароль берётся из конфига и в вывод не попадает:
   ```sh
   cd $R/sql
   export MYSQL_PWD="$(php8.5 -r 'define("ROOT_DIR", $argv[1]); echo (include ROOT_DIR."/configs/system.config.simple.energine.org.php")["database"]["password"];' "$R")"
   for f in starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql \
            starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo.content.sql; do
     mysql --default-character-set=utf8 -u c1newenergine c1senergine < $f || break
   done
   unset MYSQL_PWD
   ```
   Получается 120 таблиц и 83 страницы.
   Изображения демо-контента в SQL не входят: их архив лежит на new.energine.org,
   `private/project/backup/uploads-demo-*.tar.gz`, распаковывается в `web/`.
6. **Администратор — до того, как сайт откроется.** Демо-данные создают
   `demo@energine.org` с паролем `demo`, а этот пароль опубликован на new.energine.org.
   В демо-данных полная система: конструктор форм, репозиторий виджетов, который пишет
   файлы шаблонов. Поэтому пароль меняется сразу после загрузки базы, до `setup install`.
   Команда ставит случайный пароль, пишет его в `tests/local.php` (режим 600, вне git),
   а в базу — только хэш. Сам пароль не печатается, для входа в админку он берётся из
   этого файла:
   ```sh
   cd $R
   php8.5 -r '
   define("ROOT_DIR", getcwd());
   $d = (include ROOT_DIR . "/configs/system.config.simple.energine.org.php")["database"];
   $pw = rtrim(strtr(base64_encode(random_bytes(18)), "+/", "-_"), "=");
   $pdo = new PDO("mysql:host={$d["host"]};dbname={$d["db"]};charset=utf8", $d["username"], $d["password"]);
   $st = $pdo->prepare("UPDATE user_users SET u_password = ? WHERE u_name = ?");
   $st->execute([password_hash($pw, PASSWORD_DEFAULT), "demo@energine.org"]);
   umask(0077);
   file_put_contents("tests/local.php", "<?php\nreturn [\n    \"admin_email\" => \"demo@energine.org\",\n    \"admin_password\" => " . var_export($pw, true) . ",\n    \"mailbox\" => \"web97@loki.kweb.biz\",\n];\n");
   echo $st->rowCount(), "\n";'
   chown web97:client1 tests/local.php
   ```
   Ожидается `1`. `mailbox` — локальный ящик владельца площадки: туда тесты шлют письма.
7. **`setup install`** проверяет базу, записывает домен из конфига в `share_domains`
   (`http:80`) и раскладывает статику модулей:
   ```sh
   cd $H/web && runuser -u web97 -- php8.5 index.php setup install
   ```
8. **HTTPS-домен.** Сайт определяется по связке протокол + хост + порт, нужна и запись
   `https:443`:
   ```sql
   INSERT IGNORE INTO share_domains (domain_protocol, domain_port, domain_host, domain_root)
     VALUES ('https', 443, 'simple.energine.org', '/');
   INSERT IGNORE INTO share_domain2site (domain_id, site_id)
     SELECT domain_id, 1 FROM share_domains WHERE domain_host = 'simple.energine.org';
   ```

## Проверка

```sh
bash $R/tests/setup-linker.sh      # linker не трогает модули в core/modules
bash $R/tests/regression.sh        # все сценарные наборы и журнал ошибок PHP
```

Обход браузером и подробности по тестам — в `tests/README.md`.

## Секреты

- Пароль базы хранится только в `configs/system.config.<домен>.php`.
- Пароль администратора для тестов хранится только в `tests/local.php`.
- Оба файла вне git. Хук `.githooks/pre-commit` отклоняет коммит, в котором оказался любой
  из этих паролей: он проверяет индекс через `.githooks/secret-scan.php`.
- Хук подключается на каждом клоне отдельно: `git config core.hooksPath .githooks`.
- `git clean -fdx` и `git stash --all` в рабочем дереве площадки удалят или спрячут конфиг
  площадки и `tests/local.php`: они лежат внутри репозитория, но вне git. Не запускайте их
  в `$R`.

## Отличия simple.energine.org от new.energine.org

- **Страницы ошибок.** У simple.energine.org в ISPConfig включены собственные страницы
  ошибок: nginx подменяет ответы Energine с кодами 4xx/5xx статичными страницами из
  `web/error/`. Например, вместо страницы 404 сайта показывается `ERROR 404 - Not Found!`.
  У new.energine.org эта настройка выключена. Выключается в ISPConfig в настройках сайта,
  пункт «Own Error-Documents».
- **Администратор.** Пароль администратора не `demo` (см. шаг 6).
