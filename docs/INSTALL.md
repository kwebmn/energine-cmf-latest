# Energine Simple — установка

Состояние: **этап 5г**. Вырезаны модули shop, blog, comments, calendar, forms, ads и рассылки
модуля mail; отправка писем и шаблоны писем живут в ядре. Из модуля apps остались новости
и обратная связь. Из share ушли теги, виджеты и редактор блоков, нелокальные хранилища
файлов, водяные знаки, видео и Flash, выбор из справочника (Lookup, select2); меню сайта
строится по флагу страницы «Показывать в меню». Визуальный редактор — Jodit (в формах и
при правке на странице), файлы загружаются через `fetch`. Формы защищены токеном против
подделки запросов, вход — лимитом попыток, пароль восстанавливается по одноразовой ссылке;
почта — через `mail()` или SMTP; тема — своя, без фреймворков (см. README). Сайт ставится
одной командой установщика в пустую базу. Остаются модули share, user, apps и seo.
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
3. **Зависимости:**
   ```sh
   cd $R && runuser -u web97 -- env HOME=$H/tmp COMPOSER_HOME=$H/.composer php8.5 /usr/bin/composer install --no-dev
   chown -R web97:client1 $H/private $H/web
   ```
4. **Установка** — одна команда в пустую базу (база и её пользователь заводятся в ISPConfig):
   ```sh
   cd $H/web && runuser -u web97 -- php8.5 index.php setup install --domain=simple.energine.org \
     --db-name=c1senergine --db-user=c1newenergine --admin-email=demo@energine.org
   ```
   Установщик:
   - проверяет расширения PHP (pdo_mysql, dom, xsl, simplexml, mbstring, gd, openssl, fileinfo);
   - пишет конфиг площадки из шаблона `configs/system.config.default.php` —
     `configs/system.config.<домен>.php`, режим 600, и ссылку на него `web/system.config.php`;
     отладка в нём выключена (`site.debug` = 0: с ней посетитель видел бы пути сервера на странице
     ошибки), стенду разработки её включают вручную;
     если конфиг уже есть (например, заполнен вручную), берёт базу и домен из него, тогда
     нужен только `--admin-email`;
   - до первого изменения базы проверяет параметры, e-mail и пароли, соединение и то, что база
     пуста: в непустую базу установка не ставится;
   - ставит схему и базовые данные (`sql/structure.sql`, `sql/data.sql`): языки, служебные
     страницы и админку, группы и права, переводы, почтовые шаблоны;
   - создаёт администратора (`--admin-email`, `--admin-name`, по умолчанию `Admin`) в группе
     с полным доступом;
   - записывает адрес сайта — `http` и `https` для `--domain` (или ровно `--url=http(s)://хост[:порт]/`);
   - раскладывает статику (`setup linker`, `setup scriptMap`).

   Пароли в аргументах не принимаются — их видно в списке процессов и в истории команд. Без
   переменных окружения установщик спросит пароль базы и пароль администратора с терминала
   без эха. В сценариях — переменные `ENERGINE_DB_PASSWORD` и `ENERGINE_ADMIN_PASSWORD`
   (например, из файла с режимом 600). Ошибка — код выхода 1 и причина; если установка
   прервалась на середине, база заполнена частично: её нужно очистить и запустить установку
   снова. Параметры базы: `--db-host`, `--db-port` или `--db-socket` (сокет сервера базы, тогда
   хост и порт не нужны). `--config=ФАЙЛ` — конфиг в другом месте, `--no-static` — без статики.
5. **Демо-контент** (для `simple.energine.org`; в установку не входит):
   ```sh
   cd $H/web && runuser -u web97 -- php8.5 index.php setup demo
   ```
   Разделы и тексты, новости, галерея, обратная связь с получателями, демо-посетители
   (`sql/demo.sql`) и их файлы (`sql/demo/uploads` → `web/uploads`). Ставится только на свежую
   установку.
6. **Тесты:** `tests/local.php` (образец — `tests/local.php.example`, режим 600, вне git) —
   e-mail и пароль администратора, локальный почтовый ящик для писем тестов.

Установку заново — снять всю базу, поставить установщиком и демо, с новым случайным паролем
администратора в `tests/local.php` — делает `tests/tools/rebuild.sh --yes-drop-everything`.
Сверить установку с нуля с базой площадки, не трогая её, — `tests/tools/fresh-check.sh`,
проверить сам установщик — `tests/tools/install-check.sh` (временный экземпляр MariaDB).

### Обновление

Статика в `web/` (`images`, `scripts`, `stylesheets`, `templates`) — ссылки на файлы модулей в
репозитории, при любом режиме отладки: после `git pull` их содержимое уже новое. Если файлы статики
добавились, удалились или переименовались, а также после правки `htdocs/*.php`:
```sh
cp $R/htdocs/index.php $R/htdocs/bootstrap.php $R/htdocs/auth.php $H/web/
chown -R web97:client1 $H/private $H/web
cd $H/web && runuser -u web97 -- php8.5 index.php setup linker && runuser -u web97 -- php8.5 index.php setup scriptMap
```
Изменения базы между версиями — переходные скрипты `sql/cut/stage*.sql` (см. ниже).

### Переход базы полной системы на форк

Сайт, работающий на полной системе Energine (как `new.energine.org`), переходит на форк без
переустановки: к его базе по порядку применяются `sql/cut/stage1.sql` … `stage5.sql` — каждый
рассчитан на базу предыдущего этапа. Скрипты убирают таблицы, колонки и переводы вырезанного,
добавляют новое; тексты сайта не трогают. Страницы со своим XML в старой раскладке (меню и
вход в колонке, контейнер `mainMenuContainer`) сбрасываются на шаблон страницы — `stage5.sql`
перечисляет их в выводе клиента `mysql`, их раскладку при необходимости собрать заново в
админке. Проверка — `tests/tools/migration-check.sh`.

## Тема

Разметка сайта — `site/modules/main/transformers/energine.xslt`: шапка (название, меню, язык,
вход), содержимое, боковая колонка, подвал. Стили — один файл
`site/modules/main/stylesheets/main.css`; страница ошибки вне раскладки сайта —
`core/modules/share/transformers/error_page.xslt`. Меню, вход и переключатель языка — компоненты
раскладки (`default.layout.xml`), в шаблонах содержимого их нет. У админки (гриды, формы, режим
правки) свои стили — `energine.css` и `grid.css`, они подключаются только администратору; окна
админки (режим single) тему не подключают вовсе, а в разделах админки внутри страниц сайта
элементные стили темы (таблицы, списки, поля, кнопки) не касаются её контейнеров — `.e-pane`,
панели администратора, рамки окна.

В `web/` стили попадают ссылками (`setup linker`). nginx площадки отдаёт файл по ссылке, только
если у ссылки и файла один владелец (`disable_symlinks if_not_owner`): файл темы, записанный от
root, отдаётся с кодом 404 — после правки `chown web97:client1`.

## Почта

По умолчанию письма сайта уходят через `mail()` — sendmail сервера. Чтобы отправлять их через
SMTP-сервер, в конфиг площадки добавляется блок `mail.smtp` (пример — в
`configs/system.config.default.php`):
- `host`, `port`;
- `from` блока `mail` может быть и с именем («Сайт <noreply@example.org>»), получатели обратной
  связи — списком через запятую: в конверт SMTP идут только адреса;
- `encryption`: `tls` (или `starttls`) — STARTTLS (порт 587 или 25; если сервер его не
  предлагает, письмо не уходит), `ssl` — TLS сразу (порт 465), пусто — без шифрования; регистр
  не важен, другое значение (опечатка) — письмо не уходит, причина — в журнале ошибок PHP;
- `username`, `password` — вход AUTH PLAIN или LOGIN; без шифрования пароль идёт открытым
  текстом, это годится только для локального сервера;
- `cafile` — свой центр сертификации, если сертификат сервера выпущен не общедоступным;
- `timeout`.

Сертификат сервера проверяется по имени хоста. Если письмо не ушло, причина пишется в журнал
ошибок PHP. Клиент свой (`core/modules/share/gears/SmtpTransport.php`), сторонних библиотек нет.

## Проверка

```sh
bash $R/tests/setup-linker.sh      # linker не трогает модули в core/modules
bash $R/tests/no-traces.sh         # в коде и базе нет следов вырезанного на этапах 1–4 и старой темы
bash $R/tests/regression.sh        # все сценарные наборы и журнал ошибок PHP
bash $R/tests/tools/install-check.sh   # установщик на временном экземпляре MariaDB
bash $R/tests/tools/fresh-check.sh     # установка с нуля и демо == база площадки
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
- **Администратор.** Пароль администратора задан при установке, он не `demo`
  (для тестов — в `tests/local.php`).
