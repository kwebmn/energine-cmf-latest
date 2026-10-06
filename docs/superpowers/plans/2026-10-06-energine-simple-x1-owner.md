# Energine Simple — идеи xsight для владельца. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (инлайн). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Владелец меньше ошибается и меньше гадает: битые ссылки не ведут посетителя на 404 и видны администратору на
странице, используемый файл не удаляется молча, новая страница раздела сразу с нужным шаблоном и подсказкой,
переключатель языка не ведёт в 404, у страницы-ссылки цель выбирается из дерева и репозитория.

**Разведка (2026-10-06):**
- Текст блока (`TextBlock::main`) берётся из `pageBlocks()` и уходит в XML как поле `htmlblock`; в режиме правки
  (`Document::isEditable`: право > 2 и `editMode` — POST, при отладке и GET) Jodit сохраняет HTML блока обратно, поэтому
  разметку можно менять только вне режима правки. Дерево посетителя (`Sitemap`, `E()->getMap()`) уже загружено и
  содержит только видимые ему и включённые на языке страницы; `Sitemap::getIDByURI` меняет смещение пути запроса —
  для проверки ссылок нужен чистый поиск. Отчёт «Битые ссылки» (`LinkChecker`) разбирает тексты одним запросом, умеет
  `referrers()` для страниц; для файлов — нет.
- `FileRepository::delete` удаляет записи и файлы без проверки использования; страницы (`DivisionEditor::delete`)
  отвечают `{result: true, mode: 'confirm', confirm}` и `DivManager` повторяет запрос с `?confirm=1`;
  `GridManager.del` такого режима не знает.
- Форма новой страницы (`DivisionEditor::add`): списки макетов и шаблонов из `loadTemplateData()` (имена — константы
  `CONTENT_*`, `LAYOUT_*`; у варианта атрибуты `data-segment`, `data-layout`, `unique`), значение по умолчанию не
  задано — выбирается первый по алфавиту. Атрибуты вариантов попадают в `<option>` (`fields.xslt`).
- `LangSwitcher` строит адрес другого языка как префикс языка + путь запроса — на странице, выключенной на том языке,
  и на странице ошибки он ведёт в 404. `Response` кода ответа не отдаёт.
- Поле `smap_redirect_url` у страницы есть; меню (`energine.xslt`, `PageList` — `Redirect`) ставит его прямо в
  ссылку пункта; в форме — обычное текстовое поле. Выбор страницы (`page-tree/list/`, `DataSet::pageTree`) и файла
  (`file-library/`) уже есть у редактора текста и форм.

**Architecture:**
- **`TextLinks`** (гир): `forRequest()` — из дерева посетителя, `PageAliases`, корня сайта и префиксов языков;
  `reason(string $link): ?string` — `'page'` (страницы нет для этого посетителя и старого адреса нет), `'file'`
  (локального файла нет; адрес ресайзера — по файлу-источнику) или null (рабочая или не проверяется: внешняя, якорь,
  `mailto:`, другой язык); `filter(string $html, bool $mark, array $titles): string` — гостю ссылка заменяется своим
  содержимым, картинка удаляется; при `$mark` — класс `e-broken-link` / `e-broken-image` и `title` причины; HTML без
  находок возвращается тем же (разбор DOM — только когда есть что менять). `Sitemap::findIDByPath(array $segments):
  ?int` — чистый поиск страницы по полному пути. `TextBlock::main`: вне режима правки — `filter($content, право > 2)`.
  Стили пометок — `admin.tailwind.css` (админка грузит его только администратору).
- **Защита файлов:** `LinkChecker::fileReferrers(array $paths): array` — путь файла или папки → страницы, в текстах
  которых ссылка (`href`/`src`, любой вид адреса, в том числе ресайзер; у папки — файлы внутри); `FileRepository::delete`
  без `?confirm=1` при находках — `{result: true, mode: 'confirm', confirm: MSG_FILE_LINKED + страницы}`;
  `GridManager.del` — вопрос и повтор с `?confirm=1`.
- **Шаблон по умолчанию:** `DivisionEditor::childTemplates(int $pid): array{0: ?string, 1: ?string}` — самые частые
  макет и шаблон у подстраниц раздела, иначе `default.layout.xml` и `textblock.content.xml`; «уникальные» и выключенные
  варианты не выбираются. Подсказка шаблона — атрибут `data-hint` из константы `HINT_CONTENT_<ИМЯ>` (если есть) и
  строка под списком (`DivForm`), меняется при выборе.
- **Переключатель языка:** `Response::getStatusCode(): int`; `LangSwitcher` — адрес главной языка, если код ответа не
  2xx или страница либо её родитель выключены на этом языке (один запрос по странице и родителям).
- **Страница-ссылка:** шаблон поля `smap_redirect_url` формы раздела (`divisionEditor.xslt`) — поле и кнопки
  «Страница…», «Файл…»; `DivForm` открывает `page-tree/list/` (адрес — `Energine.root` + сегмент) и `file-library/`
  (`/` + путь файла); меню: внешний адрес (`http(s)://` не этого сайта) — `target="_blank" rel="noopener"`.
- Константы — `sql/cut/stage18.sql` (повторяемый), файлы установки — `tests/tools/regen-sql.sh`.

**Tech Stack:** PHP 8.5 (DOM), XSLT 1.0, ES-модули, Tailwind v4 (`setup css`), Playwright.

**Spec:** `docs/superpowers/specs/2026-10-06-energine-simple-xsight-ideas-design.md`.

## Global Constraints

- Поведение меняется только там, где этап это называет: битые ссылки и картинки в текстовых блоках (гостю — текст,
  администратору вне правки — пометка), вопрос при удалении используемого файла, выбранные заранее шаблоны новой
  страницы и подсказка, адрес переключателя языка, кнопки у поля переадресации, внешние пункты меню в новой вкладке.
  Текст в режиме правки не меняется. `xslt-golden` — разница только в ожидаемых местах.
- Запросов на страницу не больше бюджета `tests/queries.php` (гость 20, администратор 30): проверка ссылок — по уже
  загруженному дереву, старые адреса — один запрос и только при непроверенных ссылках; переключатель — один запрос.
- Общие правила: конфиги веб-сервера не трогаются; владелец `web97:client1`; пароли не в git и не в выводе; письма только
  локально; web93 и web94 только читаются; `rebuild.sh` не запускается; `setup` — от web97; новые скрипты модулей —
  `setup linker`. Правки PHP в живом дереве — сначала добавить, потом переключить; после правки — `php8.5 -l` и ответ
  главной и админки; после правки файла через sed/perl — `bash -n` или `php8.5 -l` и начало файла (урок этапа 5).
- Полный прогон после каждой задачи; регрессия считает и упавшие наборы (`suite`).

## Review Focus

1. **Текст не портится:** в режиме правки HTML блока — байт в байт из базы; ссылка с вложенной разметкой
   (`<b>`, картинка) при замене на текст сохраняет содержимое; кириллица, сущности (`&amp;`, `&nbsp;`), атрибуты и
   самозакрывающиеся теги в остальном тексте не искажаются; HTML без битых ссылок не разбирается вовсе.
2. **Рабочие ссылки не прячутся:** старый адрес (301), ссылка на другой язык, корень, ссылка со строкой запроса и якорем,
   внешняя, `mailto:`/`tel:`, файл через ресайзер, относительная ссылка — остаются ссылками; страница, закрытая от
   гостя, — гостю текстом, администратору — ссылкой.
3. **Удаление файла:** использование находится при любом виде адреса (абсолютный своего сайта, от корня, относительный,
   через ресайзер, `%20`); папка с используемым файлом внутри; выделение из нескольких файлов; неиспользуемый файл
   удаляется сразу, как прежде; отказ ничего не удаляет.
4. **Шаблон новой страницы:** «уникальный» шаблон (главная) не выбирается заранее; раздел без подстраниц — текстовая
   страница; выбранный шаблон сразу ставит свой макет и сегмент (как при ручном выборе); подсказка меняется при выборе.
5. **Переключатель и меню:** выключен родитель на другом языке; страница 404 и 403; хвост пути на доступной странице
   (`page-2/`) сохраняется; язык «в подготовке» гостю не показывается (как прежде); внутренний адрес переадресации в
   меню — без новой вкладки.

Проверки: п. 1–2 — `tests/text-links.php`; п. 3 — `tests/file-guard.php`, `tests/audit/grids.js`; п. 4 —
`tests/page-templates.php`, `tests/audit/grids.js`; п. 5 — `tests/lang-switcher.php`, `tests/page-link.php`,
`tests/audit/editors.js`.

---

### Task 1: Битые ссылки на странице

**Files:** `core/modules/share/gears/TextLinks.php` (новый), `core/modules/share/gears/Sitemap.php` (`findIDByPath`),
`core/modules/share/components/TextBlock.php` (`main`), `core/modules/share/stylesheets/admin.tailwind.css`
(+ `admin.css`), `sql/cut/stage18.sql` (новый: `TXT_BROKEN_LINK_PAGE`, `TXT_BROKEN_LINK_FILE`), файлы установки
(regen), `tests/text-links.php` (новый, регрессия).

**Interfaces:**
- Produces: `TextLinks::forRequest(): TextLinks`, `reason(string $link): ?string` (`'page'`|`'file'`|null),
  `filter(string $html, bool $mark, array $titles): string`; `Sitemap::findIDByPath(array $segments): ?int`; классы
  `e-broken-link`, `e-broken-image`.

- [ ] **Red:** `tests/text-links.php` (стенд: страница `claude-tl` с текстом, закрытая от гостя `claude-tl-closed`,
  старый адрес `claude-tl-old` → info, файлы `web/uploads/claude-tl/ok.pdf`, `ok.jpg`; всё удаляется в конце):
  - гость: `/info/`, `/info/?x=1#y`, `#top`, `mailto:`, `https://example.com/`, `/ua/claude-tl-nope/`, `ok.pdf`,
    `/resizer/w10-h10/uploads/claude-tl/ok.jpg`, старый адрес — ссылки; `/claude-tl-nope/` (с `<b>` внутри),
    `/claude-tl-closed/`, `/uploads/claude-tl-missing.pdf` — текст без ссылки, содержимое на месте; картинки
    `claude-tl-missing.jpg` нет; кириллица и `&amp;` на месте;
  - администратор вне правки: битая — ссылка с `class="e-broken-link"` и `title`, закрытая — обычная ссылка, картинка —
    `e-broken-image`;
  - режим правки (`?editMode` при отладке): HTML блока равен тексту из базы;
  - `TextLinks` в консоли: `reason()` по таблице случаев, `filter()` без находок возвращает строку без изменений.
  FAIL.
- [ ] **Реализация.** `stage18.sql` раздел 1 → живая база, `regen-sql.sh`; `Sitemap::findIDByPath`; `TextLinks`;
  хук в `TextBlock::main`; стили; `setup css`.
- [ ] **Green:** `text-links.php`, `queries.php`, `xslt-golden` (разница — только где были битые ссылки), регрессия,
  обход, аудит editors. Коммит.

### Task 2: Используемый файл не удаляется молча

**Files:** `core/modules/share/gears/LinkChecker.php` (`fileReferrers`), `core/modules/share/components/FileRepository.php`
(`delete`), `core/modules/share/scripts/GridManager.js` (`del`), `sql/cut/stage18.sql` (раздел 2: `MSG_FILE_LINKED`),
`tests/file-guard.php` (новый, регрессия), `tests/audit/grids.js` (вопрос в окне).

**Interfaces:**
- Consumes: ничего из задачи 1.
- Produces: `LinkChecker::fileReferrers(array $paths): array<string, string[]>`; ответ удаления
  `{result: true, mode: 'confirm', confirm: string}`.

- [ ] **Red:** `tests/file-guard.php` (стенд: папка `uploads/claude-fg/` с записями репозитория, файлы `used.pdf`,
  `pic.jpg`, `free.pdf`, страница `claude-fg` с текстом: `href` на `used.pdf` абсолютным адресом сайта, `img` через
  ресайзер на `pic.jpg`):
  - `fileReferrers` (консоль): все виды адреса (абсолютный своего сайта, от корня, относительный, ресайзер, `%20`);
    папка — по файлам внутри;
  - администратор: удаление `used.pdf` — `mode: confirm`, в тексте вопроса путь страницы, файл и запись на месте; с
    `?confirm=1` — удалены; `free.pdf` — удалён сразу; выделение `pic.jpg,free.pdf` — вопрос, ничего не удалено; папка —
    вопрос.
  `grids.js`: ответ удаления подменён на `mode: confirm` — появляется вопрос с его текстом, «ОК» — повторный запрос с
  `?confirm=1`, «Отмена» — второго запроса нет. FAIL.
- [ ] **Реализация.** `fileReferrers`; `FileRepository::delete`; `GridManager.del`; константа (раздел 2 → живая база,
  regen).
- [ ] **Green:** `file-guard.php`, аудит grids, регрессия, обход. Коммит.

### Task 3: Шаблон по умолчанию для подстраниц и подсказка шаблона

**Files:** `core/modules/share/components/DivisionEditor.php` (`add`, `childTemplates`, `loadTemplateData`),
`core/modules/share/scripts/DivForm.js` (подсказка), `sql/cut/stage18.sql` (раздел 3: `HINT_CONTENT_LANDING`,
`_SERVICE`, `_CONTACTS`, `_TEXTBLOCK`, `_CHILDS`, `_MAP`, `_MAIN` — ru, ua), `tests/page-templates.php` (новый,
регрессия), `tests/audit/grids.js` (подсказка меняется при выборе).

**Interfaces:**
- Produces: `DivisionEditor::childTemplates(int $pid): array{0: ?string, 1: ?string}` (макет, шаблон); атрибут варианта
  `data-hint`; элемент подсказки `.e-template-hint` под списком шаблонов.

- [ ] **Red:** `tests/page-templates.php` (стенд: раздел `claude-pt` с подстраницами — две «Услуга», одна «Текстовая»;
  пустой раздел `claude-pt-empty`): форма добавления в `claude-pt` — выбран `service.content.xml` и его макет; в
  `claude-pt-empty` — `textblock.content.xml` и `default.layout.xml`; «уникальный» `main.content.xml` не выбран ни
  в одной форме; у вариантов landing, service, contacts, textblock, childs, map — `data-hint` с текстом, не именем
  константы. `grids.js`: в окне новой страницы под шаблоном — подсказка выбранного, смена шаблона меняет подсказку.
  FAIL.
- [ ] **Реализация.** `childTemplates` и значения по умолчанию в `add`; `data-hint` в `loadTemplateData`; подсказка в
  `DivForm`; константы (раздел 3 → живая база, regen).
- [ ] **Green:** `page-templates.php`, аудит grids, регрессия, обход. Коммит.

### Task 4: Переключатель языка без 404

**Files:** `core/modules/share/gears/Response.php` (`getStatusCode`), `core/modules/share/components/LangSwitcher.php`,
`tests/lang-switcher.php` (новый, регрессия).

**Interfaces:**
- Produces: `Response::getStatusCode(): int`; адрес переключателя — главная языка при недоступной странице.

- [ ] **Red:** `tests/lang-switcher.php` (стенд: `claude-ls` включена на ru, выключена на ua; её подстраница
  `claude-ls/child` включена на обоих; `claude-ls2` — выключена на ru, включена на ua): на `/claude-ls/` ссылка на ua —
  `/ua/`; на `/claude-ls/child/` — `/ua/` (выключен родитель); на `/info/` — `/ua/info/`; на `/ua/claude-ls2/` ссылка на
  ru — `/`; на 404 `/claude-ls-nope/` — `/ua/`; язык «в подготовке» гостю не показывается (если второй язык закрыт —
  SKIP). FAIL.
- [ ] **Реализация.** `getStatusCode`; доступность страницы на языках в `LangSwitcher`.
- [ ] **Green:** `lang-switcher.php`, `lang-inactive.php`, `queries.php`, регрессия, обход (гость на двух языках). Коммит.

### Task 5: Страница-ссылка

**Files:** `core/modules/share/transformers/divisionEditor.xslt` (поле `smap_redirect_url`), `core/modules/share/scripts/DivForm.js`
(`pickRedirectPage`, `pickRedirectFile`), `site/modules/main/transformers/energine.xslt` (внешние пункты меню),
`sql/cut/stage18.sql` (раздел 4: `BTN_PICK_PAGE`, `BTN_PICK_FILE`), `tests/page-link.php` (новый, регрессия),
`tests/audit/editors.js` (кнопки в форме раздела).

**Interfaces:**
- Consumes: окна `page-tree/list/` и `file-library/` (как у редактора текста).
- Produces: кнопки `button.pick-redirect-page`, `button.pick-redirect-file` у поля `smap_redirect_url`.

- [ ] **Red:** `tests/page-link.php` (стенд: страницы в меню `claude-pl-ext` с адресом `https://example.com/claude`,
  `claude-pl-int` с `/info/`): в меню главной у внешней — `target="_blank"` и `rel="noopener"`, у внутренней — нет;
  форма правки страницы — поле и обе кнопки. `editors.js`: «Страница…» — окно дерева, выбор страницы ставит
  `/<сегмент>/`; «Файл…» — репозиторий, выбор файла ставит `/uploads/…`; форма сохраняется с этим адресом. FAIL.
- [ ] **Реализация.** Шаблон поля, обработчики `DivForm`, меню, константы (раздел 4 → живая база, regen).
- [ ] **Green:** `page-link.php`, аудиты editors и grids, регрессия, обход. Коммит.

### Task 6: Итог

- [ ] `docs/OWNER.md` (битые ссылки: гость не видит, администратор видит пометку; вопрос при удалении используемого
  файла; шаблон новой страницы и подсказка; страница-ссылка с выбором цели), `docs/INSTALL.md` (`stage18.sql`),
  `tests/README.md` (наборы `text-links`, `file-guard`, `page-templates`, `lang-switcher`, `page-link`).
- [ ] Полный прогон (регрессия, обход, аудиты grids/editors/admin/public/theme, install/migration/fresh-check,
  `xslt-golden`), финальное ревью (Opus, Review Focus дословно), один проход исправлений, финиш (вариант 3).
