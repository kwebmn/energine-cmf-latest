# Energine Simple — надёжность, этап 5: адреса и интерфейс. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Адреса сайта однозначны и не теряются (`/about` → `/about/`, переименованная или перенесённая страница
отвечает со старого адреса переадресацией 301), админка без вёрстки на JavaScript (грид — одна таблица на CSS, окна —
`<dialog>`), картинки уменьшает свой ресайзер на GD вместо заброшенного `timthumb`.

**Разведка (2026-10-06):**
- Адреса. `URI::setPath` отбрасывает пустые сегменты, поэтому `/info/quick-start` и `/info/quick-start/` отдают одну
  страницу с кодом 200 (дубль для поисковиков). `Sitemap::getIDByURI` идёт по сегментам от корня: известные сегменты —
  страница, остаток — параметры компонентов (`page-2/`, `single/…`); неиспользованный остаток — 404
  (`DocumentController::run`, строка 163). Единственная переадресация до разбора — `SiteManager::canonicalLocation()`:
  другое имя хоста → 301 на `site.domain` (только GET/HEAD; тестом не покрыта — через nginx другое имя не доходит).
  Сегмент страницы — `share_sitemap.smap_segment char(50)`, общий для всех языков, шаблон `[a-z0-9\-\.]*` (точка
  разрешена: страница `robots.txt/`). Адрес меняют только сохранение формы раздела (`DivisionEditor::save` — сегмент
  и родитель) и удаление; старый адрес после этого — 404 (`tests/smoke-write.sh` проверяет 404 после переноса).
  Окна админки открывают адреса без слеша (`…/123/edit`, `…/imagemanager`, `add/<id>`, `template`, `translation`,
  `user`, `move/<id>`, `singlePath + key`) — GET в iframe; запросы данных гридов и сохранения — POST
  (`Energine.request`, заголовок `X-Request: JSON`).
- xsight (`web94/private/xsight-dev`, прочитан агентом): нет ни памяти адресов, ни ресайзера, ни нормализации слеша —
  ссылки там хранятся по id страницы, ошибка 404 отдаётся с кодом 200. Делаем своё.
- Грид (`list.xslt` + `GridManager.js`, 1121 строка): две таблицы — шапка в `.gridHeadContainer`, тело в
  `.gridContainer > .gridBodyContainer` со скрытой копией `<thead>`; `adjustColumns()` меряет ячейки первой строки и
  переписывает `<col>` обеих таблиц, `scrollBarWidth()` подгоняет отступ шапки под полосу прокрутки, `fitGridSize()` и
  `fitGridFormSize()` считают высоты с поправками «-9», «+3», «-81»; панель на странице (`.e-pane`, вне окна)
  получает высоту из JS. Аудит `grids.js` п. 3 проверяет равенство `<col>` и inline-высоты.
- Окна (`ModalBox.js`, 152 строки): `div.e-modalbox` с iframe в документе `window.top`, одно затемнение `Overlay`
  на все окна, Esc окно не закрывает (просьба клиента), `z-index` 1001. 7 файлов открывают окна; аудиты
  `admin.js` и `grids.js` проверяют `z > 1000`, `.e-overlay` и Esc.
- Ресайзер: правило nginx площадки `rewrite "^/resizer/w([0-9]+)\-h([0-9]+)/(.*)$" /resizer/timthumb.php?w=$1&h=$2&src=$3&zc=2;`
  (то же в `docs/INSTALL.md`; конфиг веб-сервера не трогаем — имя точки входа `resizer/timthumb.php` остаётся).
  `timthumb.php` — 1260 строк чужого кода (2012 г.), `timthumb-config.php` отключает внешние источники; кэш
  `timthumb_*.timthumb.txt` — в `web97/tmp` (866 файлов). Поведение при `zc=2`: вписать в W×H по центру с полями
  (белые; у PNG — прозрачные), нулевая сторона — по пропорции, обе нулевые — 100×100, не больше 1500×1500,
  маленькие увеличиваются, формат — как у исходника, JPEG — качество 90; браузеру — `max-age` 10 дней.
  Адреса: `w40-h40` (грид), `w60-h45`, `w298-h224` (репозиторий), `w0-h0` (превью загрузки из `uploads/temp/`),
  `wN-hN` из окна картинки (вставляются в тексты публичных страниц). GD 2.3.3 с JPEG, PNG, GIF, WebP, AVIF — есть.

**Architecture:**
- **Завершающий слеш.** `SiteManager::canonicalLocation()` вычисляет канонический адрес запроса чистой функцией
  `SiteManager::canonicalURL(string $method, string $scheme, string $host, int $port, string $requestUri,
  bool $json, string $domain): ?string`: другое имя хоста → `site.domain`; путь страницы без `/` на конце → с `/`;
  оба сразу — одна переадресация 301. Слеш добавляется только у GET/HEAD без `X-Request: JSON` и только если в
  последнем сегменте нет точки (`robots.txt`, `index.php`, `x.jpg` — как есть); строка запроса сохраняется как была.
  Окна админки открывают адреса со слешем (без лишней переадресации). Обход (`crawl.js`) ловит внутренние
  переадресации и ссылки без слеша.
- **Память старых адресов.** Таблица `share_sitemap_aliases (alias_path varchar(255) PK, smap_id FK → share_sitemap
  ON DELETE CASCADE, alias_date datetime)`: прежний путь страницы без языка и краевых слешей (`about/team`). Гир
  `PageAliases` (на `Db`): `paths(): array` — пути всех страниц из базы (без учёта прав и языка); `remember(array
  $before): int` — после сохранения раздела каждой странице, чей путь изменился (сама и её подразделы), — прежний путь
  (`ON DUPLICATE KEY UPDATE` — последний владелец), затем удаляются псевдонимы, совпавшие с нынешними путями страниц
  (настоящая страница всегда важнее); `find(array $segments): ?array` — самый длинный префикс пути запроса, записанный
  как прежний адрес → `['id' => int, 'rest' => string[]]`. `DivisionEditor::save` зовёт `paths()` до `saveData()` и
  `remember()` после — в той же транзакции. `DocumentController::run`: перед страницей 404 (GET/HEAD, не JSON) —
  `oldAddress()`: псевдоним найден, страница видна посетителю (есть в его дереве разделов) → 301 на
  `base + язык запроса + нынешний путь + остаток + '/' + строка запроса`. Цепочек нет: псевдоним указывает на id, а не
  на путь. Переход базы — `sql/cut/stage17.sql`, файлы установки — `tests/tools/regen-sql.sh`.
- **Грид на CSS.** `list.xslt`: одна таблица `.gridContainer > table.gridTable` с настоящим `<thead>` (у файлового
  репозитория — `<colgroup>` с процентами и `table-layout: fixed` классом `fixed_columns`). CSS: шапка
  `position: sticky; top: 0`, `.grid` — колонка flex на всю высоту вкладки, `.gridContainer` — `flex: 1; min-height: 0;
  overflow: auto`, длинные значения переносятся (`overflow-wrap: anywhere`). Панель грида на странице:
  `height: max(500px, calc(100dvh - var(--e-pane-top) - 1rem))`, где `--e-pane-top` — верх панели (JS ставит одной
  строкой при построении и при изменении окна). Из `GridManager.js` уходят `adjustColumns`, `fitGridSize`,
  `fitGridFormSize`, `scrollBarWidth`, `totalWidth`, `totalHeight`, `pageY`, `style`, `minGridHeight` и
  `window.ScrollBarWidth`; прокрутка к выбранной строке учитывает высоту шапки.
- **Окна `<dialog>`.** `ModalBox.open` создаёт `<dialog class="e-modalbox …">` в документе верхнего окна и зовёт
  `showModal()`: окно в верхнем слое (без `z-index`), страница под ним недоступна мыши и клавиатуре (`inert` — от
  браузера), затемнение — `::backdrop` (у вложенных окон — прозрачное: затемнение одно, как прежде), страница под
  окном не прокручивается (`html:has(dialog.e-modalbox[open]) { overflow: hidden }`); Esc окно по-прежнему не
  закрывает (`cancel` и `keydown Escape` — `preventDefault`). `close()`: `onClose(returnValue)`, затем `dialog.close()`
  и удаление (фокус возвращается браузером). iframe внутри окна остаётся (отказ от iframe — не в этом этапе).
  `Overlay` остаётся знаком «занято» для форм и гридов.
- **Свой ресайзер.** Гир `core/modules/share/gears/ImageResizer.php` (чистый PHP + GD, без ядра и базы):
  `__construct(string $webRoot, string $cacheDir)`, `source(string $src): ?string` (только обычный файл внутри
  `<webRoot>/uploads/` после `realpath`, расширения jpg/jpeg/png/gif/webp, тип по `getimagesize`), `static box(int $w,
  int $h, int $srcW, int $srcH): array` (размеры холста и картинки на нём — как у timthumb `zc=2`),
  `respond(array $get, array $server): void` (404 без текста ошибки; ETag и Last-Modified → 304; готовая картинка —
  в кэше `<upload_tmp_dir>/energine-resizer/` атомарной записью; раз в сутки — удаление записей старше 30 дней).
  `htdocs/resizer/timthumb.php` — точка входа на 10 строк (имя задаёт правило nginx); `timthumb-config.php` удаляется
  (в репозитории и в `web/`), прежний кэш `web97/tmp/timthumb_*` — удаляется. `setup check` — строка «ресайзер:
  GD с JPEG, PNG, WebP».

**Tech Stack:** PHP 8.5 + GD, MariaDB, XSLT 1.0, ES-модули без сборки, Tailwind v4 (`setup css`), Playwright.

**Spec:** `docs/superpowers/specs/2026-10-05-energine-simple-reliability-design.md` (этап 5).

## Global Constraints

- Поведение меняется только там, где этап это называет: 301 у адреса страницы без `/` и у старого адреса
  переименованной или перенесённой страницы (прежде — дубль 200 и 404); грид — одна таблица, высоты — CSS; окна —
  `<dialog>`; картинки — свой ресайзер с тем же видом (размеры, поля, формат). Остальное — как было: полный прогон,
  обход, аудиты гридов, редакторов, админки после каждой задачи; `xslt-golden` — разница только в разметке грида
  (задача 3).
- Конфиги веб-сервера не трогаются: правило `resizer/wN-hN/…` → `resizer/timthumb.php` остаётся, файл с этим именем
  остаётся точкой входа.
- Не делаем (спецификация): отказ от iframe в окнах, Twig, DI-контейнер, TypeScript со сборкой, Web Components,
  замену Jodit, HTML-кэш для гостей.
- Правки ядра в живом дереве (урок этапа 4): сначала добавить новое, потом переключить вызовы, потом удалить старое;
  после каждой правки PHP — `php8.5 -l` и ответ главной и админки (`curl`); копии `htdocs/` → `web/` — тем же шагом;
  удаляемое имя ищется и в `htdocs/`, и в `web/`.
- Запросов на страницу не больше бюджета `tests/queries.php` (гость 20, администратор 30): псевдонимы читаются только
  на пути 404, слеш — без базы.
- Общие правила: владелец `web97:client1` (git от root, затем `chown`; `setup` — от web97); пароли не в git и не в
  выводе; письма только локально; web93 только читается; `rebuild.sh` не запускается; новые скрипты модулей —
  `setup linker` и владелец web97.

## Review Focus

1. **Переадресации без петель и потерь:** адрес-«файл» (точка в последнем сегменте) и корень не трогаются; строка
   запроса и язык сохраняются; POST и JSON не переадресуются; другое имя хоста плюс нет слеша — одна переадресация;
   старый адрес, снова ставший страницей, отдаёт страницу; хвост пути после старого адреса (`page-2/`, подраздел)
   переносится; псевдоним не ведёт на свою же страницу.
2. **Старые адреса и права:** страница, скрытая от гостя или выключенная на его языке, не выдаётся переадресацией
   (404, а не 301 на страницу, которую нельзя открыть); удаление страницы уносит её старые адреса; перенос раздела
   с подразделами — подразделы отвечают со старых адресов за одну переадресацию.
3. **Грид:** длинное значение ячейки (адрес без пробелов) не раздвигает таблицу за край; пустой грид; грид в окне и
   на странице; узкое окно 390 px; файловый репозиторий с фиксированными колонками; шапка видна при прокрутке
   списка; выбранная строка после перезагрузки видна, а не под шапкой.
4. **Окна:** Esc не закрывает ни одно окно (и повторный Esc); окно в окне — затемнение одно; после закрытия
   последнего окна страница прокручивается и фокус вернулся; страница под окном недоступна мыши; форма в окне
   сохраняет и закрывает окно с результатом (`onClose`).
5. **Ресайзер:** путь вне `uploads/`, `..`, абсолютный путь, внешний адрес, символическая ссылка наружу, каталог,
   не-картинка с расширением картинки, огромные и нулевые размеры, PNG/GIF/WebP с прозрачностью, замена файла
   (кэш не отдаёт старую картинку), 304 по ETag и Last-Modified, HEAD без тела, нет записи в кэш — картинка всё
   равно отдаётся.

Проверки: п. 1 — `tests/urls.php`, `tests/page-aliases.php`, `crawl.js`; п. 2 — `tests/page-aliases.php`; п. 3 —
`tests/audit/grids.js`, `tests/audit/admin.js`; п. 4 — `tests/audit/grids.js`, `tests/audit/admin.js`,
`tests/audit/editors.js`; п. 5 — `tests/resizer.php`.

---

### Task 1: Завершающий слеш

**Files:** `core/modules/share/gears/SiteManager.php` (`canonicalURL`, `canonicalLocation`), окна без слеша —
`core/modules/share/scripts/{PageToolbar,GridManager,Form,EnergineEditor}.js`, `tests/urls.php` (новый, регрессия),
`tests/audit/crawl.js` (внутренние переадресации, ссылки без слеша), `tests/regression.sh`.

**Interfaces:**
- Produces: `SiteManager::canonicalURL(string $method, string $scheme, string $host, int $port, string $requestUri,
  bool $json, string $domain): ?string` — абсолютный адрес для 301 или null; `canonicalLocation(): ?string` — то же
  для текущего запроса (`$_SERVER`), null в консоли. Канонический путь страницы всегда кончается на `/`.

- [ ] **Red:** `tests/urls.php`:
  - чистая функция (консоль): `GET https simple… /info/quick-start` → `https://simple.energine.org/info/quick-start/`;
    `?x=1&y=2` сохраняется; `HEAD` — так же; `POST` и `json=true` — null; `/robots.txt`, `/uploads/a.jpg`,
    `/info/x.php` — null; `/` — null; `/ua` → `/ua/`; другое имя хоста и нет слеша — один адрес с хостом
    `site.domain` и слешем; другое имя хоста со слешем — как прежде (только хост); пустой путь запроса — `/`;
  - HTTP через nginx: `GET /info/quick-start` → 301 и `Location` …`/info/quick-start/`; с `?x=1` — с ним же;
    `HEAD` → 301; `/info/quick-start/` → 200; `/` → 200; `POST /info/quick-start` → не 301; `GET` с
    `X-Request: JSON` → не 301; `/info/quick-start/nofile.txt` → не 301; `/ua/info` → 301 на `/ua/info/` (если
    второй язык открыт; иначе SKIP с причиной).
  FAIL (функции нет, `/info/quick-start` — 200).
- [ ] **Реализация.** `canonicalURL` (путь и строку запроса — из `requestUri` как есть, без декодирования);
  `canonicalLocation` зовёт её. JS окон: `…/edit/`, `imagemanager/`, `add/<id>/`, `template/`, `translation/`, `user/`,
  `move/<id>/`, `<singlePath><key>/`, `file-library/<pid>/add/`. `crawl.js`: ответ 301/302/307/308 своего хоста на
  любой запрос страницы (документ, iframe, скрипт) — ошибка `redirect: адрес → куда`; ссылка `a[href]` своего хоста
  без `/` на конце (кроме «файлов» с точкой, `#…`, `mailto:`, `tel:`, `javascript:`) — ошибка `link without /`.
- [ ] **Green:** `urls.php`, обход (77/0, ни одной внутренней переадресации), аудиты grids/editors/admin, регрессия.
  Коммит.

### Task 2: Память старых адресов (301)

**Files:** `sql/cut/stage17.sql` (новый), `sql/structure.sql` (regen), `core/modules/share/gears/PageAliases.php`
(новый), `core/modules/share/components/DivisionEditor.php` (`save`), `core/modules/share/gears/DocumentController.php`
(`oldAddress`), `tests/page-aliases.php` (новый, регрессия), `tests/smoke-write.sh` (перенос: 404 → 301),
`tests/tools/install-check.sh` (22 → 23 таблицы), `tests/tools/fingerprint.php` (строки псевдонимов — служебные),
`tests/fixtures/schema-info.json` (пересъёмка: новая таблица), `tests/regression.sh`.

**Interfaces:**
- Consumes: канонический путь со слешем (задача 1) — адрес переадресации собирается в том же виде.
- Produces: таблица `share_sitemap_aliases`; `PageAliases::__construct(Db $db)`, `paths(): array<int,string>`,
  `remember(array $before): int`, `find(array $segments): ?array{id:int, rest:string[]}`.

```sql
-- sql/cut/stage17.sql, раздел 1 (повторяемый)
CREATE TABLE IF NOT EXISTS `share_sitemap_aliases` (
  `alias_path` varchar(255) NOT NULL,
  `smap_id` int(10) unsigned NOT NULL,
  `alias_date` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`alias_path`),
  KEY `smap_id` (`smap_id`),
  CONSTRAINT `share_sitemap_aliases_ibfk_1` FOREIGN KEY (`smap_id`) REFERENCES `share_sitemap` (`smap_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
```

- [ ] **Red:** `tests/page-aliases.php` (стенд — разделы `claude-pa*`, создаются и правятся через форму раздела
  `admin/structure/single/divEditor/save` как в `smoke-write.sh`, удаляются в конце и при сбое):
  1. раздел `claude-pa` с подразделом `claude-pa-child`; сегмент раздела → `claude-pa2`: гость `GET /claude-pa/` →
     301 на `/claude-pa2/`; `/claude-pa/claude-pa-child/` → 301 на `/claude-pa2/claude-pa-child/` (одна
     переадресация); `/claude-pa/?x=1` → `/claude-pa2/?x=1`; `/claude-pa/page-2/` → `/claude-pa2/page-2/`;
     второй язык `/ua/claude-pa/` → `/ua/claude-pa2/` (если открыт); `POST /claude-pa/` и JSON — не 301;
  2. перенос `claude-pa2` под `info`: `/claude-pa2/` и `/claude-pa/` → 301 сразу на `/info/claude-pa2/`;
  3. новый раздел с сегментом `claude-pa` в корне: `/claude-pa/` → 200 (страница), псевдонима `claude-pa` в базе нет;
     `/claude-pa/claude-pa-child/` → по-прежнему 301 на подраздел;
  4. у раздела снято право гостя (строка `share_access_level` группы гостей): гость со старого адреса → 404,
     администратор → 301; право возвращается;
  5. удаление (подраздел, раздел, новый раздел): строк `share_sitemap_aliases` этих страниц нет, `/claude-pa2/` → 404;
  6. `PageAliases::find` (консоль): самый длинный префикс, остаток — сегментами; пустой путь — null.
  FAIL (таблицы нет, старый адрес — 404).
- [ ] **Реализация.** `stage17.sql` на живую базу (дамп таблиц `share_sitemap*` перед этим — в scratchpad), затем
  `bash tests/tools/regen-sql.sh`; `PageAliases`; хук в `DivisionEditor::save`; `DocumentController::oldAddress()`
  в обработчике 404 (до сборки страницы ошибки) — `Response::setRedirect($url, 301)`. `smoke-write.sh`: после
  переноса `/claude-test/` → 301 на `/info/claude-test/`. `schema-fixture.php capture` (новая таблица — законное
  изменение схемы, снимок в том же коммите).
- [ ] **Green:** `page-aliases.php`, `smoke-write`, `schema-info`, `queries`, install/migration/fresh-check,
  регрессия, обход. Коммит.

### Task 3: Грид на CSS

**Files:** `core/modules/share/transformers/list.xslt`, `core/modules/share/stylesheets/admin.tailwind.css`
(+ `admin.css` через `setup css`), `core/modules/share/scripts/GridManager.js`, `tests/types/globals.d.ts`
(`ScrollBarWidth`), `tests/js-dead.php` (имена удалённого), `tests/audit/grids.js` (п. 3), `tests/audit/admin.js`
(селектор шапки).

**Interfaces:**
- Consumes: ничего из задач 1–2.
- Produces: разметка грида `div.grid > div.gridContainer > table.gridTable > (colgroup?) thead tbody`; заголовки —
  `.gridContainer thead th[name]`; CSS-переменная `--e-pane-top` у `.e-pane` грида на странице.

- [ ] **Red:** `grids.js` п. 3 — новые проверки: в гриде одна таблица (`.gridContainer table.gridTable` — 1,
  `.gridHeadContainer` нет), ширины `thead th` = ширинам ячеек первой строки (±1 px); у `.gridContainer` нет
  inline-высоты, высота (`getBoundingClientRect`) при окне 720 и 480 px отличается на 240 ± 2; после прокрутки списка
  вниз шапка на месте (верх `thead` = верх `.gridContainer` ± 1); строка с длинным значением без пробелов не делает
  таблицу шире контейнера; панель на странице `admin/translations/` растёт с окном (480 < 720 < 900); узкое окно
  390 px — таблица не шире окна. `js-dead.php` — имена `adjustColumns`, `fitGridSize`, `fitGridFormSize`,
  `scrollBarWidth`, `gridHeadContainer`, `gridBodyContainer`, `minGridHeight`, `ScrollBarWidth` не возвращаются.
  FAIL.
- [ ] **Реализация.** `list.xslt` — одна таблица; CSS (sticky, flex, перенос, `fixed_columns`, высота панели на
  странице); `GridManager.js` — без расчётов размеров, заголовки из `thead`, прокрутка к выбранной строке с учётом
  шапки; `setup css` от web97; `tests/css-build.sh`. `admin.js` — селектор `.gridTable thead th`.
- [ ] **Green:** `grids.js`, `admin.js`, `editors.js`, `jscheck.sh`, `js-dead.php`, `css-build.sh`, `xslt-golden`
  (разница — только разметка грида), регрессия, обход. Коммит.

### Task 4: Окна на `<dialog>`

**Files:** `core/modules/share/scripts/ModalBox.js`, `core/modules/share/stylesheets/admin.tailwind.css`
(+ `admin.css`), `tests/audit/admin.js` (окно формы, окно в окне), `tests/audit/grids.js` (Esc, затемнение).

**Interfaces:**
- Consumes: стили админки (задача 3 правила грида не трогает).
- Produces: окно — `dialog.e-modalbox` (открыт `showModal()`, `:modal`) с `iframe.e-modalbox-frame`; API ModalBox
  прежний (`open`, `close`, `getCurrent`, `getExtraData`, `setReturnValue`, `boxes`).

- [ ] **Red:** `admin.js`: окно — `dialog`, `:modal`, затемнение `::backdrop` (непрозрачность ≥ 0.4), в пределах
  окна браузера, рамка и тень; точка страницы вне окна (`elementFromPoint`) принадлежит окну — страница под ним
  недоступна мыши; страница под окном не прокручивается (`overflow` у `html` — hidden), после закрытия — снова
  прокручивается и фокус на прежнем элементе; окно в окне: два `dialog`, верхний — второй, затемнение у второго
  прозрачное. `grids.js`: Esc дважды подряд не закрывает окно (`dialog[open]` — 1), окно в окне и закрытие —
  `dialog[open]` 2 → 1 → 0, `.e-overlay` при окнах не появляется. FAIL.
- [ ] **Реализация.** `ModalBox.js` на `<dialog>` (без `Overlay`), CSS `::backdrop`, `html:has(…)`; `setup css`.
- [ ] **Green:** `admin.js`, `grids.js`, `editors.js` (окна картинки, репозитория, страницы, истории), `jscheck.sh`,
  `css-build.sh`, регрессия, обход. Коммит.

### Task 5: Свой ресайзер на GD

**Files:** `core/modules/share/gears/ImageResizer.php` (новый), `htdocs/resizer/timthumb.php` (точка входа),
`htdocs/resizer/timthumb-config.php` (удалить), `web/resizer/` (копия; `timthumb-config.php` удалить),
`web97/tmp/timthumb_*` (прежний кэш — удалить), `setup/Setup.php` (`setup check`: GD), `tests/resizer.php` (новый,
регрессия), `tests/perimeter.php` (вместо проверок `timthumb-config.php`), `tests/dev-tools.php` (строка GD).

**Interfaces:**
- Produces: `ImageResizer::__construct(string $webRoot, string $cacheDir)`, `source(string $src): ?string`,
  `static box(int $w, int $h, int $srcW, int $srcH): array{0:int,1:int,2:int,3:int,4:int,5:int}` (холст W, H; x, y,
  ширина, высота картинки на холсте), `respond(array $get, array $server): void`, `static defaultCacheDir(): string`.

```php
<?php // htdocs/resizer/timthumb.php — имя файла задаёт правило веб-сервера (docs/INSTALL.md), внутри — свой ресайзер
$web = dirname(__DIR__);
require realpath($web . '/../private/energine') . '/core/modules/share/gears/ImageResizer.php';
(new Energine\share\gears\ImageResizer($web, Energine\share\gears\ImageResizer::defaultCacheDir()))->respond($_GET, $_SERVER);
```

- [ ] **Red:** `tests/resizer.php` (картинки стенда — `web/uploads/claude-resizer/`, создаются GD, удаляются в конце
  вместе со своими записями кэша):
  - вид как у timthumb `zc=2`: `wide.jpg` 400×200 → `w40-h40` — JPEG 40×40, по краю сверху белое, в центре
    красное; `w100-h0` → 100×50; `w0-h50` → 100×50; `w0-h0` → 100×100; `w9999-h9999` → не больше 1500×1500;
    маленькая 20×10 → `w200-h100` — 200×100 (увеличение, как прежде);
  - форматы: PNG с прозрачностью → PNG, угол поля прозрачный (alpha 127); GIF → GIF; WebP → WebP;
  - кэш и HTTP: второй запрос — те же байты, `ETag` и `Last-Modified`, `Cache-Control` с `max-age=864000`;
    `If-None-Match` → 304 без тела; `If-Modified-Since` → 304; `HEAD` — заголовки без тела; файл заменён (другой
    цвет, новое время) → новый `ETag` и новая картинка;
  - отказы — 404 без текста ошибки и путей сервера: `src` вне `uploads/` (`index.php`, `system.config.php`),
    `uploads/../index.php`, `/etc/passwd`, `http://example.com/a.jpg`, каталог `uploads/claude-resizer/`,
    текстовый файл `fake.jpg`, символическая ссылка `uploads/claude-resizer/link.jpg` → `/etc/hostname`, несуществующий
    файл;
  - нет записи в кэш (подмена каталога кэша на недоступный — консольный вызов `respond` с буфером вывода) — картинка
    отдаётся;
  - `box()` (консоль): таблица случаев выше без GD.
  `perimeter.php`: копия `web/resizer/timthumb.php` = `htdocs/resizer/timthumb.php`, `timthumb-config.php` нет нигде.
  `dev-tools.php`: в `setup check` есть строка ресайзера с OK. FAIL (timthumb отвечает иначе: 304 нет, `w0-h0` …).
- [ ] **Реализация.** `ImageResizer` (холст `imagecreatetruecolor`; у PNG, GIF, WebP — прозрачная заливка и
  `imagesavealpha`, у JPEG — белая; `imagecopyresampled`; JPEG и WebP — качество 90; запись в кэш —
  `tempnam` + `rename`; сутки — метка `.cleaned`, удаление записей старше 30 дней; исходник больше 50 Мп — 404);
  точка входа; копия в `web/resizer/`, удаление `timthumb-config.php` и прежнего кэша; `setup check`.
- [ ] **Green:** `resizer.php`, `perimeter.php`, `dev-tools.php`, `smoke-final` (картинка демо через ресайзер),
  `smoke-write` (файл через ресайзер), аудиты editors (окно картинки, превью загрузки) и grids (миниатюры
  репозитория), регрессия, обход. Коммит.

### Task 6: Итог

- [ ] `docs/INSTALL.md`: адреса (слеш, 301 со старых адресов, таблица псевдонимов), ресайзер (своя точка входа под
  прежним именем, кэш, удалить `timthumb-config.php` при обновлении, `setup check`); `docs/OWNER.md`: переименование
  и перенос страницы не ломают старые ссылки; `tests/README.md`: наборы `urls`, `page-aliases`, `resizer`, проверки
  обхода, число наборов.
- [ ] Полный прогон (регрессия, обход, аудиты grids/editors/admin/public/theme, install/migration/fresh-check,
  `xslt-golden`), финальное ревью (Opus, Review Focus дословно), один проход исправлений, финиш (вариант 3).
