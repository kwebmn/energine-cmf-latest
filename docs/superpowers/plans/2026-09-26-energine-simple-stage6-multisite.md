# Energine Simple — этап 6: мультисайт. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Одна установка — один сайт: адрес сайта берётся из конфига, в базе нет таблиц доменов и привязки групп к сайтам, дерево разделов одно, а сайт правится формой «Настройки сайта». Редактора сайтов больше нет.

**Architecture:**
- **Адрес из конфига.**
  - База адресов: схема запроса + `://` + `site.domain` + `site.root`. `site.domain` может нести нестандартный порт (`127.0.0.1:8123`).
  - Хост из заголовка `Host` адрес не меняет. Сейчас это гарантирует `share_domains`, так что поддельный `Host` не уводит абсолютные ссылки (письмо восстановления пароля, действие формы входа, редиректы). После этапа то же гарантирует конфиг.
  - Параметры cookie задаются в одном месте, `Site::cookieDomainOf()`:
    - для имени хоста — `Domain=.хост`, как сейчас;
    - для адреса с портом, IP или имени без точки (`localhost`) — без атрибута `Domain`.
  - Путь cookie — `/`.
- **Установщик** пишет в конфиг `domain` с нестандартным портом и `root` из `--url`. Записи доменов в базу нет.
- **«Настройки сайта»** — `admin/settings`, бывшая страница 1300 `admin/structure/sites`.
  - Компонент `SiteSettings` (Grid над `share_sites`) умеет только правку единственной записи:
    - название, ключевые слова и описание по языкам;
    - `site_meta_robots`;
    - вкладка «Свойства» — `SitePropertiesEditor` в iframe.
  - Кнопка панели страницы «Настройки сайта» открывает тот же компонент во всплывающем окне, как «Пользователи» и «Языки».
  - Удаляются `SiteEditor`, `SiteEditorConfig`, `SiteSaver`, `DomainEditor`, `SiteManager.js`, их конфиги, шаблон `sites.content.xml` и сброс шаблонов всего сайта. Сброс существовал только в редакторе сайтов.
- **Одно дерево разделов.**
  - `Registry::getMap()` без аргумента.
  - `Sitemap` строится по всей таблице; корень — единственная строка с `smap_pid IS NULL`.
  - Из `DivisionEditor`, `PageList`, `RoleEditor`, новостей, лент, `Builder` и `Robots` уходит номер сайта. Из адресов гридов уходит `[site_id]`: `divEditor/get-data/` вместо `divEditor/1/get-data/`.
  - `SiteList` и выбор сайта в дереве удаляются. Имена конфигов и шаблонов (`SiteDivisionEditor`, `site_div_editor`) остаются: они значат «редактор разделов сайта».
- **Права без сайтов.** `share_groups2sites` удаляется вместе с фильтром новостей по сайтам групп. Права на страницы и раньше от сайта не зависели.
- **Один сайт в ядре.**
  - У `SiteManager` остаётся `getCurrentSite()`. Уходят `getSiteByID`, `getSiteByPage`, `getDefaultSite` и перебор сайтов.
  - `Site::folder` — постоянная `main`.
- **База.** Итог — 28 таблиц. Удаляются:
  - таблицы `share_domains`, `share_domain2site`, `share_groups2sites`;
  - колонки `share_sitemap.site_id`, `share_sites.site_is_active`, `site_is_default`, `site_folder`, `site_order_num` и `share_sites_properties.site_id`.

  Уникальный ключ `share_sitemap (smap_pid, site_id, smap_segment)` становится `(smap_pid, smap_segment)`.
- **Переход базы** — `sql/cut/stage6.sql`.
  - Разделы скрипта по задачам; каждый можно запускать повторно (`IF EXISTS`, `INSERT IGNORE`).
  - Перед изменением схемы скрипт проверяет, что в базе ровно один сайт и один корень. Иначе — отказ (`SIGNAL`) с текстом, что сделать.
  - Базу площадки меняет только этот скрипт. Перед первым применением снимается дамп (режим 600, в `scratchpad`).
- **Файлы установки** (`sql/structure.sql`, `data.sql`, `demo.sql`) после каждой задачи получаются генератором `tests/tools/regen-sql.sh`, руками не правятся.
  - Генератор ставит нынешние файлы во временный экземпляр MariaDB, применяет `sql/cut/stage6.sql` и выгружает файлы заново в прежнем формате.
  - Правило этапа 5г выполняется так: изменение пишется один раз в `stage6.sql`, файлы установки из него генерируются, `fresh-check` сверяет.

**Tech Stack:** PHP 8.5, MariaDB 10.11, XSLT 1.0, MooTools (админка), bash, curl, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — раздел 6 «Мультисайт», раздел 5 (28 таблиц), раздел 8 (проверка).

## Global Constraints

Те же, что на этапах 1–5:
- конфиги веб-сервера не трогаются;
- владелец файлов `web97:client1`: git от root, после него `chown`;
- PHP — `php8.5`;
- пароли не попадают ни в git, ни в вывод, ни в аргументы команд;
- письма — только на `web97@loki.kweb.biz`;
- `web93` только читается;
- `rebuild.sh` не запускается: пароль тестового администратора меняет только пользователь;
- после правки PHP — пауза перед проверкой (opcache);
- `web/{index,bootstrap,auth}.php` — копии `htdocs/*`: после правки `htdocs` — `cp` и `chown`;
- после добавления или удаления JS и шаблонов — `setup linker` и `setup scriptMap` от имени `web97`.

Этапа 6:
- база площадки меняется только скриптом `sql/cut/stage6.sql`, перед первым применением — дамп;
- файлы установки — только генератором;
- в конце этапа по спецификации 28 таблиц.

## Review Focus

1. **Чужой `Host` и порт.** При запросе с поддельным `Host`, по IP или с портом адрес в ссылках, `<base>`, действии формы входа, письме восстановления пароля и редиректах остаётся адресом из конфига. Вход и CSRF работают на `host:port` и на http, и на https.
2. **Переход базы существующего сайта.**
   - При двух сайтах или двух корнях — отказ до любого изменения.
   - Повторный запуск ничего не меняет.
   - Страницы, их адреса, тексты, права, новости и файлы после перехода те же.
3. **Сегменты страниц.** Страница с сегментом, который уже есть у соседа, получает понятный отказ, а не ошибку SQL и 500. Переименование и перенос страниц работают.
4. **Права.** Группа с правом правки раздела новостей (не администраторы) видит все новости в редакторе. Форма группы сохраняет права без строк «сайт». Гость и посетитель видят то же, что до этапа.
5. **«Настройки сайта».**
   - Сохранённые название и мета-описание видны посетителю: заголовок, мета-теги страниц без своих.
   - `NOINDEX` сайта попадает в `robots.txt` и `google-sitemap`.
   - Сохранение без токена отклоняется.
   - Добавить или удалить сайт нельзя.

Тесты по пунктам:
- 1 — `install-check.sh` (задача 1);
- 2 — `migration-check.sh` (задача 5);
- 3 — `smoke-write.sh` (задача 3);
- 4 — `smoke-rights.php` (задача 4);
- 5 — `site-settings.php` (задача 2).

---

### Task 1: Адрес сайта из конфига

**Files:**
- Modify: `core/modules/share/gears/{Site,SiteManager,UserSession,Response,Document,Mail}.php`, `core/modules/share/components/FileRepository.php`, `core/modules/user/components/LoginForm.php`, `core/modules/share/transformers/energine.xslt`, `setup/Setup.php`, `tests/tools/{install-check,rebuild}.sh`, `tests/regression.sh`
- Delete: `core/modules/share/components/CrossDomainAuth.php`
- Create: `tests/site-address.php`, `tests/tools/regen-sql.sh`

**Interfaces:**
- Produces:
  - `Site::hostOf(string $domain): string`: `'a.org:8080'` → `'a.org'`;
  - `Site::cookieDomainOf(string $domain): string`: `'a.org'` → `'.a.org'`; для порта, IP и имени без точки — `''`;
  - `Site::normalizeRoot(?string $root): string`: `''`, `'/'` → `'/'`; `'sub'`, `'/sub'` → `'/sub/'`;
  - у текущего сайта свойства `base`, `root`, `host`, `cookieDomain`;
  - `tests/tools/regen-sql.sh` — выход 0 и файлы установки на месте.

- [ ] **Красный `install-check.sh`:**
  - установка с `--url=http://127.0.0.1:$PORT/` пишет в конфиг `'domain' => '127.0.0.1:$PORT'` и `'root' => '/'`;
  - `share_domains` после установки пуст;
  - страницы встроенного сервера — с `<base href="http://127.0.0.1:$PORT/">`;
  - с заголовком `Host: evil.example` в `<base>` и действии формы входа — адрес из конфига;
  - `Set-Cookie` cookie токена и сессии — без `Domain=`;
  - вход администратора через `auth.php` проходит.
- [ ] **Красный `tests/site-address.php`**, по образцу `session-id.php` (`vendor/autoload.php`, `check()`):
  - случаи трёх функций из Interfaces;
  - `IPv4`: `'10.0.0.1'` → `''`;
  - регистр хоста сохраняется.

  В `regression.sh` — строка `### site-address`, наборов 14.
- [ ] Прогон. Ожидается FAIL: в конфиге только хост, в `share_domains` строка, функций нет.
- [ ] **`Site`:**
  - три статические функции;
  - `setAddress(string $scheme, string $domain, string $root)` вместо `setDomain`: пишет `base`, `root`, `host`, `cookieDomain`.
- [ ] **`SiteManager::__construct`:**
  - сайты — `Site::load()`; текущий — `site_is_default` (до задачи 5);
  - адрес всем сайтам — из `URI::create()->getScheme()`, `site.domain`, `site.root`;
  - нет `site.domain` — `SystemException('ERR_NO_SITE', ERR_DEVELOPER)`;
  - запрос к `share_domains` и `site.dev_domains` уходят.
- [ ] **Cookie:**
  - `UserSession::launch` — путь `/`, домен `cookieDomain` текущего сайта;
  - `Response::addCookie` без домена — то же. Ветка с несуществующим `->domain` уходит;
  - `FileRepository` — `addCookie(self::STORED_PID, $uplPID)` с параметрами по умолчанию.
- [ ] **Остальные потребители адреса:**
  - `Mail` — Message-ID с `Site::hostOf(site.domain)`;
  - `LoginForm` — действие формы от `base`, без междоменной ветки;
  - `Document` — без `CrossDomainAuth`;
  - `energine.xslt` — без шаблона `cdAuth`;
  - `CrossDomainAuth.php` удаляется.
- [ ] **`Setup`:**
  - `writeConfig` пишет `domain` (порт — только нестандартный для схемы) и `root` из `--url`;
  - `siteUrls` сводится к разбору `--url` / `--domain`;
  - `writeDomains` и мёртвый код уходят: `getSiteHost`, `getSiteRoot` и закомментированный блок, `createSitemapSegment`;
  - готовый конфиг и `--domain` с другим адресом (хост и порт) — отказ, как сейчас;
  - итоговое сообщение — без доменов.
- [ ] `rebuild.sh` — без `share_domains`.
- [ ] **Генератор `tests/tools/regen-sql.sh`** — по образцу генератора 5г (`scratchpad/stage-tools/make-install-sql-5d.sh`):
  - вход — `sql/structure.sql`, `data.sql`, `demo.sql` во временном экземпляре, затем `sql/cut/stage6.sql`, если он есть;
  - выход — три файла в прежнем формате. Число таблиц в заголовке `structure.sql` считается, а не пишется руками;
  - учёт строк: каждая непустая таблица выгружена в `data.sql` или `demo.sql`, иначе отказ;
  - `sql/demo/uploads` не трогает.
- [ ] Проверка генератора: без `stage6.sql` три файла выходят байт в байт (`git diff --exit-code sql/`).
- [ ] **Зелёный:**
  - `install-check.sh`, `site-address.php`, `check-regression.sh 14`;
  - обход, `editors.js`, `grids.js`, `theme.js`;
  - `fresh-check.sh`, `migration-check.sh`, `no-traces.sh`.

  Ожидается 0 провалов. Коммит.

### Task 2: «Настройки сайта» вместо редактора сайтов

**Files:**
- Create:
  - `core/modules/share/components/SiteSettings.php`, `core/modules/share/config/SiteSettings.component.xml`;
  - `site/modules/main/templates/content/site_settings.content.xml`;
  - `sql/cut/stage6.sql` (раздел 1);
  - `tests/site-settings.php`.
- Modify:
  - `core/modules/share/components/{DivisionEditor,SitePropertiesEditor}.php`, `core/modules/share/config/DivisionEditor.component.xml`;
  - `core/modules/share/scripts/PageToolbar.js`, `core/modules/share/transformers/divisionEditor.xslt`;
  - `tests/{smoke.sh,smoke-final.sh,smoke-roundtrip.php,paths-all.txt,regression.sh}`, `tests/audit/{crawl-admin.txt,crawl-singles.txt,grids.js}`.
- Delete:
  - `core/modules/share/components/{SiteEditor,DomainEditor}.php`, `core/modules/share/components/SiteEditorConfig.php`, `core/modules/share/gears/SiteSaver.php`;
  - `core/modules/share/config/{SiteEditor,SiteEditorModal,DomainEditor}.component.xml`, `core/modules/share/scripts/SiteManager.js`;
  - `site/modules/main/templates/content/sites.content.xml`.

**Interfaces:**
- Produces:
  - страница `admin/settings/`;
  - адреса компонента `settings`:
    - `single/settings/` — грид из одной записи;
    - `<id>/edit/`, `save/`;
    - `<id>/properties/` — свойства;
    - `get-data/`;
  - состояние `DivisionEditor` `showSiteSettings` (`/site-settings/[any]/`);
  - кнопка `siteSettings`: `BTN_SITE_SETTINGS`, `onclick="showSiteSettings"`.

- [ ] **Красный `tests/site-settings.php`** — администратор, токен как в `smoke-csrf.php`:
  - `admin/settings/` — 200, грид одной записи, без кнопок добавления, удаления и перемещения;
  - форма правки: название, ключевые слова и описание по языкам, `site_meta_robots`, вкладка свойств;
  - сохранение нового названия (ru) видно в заголовке главной; название возвращается;
  - `NOINDEX` сайта: в `robots.txt` — `Disallow: /`, `google-sitemap` — 404; возврат;
  - сохранение без токена — 422, запись та же;
  - `admin/structure/sites/` — 404.

  В `regression.sh` — строка `### site-settings`, наборов 15.
- [ ] Красные правки старых проверок:
  - `smoke.sh`, `smoke-final.sh`, `smoke-roundtrip.php` — форма `settings/single/settings/1/edit/` вместо `siteEditor`;
  - `paths-all.txt`, `crawl-admin.txt`, `crawl-singles.txt` — `admin/settings/`;
  - `grids.js` — кнопка «Настройки сайта» панели страницы открывает окно с гридом.

  Прогон. Ожидается FAIL: страницы нет.
- [ ] **`SiteSettings extends Grid`:**
  - правка, сохранение, `get-data`, `properties` (iframe `SitePropertiesEditor`, как вкладка доменов в `SiteEditor::prepare`);
  - поля правки: `site_id` (только чтение), `site_meta_robots`, переводы;
  - `add`, `delete`, `up`, `down` — нет ни в конфиге, ни в коде: состояния без шаблона адреса недоступны;
  - сохранение — обычный `Saver`. Если `SiteSaver` делал для `site_meta_robots` что-то нужное, это переносится.
- [ ] **Вызовы из `DivisionEditor`:**
  - `DivisionEditor` — `showSiteSettings` вместо `showSiteEditor`;
  - `PageToolbar.js` — `showSiteSettings` открывает `componentPath + 'site-settings'`;
  - шаблон окна редактора сайтов в `divisionEditor.xslt` уходит.
- [ ] **Сброс шаблонов всего сайта уходит:**
  - `DivisionEditor::resetTemplates`, если его вызывал только редактор сайтов (проверить `grep`);
  - константы `BTN_RESET_TEMPLATES`, `MSG_CONFIRM_TEMPLATES_RESET`, `MSG_TEMPLATES_RESET`, если ими больше никто не пользуется.
- [ ] **`sql/cut/stage6.sql`, раздел 1:**
  - страница с `smap_content = 'main/sites.content.xml'` → `smap_pid` — страница `admin`, сегмент `settings`, шаблон `main/site_settings.content.xml`, порядок 3;
  - названия «Настройки сайта» / «Налаштування сайту»;
  - константы `BTN_SITE_SETTINGS`, `CONTENT_SITE_SETTINGS` (ru, ua);
  - удаляются `BTN_SITE_EDITOR`, `CONTENT_SITES`, `TAB_DOMAINS`, `TXT_DOMAINEDITOR`, `FIELD_DOMAIN_ID`, `FIELD_DOMAIN_URL`, `FIELD_DOMAIN_PROTOCOL`, `FIELD_DOMAIN_PORT`, `FIELD_DOMAIN_HOST`, `FIELD_DOMAIN_ROOT`, `FIELD_SITE_PROTOCOL`, `FIELD_SITE_HOST`, `FIELD_SITE_ROOT`, `FIELD_SITE_PORT`, `FIELD_COPY_SITE_STRUCTURE`, `TXT_SITELIST`, `FIELD_SITE`, `FIELD_SITE_LOGO`, `FIELD_SITE_GA_CODE` и константы сброса (по результату `grep`).

  Добавляется `ERR_BAD_PROPERTY_NAME`: используется, но строки нет.
- [ ] Дамп базы площадки (режим 600, `scratchpad`). Раздел 1 — в базу площадки. `regen-sql.sh`. `setup linker`, `setup scriptMap`.
- [ ] **Зелёный:**
  - `site-settings.php`, `check-regression.sh 15`;
  - обход (`admin/settings/` без ошибок), `grids.js`, `editors.js`, `raw-constants.php`;
  - `fresh-check.sh`, `install-check.sh`.

  Коммит.

### Task 3: Одно дерево разделов

**Files:**
- Modify:
  - `core/modules/share/gears/{Sitemap,Registry,Builder}.php`;
  - `core/modules/share/components/{DivisionEditor,PageList}.php`, `core/modules/user/components/RoleEditor.php`;
  - `core/modules/apps/components/{NewsRepository,NewsFeed,Feed,ExtendedFeed}.php`, `core/modules/seo/components/Robots.php`;
  - `core/modules/share/config/{DivisionEditor,SiteDivisionEditor,SiteDivisionSelector}.component.xml`, `core/modules/apps/config/NewsRepository.component.xml`;
  - `site/modules/main/templates/content/site_div_editor.content.xml`, `core/modules/apps/templates/content/site_div_selector.container.xml`;
  - `core/modules/share/transformers/divisionEditor.xslt`;
  - `core/modules/share/scripts/{DivManager,DivSidebar,DivForm,Form}.js`;
  - `sql/cut/stage6.sql` (раздел 2);
  - `tests/{smoke.sh,smoke-final.sh,smoke-write.sh}`, `tests/audit/grids.js`.
- Delete: `core/modules/share/components/SiteList.php`, `core/modules/share/config/SiteList.component.xml`.

**Interfaces:**
- Consumes: `getCurrentSite()->base` (задача 1).
- Produces:
  - `Registry::getMap(): Sitemap` без аргумента;
  - адреса дерева: `divEditor/get-data/`, `show/`, `list/`, `/[smap_id]/selector/[any]/` у новостей — без номера сайта;
  - JSON дерева — без поля `site`.

- [ ] **Красные проверки:**
  - `smoke.sh` и `smoke-final.sh` — `divEditor/get-data/`;
  - `smoke-write.sh`:
    - поля страницы без `share_sitemap[site_id]`;
    - вторая страница с тем же сегментом под тем же родителем — отказ с сообщением, не 500 и не ошибка SQL в ответе;
    - перенос страницы к другому родителю — адрес меняется;
  - `grids.js` — дерево на `admin/structure/` без списка сайтов;
  - выбор страницы в форме новости открывает дерево и возвращает раздел.

  Прогон. Ожидается FAIL: адрес `divEditor/get-data/` не разбирается, поле `site_id` обязательно.
- [ ] **Ядро и компоненты:**
  - `Sitemap` — одно дерево, корень `smap_pid IS NULL`, мета по умолчанию от текущего сайта, без ключа `Site`, без `getSiteID`;
  - `Registry::getMap()` — один экземпляр, текст ошибки про `$siteID` уходит;
  - `DivisionEditor` — без параметра `site`, состояния `site_id`, фильтров по сайту, `getSiteByPage` и `getSiteByID`, мёртвого `jumpSite` (и `PageToolbar.jumpSite`);
  - `PageList`, `RoleEditor`, новости и ленты — `E()->getMap()`, адрес от `getCurrentSite()->base`;
  - `Builder` — имя раздела без «сайт :»;
  - `Robots::createSitemapSegment` — без перебора сайтов.
- [ ] **Конфиги, шаблоны, JS:**
  - в конфигах — шаблоны адресов без `[site_id]`;
  - из двух шаблонов уходит `SiteList`; из `divisionEditor.xslt` — `#site_selector`;
  - JS — адреса без номера сайта, `Form.js` без «сайт : раздел»;
  - удаляются `SiteList.php` и его конфиг.
- [ ] **`sql/cut/stage6.sql`, раздел 2:**
  - проверка: ровно один сайт и один корень, иначе `SIGNAL SQLSTATE '45000'` с текстом «оставьте один сайт…»;
  - затем `DROP FOREIGN KEY IF EXISTS share_sitemap_ibfk_9`;
  - в одном `ALTER` — `UNIQUE (smap_pid, smap_segment)` вместо старого ключа `smap_pid`, `DROP KEY site_id`, `DROP COLUMN site_id`. Ключ `ibfk_8` опирается на левую колонку уникального ключа — он сохраняется.
- [ ] Раздел 2 — в базу площадки. `regen-sql.sh`, `setup linker`, `setup scriptMap`.
- [ ] **Зелёный:** `check-regression.sh 15`, `menu.php`, обход, `grids.js`, `editors.js`, `fresh-check.sh`, `install-check.sh`, `migration-check.sh`. Коммит.

### Task 4: Права без сайтов

**Files:**
- Modify:
  - `core/modules/user/gears/{User,UserGroup}.php`;
  - `core/modules/apps/components/NewsRepository.php`, `core/modules/user/components/RoleEditor.php`;
  - `core/modules/user/transformers/user.xslt`, `core/modules/user/scripts/GroupForm.js`;
  - `sql/cut/stage6.sql` (раздел 3), `tests/regression.sh`.
- Create: `tests/smoke-rights.php`.

**Interfaces:**
- Produces:
  - `User::getSites`, `UserGroup::getSites` удалены;
  - JSON и форма группы — без поля `Site`.

- [ ] **Красный `tests/smoke-rights.php`** — администратор, токен:
  - временная группа с правом 2 на странице `news-editor`;
  - временный пользователь в ней, вход им;
  - `news-editor/single/newsRepo/get-data/` — все новости (число строк как у администратора);
  - форма группы (`roles/single/roleEditor/<id>/edit/`) — без строк-заголовков сайта, сохранение прав проходит;
  - уборка группы и пользователя в `finally`.

  В `regression.sh` — строка `### rights`, наборов 16. Прогон. Ожидается FAIL: 0 новостей, фильтр `[0]`.
- [ ] Фильтр по сайтам групп в `NewsRepository` уходит, `getSites` удаляются. `RoleEditor` и `user.xslt` — без `Site`. `GroupForm.js` — радиокнопки колонки ставят право на все страницы, как сейчас.
- [ ] `sql/cut/stage6.sql`, раздел 3: `DROP TABLE IF EXISTS share_groups2sites`. Генератор — без этой таблицы в списке.
- [ ] Раздел 3 — в базу площадки. `regen-sql.sh`.
- [ ] **Зелёный:** `smoke-rights.php`, `check-regression.sh 16`, `grids.js`, `fresh-check.sh`, `install-check.sh`. Коммит.

### Task 5: Один сайт в ядре и схеме

**Files:**
- Modify:
  - `core/modules/share/gears/{SiteManager,Site,Document,ErrorDocument,OGPrimitive}.php`, `core/modules/share/gears/SitePropertiesSaver.php`, `core/modules/share/components/SitePropertiesEditor.php`;
  - `core/modules/share/transformers/document.xslt`;
  - `setup/Setup.php`;
  - `sql/cut/stage6.sql` (раздел 4);
  - `tests/smoke-mail.php`, `tests/tools/{install-check,migration-check}.sh`.

**Interfaces:**
- Consumes:
  - `Site::setAddress` (задача 1);
  - `stage6.sql`, разделы 1–3 (задачи 2–4).
- Produces:
  - `SiteManager::getCurrentSite(): Site` — единственный публичный метод;
  - `Site::FOLDER = 'main'`, `$site->folder` возвращает его;
  - `<property name="base">` без атрибута `default`.

- [ ] **Красный `install-check.sh`:** 28 таблиц, нет `share_domains`, `share_domain2site`, `share_groups2sites`, `share_sitemap.site_id`, `share_sites.site_is_default`.
- [ ] **Красный `migration-check.sh`, новая часть для `stage6.sql`.** База до этапа 6 — `git show <коммит до этапа 6>:sql/{structure,data,demo}.sql`, коммит записан в скрипте. Поверх — своё содержимое сайта:
  - свой текст главной;
  - своя страница;
  - новость;
  - свойство сайта.

  Проверяется:
  - после `stage6.sql` тексты, страницы с адресами, права, новости и свойство те же;
  - повторный прогон ничего не меняет (отпечаток);
  - второй сайт в `share_sites` → отказ до изменений: `share_domains` на месте, `site_id` на месте, текст отказа в выводе;
  - второй корень → отказ.

  Прогон. Ожидается FAIL: раздела 4 нет.
- [ ] **`SiteManager` и `Site`:**
  - `SiteManager` — одна запись `share_sites`, без `Iterator`, `getSiteByID`, `getSiteByPage`, `getDefaultSite` и проверки активности;
  - `Site::load` — одна строка; свойства — из `share_sites_properties` без `site_id`.
- [ ] **Потребители:**
  - `Document` — `resizer` от текущего сайта, без атрибута `default`;
  - `document.xslt` — `MAIN_SITE` от `base`;
  - `OGPrimitive` — текущий сайт;
  - `SitePropertiesEditor` и `SitePropertiesSaver` — без `site_id`;
  - `smoke-mail.php` — без `site_is_default=1`;
  - `Setup` — текст о 31 таблице.
- [ ] **`sql/cut/stage6.sql`, раздел 4:**
  - проверка одного сайта — та же, что в разделе 2, стоит первой;
  - `DROP TABLE IF EXISTS share_domain2site, share_domains`;
  - `share_sites` — `DROP COLUMN IF EXISTS` четырёх колонок;
  - `share_sites_properties`:
    - сначала уходят внешний ключ на `share_sites` и уникальный ключ `(site_id, prop_name)`;
    - строки с `site_id` сайта заменяют одноимённые строки без сайта;
    - `DROP COLUMN site_id`;
    - `UNIQUE (prop_name)`.
- [ ] Раздел 4 — в базу площадки. `regen-sql.sh`.
- [ ] **Зелёный:** `install-check.sh`, `migration-check.sh`, `fresh-check.sh`, `check-regression.sh 16`, обход, `theme.js`. Коммит.

### Task 6: Следы и документы

**Files:**
- Modify:
  - `tests/no-traces.sh`;
  - `README.md`, `docs/INSTALL.md`, `tests/README.md`;
  - `sql/cut/stage6.sql` (раздел 5, демо-текст);
  - `tests/tools/install-check.sh` (число таблиц в комментарии).

- [ ] **Красный `no-traces.sh`, категория «мультисайт»:**
  - таблицы `share_domains`, `share_domain2site`, `share_groups2sites`;
  - классы и файлы `SiteEditor`, `SiteEditorConfig`, `SiteSaver`, `DomainEditor`, `SiteList`, `CrossDomainAuth`, `SiteManager.js`;
  - слова `site_is_default`, `site_is_active`, `site_folder`, `site_order_num`, `dev_domains`, `site_selector`, `writeDomains`, `getSiteByID`, `getSiteByPage`, `getDefaultSite`, `jumpSite`;
  - колонка `share_sitemap.site_id` в базе;
  - страница `main/sites.content.xml` в базе.

  Константы, удалённые в i18n, берутся из `sql/cut/stage6.sql`. Прогон — находки в документах и демо-тексте.
- [ ] **`stage6.sql`, раздел 5:** демо-текст 73 (ru и ua) — про «Настройки сайта» и ссылка на `admin/settings/`, а не про «редактор сайтов и доменов». Правится только демо: в `data.sql` этого блока нет. Раздел — в базу площадки. `regen-sql.sh`.
- [ ] **Документы:**
  - `README.md`, `docs/INSTALL.md` — 28 таблиц; адрес из конфига (`site.domain` с портом, `site.root`); «Настройки сайта»;
  - `tests/README.md` — новые наборы, генератор, `migration-check` для `stage6.sql`.
- [ ] **Итоговый прогон:**
  - `check-regression.sh 16`, обход, `editors.js`, `grids.js`, `theme.js`;
  - `install-check.sh`, `fresh-check.sh`, `migration-check.sh`, `no-traces.sh`;
  - `.githooks/secret-scan.php`;
  - повторный `stage6.sql` на базе площадки — отпечаток тот же.

  Коммит.
