# Energine Simple — установка

Состояние: **этап 5а**. Вырезаны модули shop, blog, comments, calendar, forms, ads и рассылки
модуля mail; отправка писем и шаблоны писем живут в ядре. Из модуля apps остались новости
и обратная связь. Из share ушли теги, виджеты и редактор блоков, нелокальные хранилища
файлов, водяные знаки, видео и Flash, выбор из справочника (Lookup, select2); меню сайта
строится по флагу страницы «Показывать в меню». Визуальный редактор — Jodit (в формах и
при правке на странице), файлы загружаются через `fetch`; CKEditor и FileAPI удалены.
Формы защищены токеном против подделки запросов, вход — лимитом попыток, пароль
восстанавливается по одноразовой ссылке (см. README). Остаются модули share, user, apps и seo.
Что и в каком порядке вырезается дальше, описано в спецификации:
`docs/superpowers/specs/2026-09-26-energine-simple-design.md`.

Площадка: `simple.energine.org` (ISPConfig, `web97`), база `c1senergine`.

## Раскладка на ISPConfig

Document root ISPConfig фиксирован (`web/`), а `open_basedir` пускает PHP только в `web/`,
`private/` и `tmp/`. Поэтому код лежит в `private/`, а в `web/` — только точка входа.

| Путь (от `/var/www/clients/client1/webNN`) | Что это |
|---|---|
| `web/index.php`, `bootstrap.php`, `auth.php`, `resizer/` | точка входа, копии из `htdocs/` репозитория; после обновления кода копируются заново |
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
5. **База.** Восемь файлов установки полной системы, затем переходные скрипты этапов
   по порядку номеров: `sql/cut/stage1.sql` — вырезанные модули, `sql/cut/stage2.sql` —
   вырезанные части apps, `sql/cut/stage3.sql` — вырезанное из share и флаг меню,
   `sql/cut/stage4.sql` — переводы старой панели редактора и сообщения правки на странице и
   загрузки файлов, `sql/cut/stage5.sql` — безопасность: таблица попыток входа, ссылка
   восстановления пароля и письмо с ней, сообщения об отказах. Каждый
   скрипт рассчитан на базу предыдущего этапа, поэтому они идут строго по порядку. Пароль
   берётся из конфига и в вывод не попадает:
   ```sh
   cd $R/sql
   export MYSQL_PWD="$(php8.5 -r 'define("ROOT_DIR", $argv[1]); echo (include ROOT_DIR."/configs/system.config.simple.energine.org.php")["database"]["password"];' "$R")"
   for f in starter.structure.sql starter.routines.sql starter.data.demo.sql starter.structure.fixes.sql \
            starter.data.demo.fixes.sql modules.structure.sql modules.data.sql demo.content.sql \
            $(ls cut/stage*.sql | sort -V); do
     mysql --default-character-set=utf8 -u c1newenergine c1senergine < $f || break
   done
   unset MYSQL_PWD
   ```
   Получается 31 таблица и 34 страницы, 8 новостей. Сведение установки в один файл — этап 5.
   Изображения демо-контента в SQL не входят: их архив лежит на new.energine.org,
   `private/project/backup/uploads-demo-*.tar.gz`, распаковывается в `web/`. После
   распаковки удаляются файлы, которые больше ни к чему не привязаны, — списки
   `sql/cut/stageN.files`:
   ```sh
   cd $H/web && for l in $(ls $R/sql/cut/stage*.files | sort -V); do xargs -a $l rm -f; done
   ```
   Шаги 5–8 целиком, с удалением прежней базы, повторяет `tests/tools/rebuild.sh`
   (см. `tests/README.md`). Сверить установку с нуля с базой площадки, не трогая её,
   можно `tests/tools/fresh-check.sh`: он ставит базу во временный экземпляр MariaDB.
6. **Администратор — до того, как сайт откроется.** Демо-данные создают
   `demo@energine.org` с паролем `demo`, а этот пароль опубликован на new.energine.org.
   Под этим паролем открыта вся админка, в том числе правка XML страниц и файловый
   репозиторий. Поэтому пароль меняется сразу после загрузки базы, до `setup install`.
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

## Почта

По умолчанию письма сайта уходят через `mail()` — sendmail сервера. Чтобы отправлять их через
SMTP-сервер, в конфиг площадки добавляется блок `mail.smtp` (пример — в
`configs/system.config.default.php`):
- `host`, `port`;
- `encryption`: `tls` — STARTTLS (порт 587 или 25; если сервер его не предлагает, письмо не
  уходит), `ssl` — TLS сразу (порт 465), пусто — без шифрования;
- `username`, `password` — вход AUTH PLAIN или LOGIN; без шифрования пароль идёт открытым
  текстом, это годится только для локального сервера;
- `cafile` — свой центр сертификации, если сертификат сервера выпущен не общедоступным;
- `timeout`.

Сертификат сервера проверяется по имени хоста. Если письмо не ушло, причина пишется в журнал
ошибок PHP. Клиент свой (`core/modules/share/gears/SmtpTransport.php`), сторонних библиотек нет.

## Проверка

```sh
bash $R/tests/setup-linker.sh      # linker не трогает модули в core/modules
bash $R/tests/no-traces.sh         # в коде и базе нет следов вырезанного на этапах 1–4
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
  пункт «Own Error-Documents». Поэтому отказ по токену формы отвечает кодом 422, а не 403:
  страницу 403 nginx подменил бы своей, и посетитель не узнал бы, что форму нужно
  отправить ещё раз.
- **Администратор.** Пароль администратора не `demo` (см. шаг 6).
