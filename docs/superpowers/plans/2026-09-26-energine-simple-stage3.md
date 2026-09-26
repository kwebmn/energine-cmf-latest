# Energine Simple — этап 3: почистить share. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Из кода и базы уходят:
- теги;
- виджеты и редактор блоков;
- нелокальные хранилища файлов;
- водяные знаки;
- видео и Flash;
- неиспользуемый выбор записей из справочника (`Lookup`, select2);
- колонки, на которые код не ссылается.

Меню сайта перестаёт зависеть от тегов.

**Architecture:** Как на этапах 1–2:
- переходный скрипт `sql/cut/stage3.sql` применяется после `stage2.sql`;
- `tests/no-traces.sh` получает категории этапа 3;
- переводы чистит `tests/tools/cut-constants.php`;
- установка с нуля сверяется с переведённой базой через `tests/tools/rebuild.sh` и `fingerprint.php`.

Каждая задача меняет базу и код, который её читает, вместе.

**Меню без тегов.** Сейчас главное меню — это `PageList` с параметром `tags=menu`. Тег `menu` висит на страницах, которые должны быть в меню. Форма новой страницы подставляет его по умолчанию. Замена: колонка `share_sitemap.smap_in_menu` (`TINYINT(1) NOT NULL DEFAULT 1`) и параметр `menu` у `PageList`. В форме раздела это флажок «Показывать в меню». Перенос данных: флаг равен 1 у страниц с тегом `menu`, у остальных 0.

Спецификация велит вырезать теги целиком и молчит о том, чем их заменить в меню. Флаг — наименьшая замена, при которой человек по-прежнему решает, какие страницы видны в меню.

**Tech Stack:** PHP 8.5, MariaDB 10.11, XSLT, MooTools, bash, Playwright.

**Spec:** `docs/superpowers/specs/2026-09-26-energine-simple-design.md` — раздел 3 «Из share», раздел 5, раздел 9 (этап 3).

## Global Constraints

Те же, что на этапах 1–2:
- конфиги веб-сервера не трогаются;
- владелец файлов `web97:client1`, git работает от root, после него `chown`;
- PHP — `php8.5`;
- пароли не попадают ни в git, ни в вывод команд;
- письма уходят только на `web97@loki.kweb.biz`;
- `web93` только читается;
- коммиты делаются с явными путями;
- клиент `mysql` всегда запускается с `--default-character-set`.

Остаются:
- **CodeMirror.** Его используют поля кода: шаблоны писем, исходник текстового блока, XML страницы. Удаляются только режимы и дополнения, которые никто не подключает.
- **`Carousel.js`** — на нём `AttachmentsCarousel`.
- **FileAPI и CKEditor** — их заменяет этап 4. Из CKEditor на этом этапе уходят только кнопки видео и Flash.
- **Свой XML страницы** (`smap_content_xml`). Правится полем кода в форме раздела, сбрасывается очисткой этого поля.
- **Мультисайт** (`SiteList`, `SiteEditor`, домены) — этап 6. Теги из него уходят сейчас.

Правило раздела 5 спецификации: «в оставшихся таблицах не будет колонок вырезанного». Поэтому вместе с видео уходят и `upl_is_mp4`, `upl_is_ready`, хотя в таблице примеров их нет.

## Review Focus

1. **Меню без тегов.**
   - Страницы, которые были в меню, остаются в нём на обоих языках.
   - Служебные страницы в меню не появляются: вход, восстановление пароля, `robots.txt`, `sitemap.xml`.
   - Новая страница по умолчанию попадает в меню, снятый флажок её убирает.
   - Подменю админки на месте.

   Тест — `menu.php`.
2. **Страницы со своим XML (главная).** После снятия атрибутов виджетов и параметра `tags` на странице те же компоненты и те же тексты. Тест — список компонентов из `smap_content_xml` до и после, чтение всех страниц, обход.
3. **Файловый репозиторий без хранилищ, водяных знаков и видео.** Работают загрузка, папки, удаление, выбор файла в формах. Картинки новостей и галереи отдаются. Тест — `smoke-upload`, ответы 200 на картинки, обход форм.
4. **Формы админки, где были теги, lookup и поля кода.** Раздел, новость, сайт, файл, шаблон письма и исходник текстового блока открываются и сохраняются. Тест — `smoke-roundtrip`, `smoke-editing`, обход форм.
5. **Установка с нуля расходится с переведённой базой.** Тест — `fingerprint.php` до и после `rebuild.sh`.

---

### Task 1: Тест «нет следов» и тест меню

- [ ] Снимок базы: `backup/db-stage3-before-*.sql.gz`.
- [ ] В `tests/no-traces.sh` — категории этапа 3: `tags`, `widgets`, `storages`, `watermark`, `video`, `flash`, `lookup`, `columns`. У каждой есть часть для кода и часть для базы.
  - **По коду:**
    - классы, пути, скрипты, стили;
    - состояния (`tags`, `showWidgetEditor`, `putVideo`, `lookup`);
    - атрибуты `widget=` и `column=` в шаблонах;
    - параметр `name="tags"`;
    - колонки видео и неиспользуемые колонки.
  - **По базе:**
    - таблицы `share_tags*`, `share_sitemap_tags`, `share_sites_tags`, `share_uploads_tags`, `apps_news_tags`, `share_widgets`;
    - страница `admin/widgets`;
    - атрибуты `widget=` и `column=`, параметр `tags` в XML страниц;
    - хранилища `repo/ftp*` и `repo/ro` в `share_uploads`;
    - колонки видео (`upl_is_mp4`, `upl_is_webm`, `upl_is_flv`, `upl_duration`, `upl_is_ready`) и неиспользуемые (`upl_views`, `u_fbid`, `u_vkid`, `u_company`, `u_position`, `news_show_image`);
    - слова в текстовых блоках.

  Выражения калибруются на красном прогоне и не должны задевать оставшееся:
  - `strip_tags`;
  - `share_lang_tags`;
  - `ltag_*`;
  - OG-теги;
  - блоки `block=`;
  - изображения в `fields.xslt`;
  - CodeMirror.
- [ ] `tests/menu.php` (через `testlib.php`):
  1. Меню гостя на `/` и `/ua/` — ровно корневые страницы с `smap_in_menu = 1`, доступные гостю. Вход, восстановление пароля, `robots.txt` и `google-sitemap` в меню не попадают.
  2. `smap_in_menu = 0` у `contacts` убирает `/contacts/` из меню, возврат флага возвращает. Исходное значение восстанавливается и при падении.
  3. Форма добавления страницы в админке содержит поле `smap_in_menu` со значением 1 по умолчанию.
  4. Администратор видит в меню подразделы админки.
- [ ] `menu.php` — девятый набор в `regression.sh`.
- [ ] Красный прогон `no-traces.sh all` по новым категориям и `menu.php` (нет колонки), коммит.

### Task 2: Меню без тегов

**Files:**
- `sql/cut/stage3.sql` (блоки 1–2);
- `share/components/PageList.php`;
- шаблоны содержимого с `<param name="tags">menu</param>`: 22 файла в `core` и `site`;
- `share/components/DivisionEditor.php`, конфиги `DivisionEditor`, `SiteDivisionEditor`;
- `tests/smoke-write.sh`.

**`stage3.sql`:**
1. `ALTER TABLE share_sitemap ADD COLUMN IF NOT EXISTS smap_in_menu TINYINT(1) NOT NULL DEFAULT 1 AFTER smap_segment`. Затем, только пока есть `share_sitemap_tags` (динамический SQL, повторный прогон ничего не меняет), флаг 0 у страниц без тега `menu`.
2. XML страниц: `<param name="tags">menu</param>` меняется на `<param name="menu">1</param>`.
3. Переводы `FIELD_SMAP_IN_MENU`: «Показывать в меню» / «Показувати в меню», через `INSERT IGNORE`.

- [ ] `PageList`: параметр `menu` вместо `tags` — страницы с `smap_in_menu = 0` отбрасываются.
- [ ] Шаблоны: `tags=menu` меняется на `menu=1`.
- [ ] Форма раздела: флажок, при добавлении по умолчанию включён. Подстановка тега `menu` в `add()` уходит в задаче 3 вместе с тегами.
- [ ] `smoke-write.sh`: страница создаётся с `share_sitemap[smap_in_menu]=1`.
- [ ] Зелёный `menu.php`, повторный прогон скрипта без изменений, регрессия, коммит.

### Task 3: Теги

**`stage3.sql`, блок 3:**
- таблицы `share_tags`, `share_tags_translation`, `share_sitemap_tags`, `share_sites_tags`, `share_uploads_tags`, `apps_news_tags` — по списку из `information_schema`;
- тексты путеводителя без упоминания тегов — точными заменами.

**Код:**
- **Удаляются целиком:**
  - `share/gears/TagManager.php`;
  - `share/components/TagEditor.php`, `config/TagEditorModal.component.xml`, `transformers/tagEditor.xslt` и его подключение;
  - скрипты `Tags.js`, `TagEditor.js`, `DropBoxList.js` (если его грузят только теги);
  - `stylesheets/tags.css`, `acpl.css` (если он только для тегов).
- **Правятся:**
  - `Grid` — состояние `tags`, подсказки тегов, `tagEditor`;
  - `GridConfig` — состояние `tags`;
  - `QAL::getTagsTablename`;
  - `Form.js` — `Tags`, `Form.BooleanTag`;
  - `fields.xslt` — поле `tags`;
  - `NewsFeed` — состояние `tag` и его шаблоны в конфиге;
  - `ExtendedFeed`, `ExtendedFeedEditor`, `DivisionEditor` — поле тегов;
  - `Sitemap::getPagesByTag` и `PageList` — `id` по тегу;
  - `SitemapTree`, `NavigationMenu`, `SiteList` — параметр `tags`;
  - `SiteEditor`, `SiteSaver`, `SiteManager` — теги сайтов;
  - `AttachmentManager`, `ExtendedSaver` — теги файлов.

- [ ] Красный `no-traces.sh all tags`. Удаления, `php -l`, проверка XML, `setup linker`, зелёный `no-traces.sh all`. Затем регрессия, обход и коммит.

### Task 4: Виджеты и редактор блоков

**`stage3.sql`, блок 4:**
- таблица `share_widgets`;
- страница `admin/widgets` (родитель ищется от корня);
- в XML страниц снимаются атрибуты ` widget="widget"`, ` widget="static"`, ` column="column"`;
- тексты путеводителя.

**Код:**
- **Удаляются целиком:**
  - `share/components/WidgetsRepository.php`, конфиги `WidgetsRepository` и `ModalWidgetsRepository`;
  - скрипты `LayoutManager.js`, `WidgetGridManager.js`, `ComponentParamsForm.js`, `NewTemplateForm.js`;
  - `stylesheets/layout_manager.css`;
  - `site/.../widgets_repository.content.xml`.
- **Правятся:**
  - `PageToolbar.js` и конфиг `DivisionEditor` — переключатель `editBlocks`;
  - `DivisionEditor` — `showWidgetEditor`, `widgetEditor`, сведения о шаблоне для редактора блоков. `resetTemplates` удаляется, если его зовёт только `LayoutManager`;
  - `container.xslt` — обёртки `column` и `widget` для администратора;
  - `ComponentManager::findBlockByName` — удаляется, если больше не используется.
- **Шаблоны содержимого:** атрибуты `widget=` и `column=` снимаются во всех `*.content.xml`.

- [ ] Перед правкой — список имён компонентов из XML каждой страницы со своим XML. После правки он должен совпасть.
- [ ] Красный `no-traces.sh all widgets`, удаления, проверки, зелёный. Затем регрессия, обход и коммит.

### Task 5: Хранилища и водяные знаки

**Удаляются:**
- `FileRepositoryFTP.php`, `FileRepositoryFTPRO.php`, `FileRepositoryRO.php`, `FTP.php`;
- `WatermarkDefault.php`, `FileRepositoryWatermark.php`, `IWatermark.php`.

**Правятся:**
- `FileRepositoryLocal` — без водяного знака и описания FTP;
- `FileRepoInfo` — только `repo/local`;
- `configs/system.config.default.php` — секция `repositories` без FTP и RO, секции `ftp` нет;
- конфиг площадки — те же строки, правкой по месту без вывода содержимого, затем `php -l`;
- `stage3.sql`, блок 5: записи хранилищ `repo/ftp`, `repo/ftpro`, `repo/ro` в `share_uploads` вместе с содержимым.

- [ ] Красный `no-traces.sh all storages watermark`, правки, зелёный. Затем `smoke-upload`, регрессия, обход и коммит.

### Task 6: Видео и Flash

**Удаляются целиком:**
- `share/gears/VideoUploader.php`;
- `scripts/jwplayer/`, `Player.js`, `Playlist.js`;
- `transformers/embed_player.xslt`, `media.xslt` и их подключения;
- `Swiff.Uploader.js`, `Swiff.Uploader.swf`, `expressInstall.swf`, `swfobject.js`;
- плагин CKEditor `energinevideo`.

**Правятся:**
- `DataSet::embedPlayer`;
- `FileRepositorySelect` — состояние `putVideo` и кнопка вставки видео;
- `FileRepoForm.getPlayerParams`;
- `Form.js` — плагин `energinevideo`, кнопка `Flash`, фильтр `*.flv`;
- `fields.xslt` — плеер и видео во вложениях, картинки остаются;
- `AttachmentManager` — поля видео, OG-видео, фильтр `upl_is_ready`;
- `OGObject::setVideo`;
- `FileRepository.js` — сведения о видео;
- `FileRepoInfo` — тип `video` и флаги форматов: видеофайл — обычный файл;
- конфиги `FileRepository*` — поля видео;
- `setup/Setup.php` — исключения `jwplayer` и `Swiff.Uploader`;
- стили плеера.

**`stage3.sql`, блок 6:**
- колонки `upl_is_mp4`, `upl_is_webm`, `upl_is_flv`, `upl_duration`, `upl_is_ready`, `upl_views` (`DROP COLUMN IF EXISTS`);
- записи с типом `video` становятся обычными файлами.

- [ ] Красный `no-traces.sh all video flash`, правки, зелёный. Затем `smoke-upload`: картинка и файл `.mp4` грузятся как обычные файлы. Картинки новостей и галереи отдают 200. Регрессия, обход, коммит.

### Task 7: Lookup и select2, CodeMirror, мёртвый код, внешняя заглушка

**Lookup.** `FieldDescription::FIELD_TYPE_LOOKUP` не назначает ни один конфиг — ни на этой площадке, ни в полной системе. Удаляются:
- `Lookup.php`, `LookupConfig.php`, `user/components/UserLookup.php`;
- `config/Lookup.component.xml`;
- `Lookup.js`, `TextboxList.js` (если его грузит только `Lookup`);
- `scripts/select2/`, `stylesheets/select2/`;
- состояние `lookup` в `Grid` и `GridConfig`;
- ветки lookup в `DBDataSet` и `Builder`;
- константа типа;
- шаблоны lookup в `form.xslt` и `fields.xslt`;
- загрузка `Lookup` в `Form.js`.

**CodeMirror.** Остаются `lib/` и режимы и дополнения, которые подключают `form.xslt`, `text.xslt`, `divisionEditor.xslt` и `Form.js`. Остальное удаляется.

**Мёртвый код.** `GridManager.copy()` отложен с этапа 1.

**Внешняя заглушка.** Пустые картинки в админке берутся с `placehold.it`: сервис мёртв, браузер
блокирует ответ, а адрес уходит третьей стороне. Места: `fields.xslt` (превью пустого поля),
`Energine.js` (замена несуществующей картинки), `FileRepository.js` (превью в репозитории).
Замена — локальная заглушка: SVG в `data:` того же размера. Решение ревью этапа 2.

- [ ] Красный `no-traces.sh all lookup` и новой категории `placehold` (код), удаления и замена, зелёный.
- [ ] Обход форм с полями кода: шаблон письма, исходник текстового блока, XML страницы. Регрессия, коммит.

### Task 8: Неиспользуемые колонки

`stage3.sql`, блок 7: `user_users.u_fbid`, `u_vkid`, `u_company`, `u_position`, `apps_news.news_show_image`. Перед удалением код, конфиги и тесты проверяются поиском на отсутствие ссылок.

- [ ] Красный `no-traces.sh db columns`, скрипт, зелёный. Затем `smoke-roundtrip`, `smoke-profile`, регрессия и коммит.

### Task 9: Переводы

- [ ] `raw-constants.php` — базовая линия.
- [ ] `cut-constants.php` (с этапа 2 комментарии в словарь не входят):
  - удалённые файлы — копии на web93;
  - таблицы и колонки — из базы web93;
  - вырезанные колонки — через `--cut-column`.
- [ ] Строки, которых не было ни в каком коде, инструмент не видит. Их ищут по именам
  вырезанного в справочнике (`TAG`, `WIDGET`, `VIDEO`, `FLASH`, `FTP`, `WATERMARK`, `LOOKUP` и т. п.),
  каждое имя проверяется поиском по коду и текстам базы. Урок ревью этапа 2.
- [ ] Блок 8 в `stage3.sql`, применить.
- [ ] Зелёный `no-traces.sh i18n`. Новых сырых имён нет, `setup untranslated` не показывает новых. Коммит.

### Task 10: Установка с нуля и документы

- [ ] `rebuild.sh` проверяет архив загрузок до того, как снять базу (отложено с ревью этапа 2).
- [ ] Перевод со снимка «до этапа 3»: восстановить снимок, применить `stage3.sql` дважды. Второй прогон ничего не меняет, `fingerprint.php` (данные и схема).
- [ ] `rebuild.sh`: восемь файлов, три скрипта `cut`, файлы этапов. Сверка отпечатков.
- [ ] `no-traces.sh all`, `raw-constants.php`, регрессия (9 наборов), обход.
- [ ] Документы:
  - `INSTALL.md` — таблицы и страницы, этап 3;
  - `README.md`;
  - `tests/README.md` — `menu.php` и категории этапа 3.
- [ ] Скан секретов, коммит.
