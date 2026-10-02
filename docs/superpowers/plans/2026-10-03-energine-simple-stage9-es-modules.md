# Этап 9 — ES-модули вместо ScriptLoader и карты зависимостей: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** скрипты ядра — ES-модули с `import`/`export`; страницы подключают их через import map с версиями файлов;
`ScriptLoader`, `system.jsmap.php`, `setup scriptMap` и разрешение зависимостей в `Document.php` удалены.

**Architecture:** `Document.php` отдаёт в `/document/javascript` список всех модулей (`module name version`) и поведения;
`document.xslt` выводит `<script type="importmap">`, модуль настройки `Energine` и модуль запуска поведений (импорт
классов поведений страницы, затем прежний обработчик `DOMContentLoaded`, экземпляры — `window[id]`); встроенные скрипты
шаблонов (переводы, панели) — модули. Каждый файл ядра импортирует то, чем пользуется (таблица задачи 2); глобальны
только `Energine`, `ModalBox`, `componentToolbars`, экземпляры поведений, `document.FileRepository`,
`window.ScrollBarWidth`, `Jodit` (сам).

**Tech Stack:** браузерный JavaScript (ES-модули, import map), XSLT 1.0, PHP 8.5, Playwright-аудиты, `tests/no-traces.sh`.

**Spec:** `docs/superpowers/specs/2026-10-03-energine-simple-stage9-es-modules-design.md`

## Global Constraints

- Клон `/var/www/clients/client1/web97/private/stage9/energine`, ветка `main`; стенд —
  `STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start` (из клона), команды —
  `bash tests/tools/stand.sh run …`; ссылки стенда после изменений `web/scripts` — от web97
  `php8.5 /tmp/stand-web97/site/web/index.php setup linker`.
- Коммиты — `bash tests/tools/stand.sh run git commit -q -m "…" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`;
  после git-операций от root — `chown -R web97:client1 /var/www/clients/client1/web97/private/stage9`.
- Модули — строгий режим: никаких присваиваний необъявленным переменным; повторный `import` одного имени — ошибка.
- В комментариях скриптов не писать примеров `import … from` с именем в кавычках, которых нет в коде (проверка
  `modules` читает код без комментариев, но держим чисто).
- Проверки на площадке ничего не меняют в данных сверх прежнего; база не меняется; адрес new.energine.org нигде не
  упоминается; пароли и `configs/system.config.*.php` не выводятся.
- **Выкладка на площадку — только после «да» владельца** (разрешение «без остановок» было для этапа 8).

## Review Focus

1. Порядок выполнения: настройка `Energine` → переводы (модули в теле) → запуск поведений и привязка панелей
   (`DOMContentLoaded`) — как при классических скриптах; панель страницы администратора и правка на странице.
2. Окна: `window.top.ModalBox` из модуля `ModalBox` каждого окна — общая очередь; ответы окон гридам и формам.
3. Строгий режим модулей: код вне классов (объекты `Energine`, `ModalBox`, `EnergineEditor`, функции `Energine.*`),
   `this` в обработчиках, присваивания глобальным именам.
4. Import map: имена с `/` (`jodit/jodit.min`), версии всех файлов, ни одного запроса без `?v=`; поведение с путём
   (`behavior path`).
5. Страницы без поведений (гость на главной), страница ошибки, режим одной записи (`single`), режим правки.

---

## Task 1: Проверки

**Files:**
- Create: `tests/tools/module-imports.php`
- Modify: `tests/no-traces.sh` (категория `modules`)
- Modify: `tests/audit/public.js` (запросы скриптов — с версией; import map; версия — время файла), `tests/audit/public-db.php`
  (команда `mtime NAME`)
- Modify: `tests/audit/grids.js` (классы не глобальны; классы в проверках этапа 8 — через `import()`),
  `tests/audit/editors.js` (блок 24 — `Form` через `import()`)

**Interfaces:**
- Produces: красные до переделки — `no-traces modules`; в `public` — «скрипты — модули из import map» на каждой странице
  и «версия модуля — время изменения файла»; в `grids` — «админка: классы не глобальны, договор страницы на месте».

- [ ] **Step 1: module-imports.php.**

Full file `tests/tools/module-imports.php`:
```php
<?php
// Модули ядра (этап 9): каждый скрипт ядра и сайта, кроме Jodit, — ES-модуль (есть export); имя, которое
// экспортирует один модуль, а пользуется им другой, импортировано этим другим.
// Запуск: php8.5 tests/tools/module-imports.php [корень проекта]. Печатает нарушения; выход 0 — нарушений нет.
$root = rtrim($argv[1] ?? dirname(__DIR__, 2), '/');
$files = array_merge(glob("$root/core/modules/*/scripts/*.js") ?: [], glob("$root/site/modules/*/scripts/*.js") ?: []);
if (!$files) {
    fwrite(STDERR, "скрипты ядра не найдены\n");
    exit(2);
}
// код без комментариев и содержимого строк: имена в них не считаются
$code = function ($file) {
    $src = file_get_contents($file);
    $src = preg_replace('~/\*.*?\*/~s', ' ', $src);
    $src = preg_replace('~(?<![:\\\\])//[^\n]*~', ' ', $src);
    return preg_replace(['~\'(?:\\\\.|[^\'\\\\\n])*\'~', '~"(?:\\\\.|[^"\\\\\n])*"~', '~`(?:\\\\.|[^`\\\\])*`~s'], ["''", '""', '``'], $src);
};
$rel = fn($f) => substr($f, strlen($root) + 1);
$exports = [];
$bad = [];
foreach ($files as $f) {
    $c = $code($f);
    if (!preg_match('~^export\s~m', $c)) {
        $bad[] = $rel($f) . ': не модуль (нет export)';
    }
    preg_match_all('~^export\s+(?:class|const|function)\s+(\w+)~m', $c, $m);
    foreach ($m[1] as $name) {
        $exports[$name] = $f;
    }
}
foreach ($files as $f) {
    $c = $code($f);
    preg_match_all('~^import\s*\{([^}]*)\}\s*from~m', $c, $m);
    $imported = array_filter(array_map('trim', explode(',', implode(',', $m[1]))));
    foreach ($exports as $name => $src) {
        if ($src !== $f && preg_match('~(?<![\w.$])' . preg_quote($name, '~') . '\b~', $c) && !in_array($name, $imported, true)) {
            $bad[] = $rel($f) . ": $name не импортирован";
        }
    }
}
echo $bad ? implode("\n", $bad) . "\n" : '';
exit($bad ? 1 : 0);
```

- [ ] **Step 2: no-traces.sh — категория `modules`.**
  - в список категорий (строка `ckeditor fileapi jsonp … mootools i18n)`) добавить `modules` после `mootools`;
  - в шапку: `# Этап 9 — ES-модули: modules (нет ScriptLoader и карты зависимостей; скрипты — модули, имена других
    модулей импортированы)`;
  - перед `# содержимое сайта:` добавить `MODULES_CODE='ScriptLoader|system\.jsmap|scriptMap'`;
  - перед `elif [ "$m" = mail-core ]; then` в ветке кода:

```bash
    elif [ "$m" = modules ]; then
      found=$(G "$MODULES_CODE" --include='*.js' --include='*.php' --include='*.xslt' --exclude-dir=jodit core site setup \
        | cut -c1-160)
      imports=$(php8.5 "$R/tests/tools/module-imports.php" "$R" 2>&1); rc=$?
      [ $rc -gt 1 ] && imports="__GREPERROR__ $imports"
      [ -n "$imports" ] && found+=$'\n'"$imports"
```

- [ ] **Step 3: public-db.php** — команда `mtime`:

```php
    case 'mtime':
        echo filemtime(WEB . '/scripts/' . $argv[2] . '.js');
        break;
```

  (и строка в шапке: `//   php8.5 public-db.php mtime NAME — время изменения web/scripts/NAME.js`).

- [ ] **Step 4: public.js.**
  - в `open()`: `const log = { moo: [], errors: [], posts: [], scripts: [] };` и в обработчике `request`:
    `if (/\/scripts\/[^?#]+\.js([?#]|$)/.test(r.url())) log.scripts.push(r.url());`
  - в `inspect` добавить `map`:

```js
    const mapEl = document.querySelector('script[type="importmap"]');
    let imports = null;
    try { imports = mapEl ? JSON.parse(mapEl.textContent).imports : null; } catch (e) { }
    const map = { present: !!imports, energine: !!(imports && imports.Energine),
        versioned: !!imports && Object.values(imports).every((u) => /\.js\?v=\d+$/.test(u)),
        classic: [...document.querySelectorAll('script[src]')].filter((s) => /\/scripts\//.test(s.src)).length,
        loader: typeof window.ScriptLoader };
```

    и вернуть его полем `map`;
  - в `pageChecks` проверку версии заменить сетевой и добавить проверку модулей:

```js
    check(`${who} /${url}: скрипты сайта — с версией ?v=`, log.scripts.length > 0
        && log.scripts.every((u) => /\.js\?v=\d+$/.test(u)), log.scripts.filter((u) => !/\.js\?v=\d+$/.test(u)).join(' ') || 'скриптов нет');
    check(`${who} /${url}: скрипты — модули из import map`, r.map.present && r.map.energine && r.map.versioned
        && r.map.classic === 0 && r.map.loader === 'undefined', JSON.stringify(r.map));
```

  - после блока `1a.` (файлы MooTools — 404):

```js
        // 1b. the version of a module in the import map is the time of its file (stage 9)
        {
            const p = await guest.newPage();
            await p.goto(BASE, { waitUntil: 'networkidle' });
            const url = await p.evaluate(() => {
                const el = document.querySelector('script[type="importmap"]');
                try { return el ? JSON.parse(el.textContent).imports.Validator : ''; } catch (e) { return ''; }
            });
            const mtime = db('mtime', 'Validator').trim();
            check('версия модуля в import map — время изменения файла', !!url && url.endsWith('Validator.js?v=' + mtime), `${url} / ${mtime}`);
            await p.close();
        }
```

- [ ] **Step 5: grids.js.**
  - классы в проверках этапа 8 — через `import()`, если их нет в `window`:
    - проверка «дерево страниц: имя с разметкой — текстом»: `p.evaluate((payload) => {` → `p.evaluate(async (payload) => {`,
      строка `if (!window.TreeView) return { error: 'no TreeView' };` → `const TreeView = window.TreeView || (await import('TreeView')).TreeView;`;
    - проверка затемнения: перед `const overlay = new Overlay(box);` — `const Overlay = window.Overlay || (await import('Overlay')).Overlay;`;
    - проверка узлов дерева: перед `const tree = new TreeView(ul, {});` — `const TreeView = window.TreeView || (await import('TreeView')).TreeView;`
      (функция — `async`);
    - проверка кнопок панели: `ap.evaluate(() => {` → `ap.evaluate(async () => {`, перед `const tb = new Toolbar('claude_tb');` —
      `const Toolbar = window.Toolbar || (await import('Toolbar')).Toolbar;`;
  - новая проверка в начале блока шага 7 (перед `// ===== stage 8, step 7`):

```js
        // ===== stage 9: ES modules — the classes are not global, the page contract is
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const g = await p.evaluate(() => ({
                classes: ['Form', 'GridManager', 'Grid', 'Toolbar', 'TabPane', 'TreeView', 'Overlay', 'PageToolbar', 'ScriptLoader']
                    .filter((n) => n in window),
                contract: ['Energine', 'ModalBox', 'componentToolbars'].filter((n) => !(n in window)),
            }));
            check('админка: классы не глобальны, договор страницы на месте', !g.classes.length && !g.contract.length, JSON.stringify(g));
            check('админка, модули: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }
```

- [ ] **Step 6: editors.js** (блок 24): `const qs = await p.evaluate(() => {` → `const qs = await p.evaluate(async () => {`;
  строка `const result = (window.Form && Form.toQueryString) ? Form.toQueryString(fx) : fx.toQueryString();` →
  `const Form = window.Form || (await import('Form')).Form;` и `const result = Form.toQueryString(fx);`.

- [ ] **Step 7: Стенд и прогон до переделки.**

Run: `STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start; bash tests/tools/stand.sh run bash tests/no-traces.sh code modules; cd tests/audit && for t in public grids editors; do …; done`
Expected: `no-traces modules` — FAIL (ScriptLoader, «не модуль»); `public` — FAIL у «скрипты — модули из import map»
(каждая страница) и «версия модуля …»; `grids` — FAIL «админка: классы не глобальны …»; `editors` — 0; остальное — OK.

- [ ] **Step 8: Commit** — «Этап 9: проверки — модули из import map, версии файлов, классы не глобальны, импорты модулей».

## Task 2: Модули

**Files:**
- Modify: все 29 файлов `core/modules/share/scripts/*.js` и `core/modules/user/scripts/*.js` (без `jodit/`)
- Modify: `core/modules/share/gears/Document.php` (список модулей вместо карты)
- Modify: `core/modules/share/transformers/document.xslt`, `list.xslt`, `divisionEditor.xslt`, `toolbar.xslt`, `file.xslt`

**Interfaces:**
- Produces: модули с экспортами таблицы; `/document/javascript/module[@name][@version]`; глобальные имена договора.

- [ ] **Step 1: Скрипты.** В каждом файле строка `ScriptLoader.load(…);` (если есть) заменяется блоком импортов из
  таблицы (в том же месте, по строке на имя, в порядке таблицы); объявления — как в колонке «Экспорт». Комментарии
  `@requires` остаются. Остальной код не меняется.

| Файл | Импорты (вместо `ScriptLoader.load`; если вызова нет — после шапки `@file`) | Экспорт и глобальные имена |
|---|---|---|
| `Energine.js` | — | удалить `var ScriptLoader = {…};` с его комментарием; `var Energine =` → `export const Energine =`; в конце файла `window.Energine = Energine;` |
| `Validator.js` | — | `var Validator = class` → `export class` (так и далее: `var X = class X` → `export class X`) |
| `ValidForm.js` | `import {Validator} from 'Validator';` | `export class ValidForm` |
| `LoginForm.js` | `import {ValidForm} from 'ValidForm';` | `export class LoginForm` |
| `Register.js` | `import {Energine} from 'Energine';` `import {ValidForm} from 'ValidForm';` | `export class Register` |
| `UserProfile.js` | `import {ValidForm} from 'ValidForm';` | `export class UserProfile` |
| `Overlay.js` | — | `export class Overlay` |
| `ModalBox.js` | `import {Energine} from 'Energine';` `import {Overlay} from 'Overlay';` | `var ModalBox =` → `export const ModalBox =`; в конце `window.ModalBox = ModalBox;` |
| `TabPane.js` | `import {Energine} from 'Energine';` | `export class TabPane` |
| `PageList.js` | `import {Energine} from 'Energine';` | `export class PageList` |
| `Toolbar.js` | `import {Energine} from 'Energine';` | `export class Toolbar` |
| `PageToolbar.js` | `import {Energine} from 'Energine';` `import {Toolbar} from 'Toolbar';` `import {ModalBox} from 'ModalBox';` | `export class PageToolbar` |
| `Filters.js` | — | `var FiltersFabric = class` → `class`; `var Filters = class` → `export class`; `var Filter = class` → `class` |
| `TreeView.js` | `import {Energine} from 'Energine';` | `export class TreeView` |
| `EnergineEditor.js` | `import 'jodit/jodit.min';` `import {Energine} from 'Energine';` `import {ModalBox} from 'ModalBox';` | `var EnergineEditor =` → `export const EnergineEditor =` |
| `PageEditor.js` | `import {Energine} from 'Energine';` `import {EnergineEditor} from 'EnergineEditor';` | `export class PageEditor` |
| `Form.js` | `import {Energine} from 'Energine';` `import {EnergineEditor} from 'EnergineEditor';` `import {TabPane} from 'TabPane';` `import {Validator} from 'Validator';` `import {ModalBox} from 'ModalBox';` `import {Overlay} from 'Overlay';` | `export class Form` |
| `DivForm.js` | `import {Energine} from 'Energine';` `import {Form} from 'Form';` | `export class DivForm` |
| `GroupForm.js` | `import {Form} from 'Form';` | `export class GroupForm` |
| `ImageManager.js` | `import {Energine} from 'Energine';` `import {Form} from 'Form';` `import {ModalBox} from 'ModalBox';` | `export class ImageManager` |
| `FileRepoForm.js` | `import {Energine} from 'Energine';` `import {Form} from 'Form';` | `export class FileRepoForm` |
| `GridManager.js` | `import {Energine} from 'Energine';` `import {TabPane} from 'TabPane';` `import {PageList} from 'PageList';` `import {Overlay} from 'Overlay';` `import {ModalBox} from 'ModalBox';` `import {Filters} from 'Filters';` | `export class Grid`, `export class GridManager` |
| `FileRepository.js` | `import {Energine} from 'Energine';` `import {Grid, GridManager} from 'GridManager';` `import {ModalBox} from 'ModalBox';` | `var FILE_COOKIE_NAME =` → `const FILE_COOKIE_NAME =`; `export class FileRepository`; `var PathList = class` → `class` |
| `UserManager.js` | `import {Energine} from 'Energine';` `import {GridManager} from 'GridManager';` | `export class UserManager` |
| `ActionLogManager.js` | `import {Energine} from 'Energine';` `import {GridManager} from 'GridManager';` | `export class ActionLogManager` |
| `DivManager.js` | `import {Energine} from 'Energine';` `import {TabPane} from 'TabPane';` `import {ModalBox} from 'ModalBox';` `import {TreeView} from 'TreeView';` | `export class DivManager` |
| `DivSidebar.js` | `import {Energine} from 'Energine';` `import {DivManager} from 'DivManager';` `import {TreeView} from 'TreeView';` | `export class DivSidebar` |
| `DivTree.js` | `import {DivManager} from 'DivManager';` | `export class DivTree` |
| `getDirsTree.js` | `import {Energine} from 'Energine';` `import {DivManager} from 'DivManager';` `import {TreeView} from 'TreeView';` | `export class getDirsTree` |

- [ ] **Step 2: Document.php.** Блок от комментария `// скрипты страницы и их зависимости …` до конца метода (перед
  `/** Check if the component editable.`) заменить на:

```php
        // модули страницы: поведения компонентов и все скрипты web/scripts для import map (имя → время файла:
        // после обновления браузер не возьмёт из кэша прежний файл ни у страницы, ни у её зависимостей)
        $dom_javascript = $this->doc->createElement('javascript');
        $dom_root->appendChild($dom_javascript);
        foreach ($this->js as $behavior) {
            $dom_javascript->appendChild($this->doc->importNode($behavior, true));
        }
        foreach ($this->scriptModules() as $name => $version) {
            $dom_module = $this->doc->createElement('module');
            $dom_module->setAttribute('name', $name);
            $dom_module->setAttribute('version', $version);
            $dom_javascript->appendChild($dom_module);
        }
    }

    /**
     * Модули для import map: файлы .js в web/scripts (ссылки на скрипты модулей и Jodit) — имя (путь без .js) →
     * время изменения файла.
     *
     * @return array
     */
    protected function scriptModules() {
        $dir = HTDOCS_DIR . '/scripts';
        $modules = [];
        if (is_dir($dir)) {
            $files = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($dir,
                \FilesystemIterator::SKIP_DOTS | \FilesystemIterator::FOLLOW_SYMLINKS));
            foreach ($files as $file) {
                if ($file->getExtension() === 'js') {
                    $name = substr(str_replace('\\', '/', substr($file->getPathname(), strlen($dir) + 1)), 0, -3);
                    $modules[$name] = (string)$file->getMTime();
                }
            }
        }
        ksort($modules);
        return $modules;
    }
```

  и удалить метод `createJavascriptDependencies` с его комментарием.

- [ ] **Step 3: document.xslt.**
  - строки `<script type="text/javascript" src="{$STATIC_URL}scripts/Energine.js?v=…"></script>` и следующий
    `<script type="text/javascript">Object.assign(Energine, {…});</script>` заменить на:

```xml
        <script type="importmap">{"imports": {<xsl:for-each select="/document/javascript/module">"<xsl:value-of select="@name"/>": "<xsl:value-of select="$STATIC_URL"/>scripts/<xsl:value-of select="@name"/>.js?v=<xsl:value-of select="@version"/>"<xsl:if test="position() != last()">, </xsl:if></xsl:for-each>}}</script>
        <script type="module">
            import {Energine} from 'Energine';
            Object.assign(Energine, {
            <xsl:if test="document/@debug=1">'debug' :true,</xsl:if>
            'base' : '<xsl:value-of select="$BASE"/>',
            'static' : '<xsl:value-of select="$STATIC_URL"/>',
            'resizer' : '<xsl:value-of select="$RESIZER_URL"/>',
            'media' : '<xsl:value-of select="$MEDIA_URL"/>',
            'root' : '<xsl:value-of select="$MAIN_SITE"/>',
            'lang' : '<xsl:value-of select="$DOC_PROPS[@name='lang']/@real_abbr"/>',
            'csrf' : '<xsl:value-of select="$CSRF"/>',
            'singleMode':<xsl:value-of select="boolean($DOC_PROPS[@name='single'])"/>
            });
        </script>
```

  - строку `<xsl:apply-templates select="/document/javascript/library" mode="head"/>` удалить; шаблоны
    `match="/document/javascript/library"` (оба) удалить;
  - скрипт запуска поведений: `<script type="text/javascript">` → `<script type="module">`; первой строкой внутри —
    импорты классов поведений страницы:

```xml
            <xsl:for-each select="$COMPONENTS/javascript/behavior[not(@name = preceding::behavior/@name)]">
                import {<xsl:value-of select="@name"/>} from '<xsl:if test="@path"><xsl:value-of select="@path"/>/</xsl:if><xsl:value-of select="@name"/>';
            </xsl:for-each>
```

    `var componentToolbars = [];` → `window.componentToolbars = [];`; объявление `var <id>, <id>…;` → по строке
    `window['<id>'] = null;` на каждый id (тем же перебором); в `INIT_JS` и в запуске `PageEditor`
    `<id> = new …` → `window['<id>'] = new …`;
  - шаблон переводов (`/document/translations[…editable…]`): `<script type="text/javascript">` →
    `<script type="module">` и первой строкой `import {Energine} from 'Energine';`.
- [ ] **Step 4: Встроенные скрипты шаблонов** — `<script type="text/javascript">` → `<script type="module">`, первой
  строкой — импорт: `list.xslt` (оба скрипта переводов) и `divisionEditor.xslt` (переводы) — `import {Energine} from 'Energine';`;
  `toolbar.xslt` (панель грида и формы) и `file.xslt` (панель окна картинки) — `import {Toolbar} from 'Toolbar';`.
- [ ] **Step 5: Строгий режим и синтаксис.** Каждый скрипт — `node --check` как модуль (копия с расширением `.mjs` во
  временном каталоге); `php8.5 -l` для `Document.php`; XSLT — разбор PHP DOM.
- [ ] **Step 6: Стенд и прогон.** `setup linker` стенда; `no-traces code modules mootools`; `public`, `grids`, `editors`,
  `theme`, `crawl`.
Expected: всё зелёное; карта зависимостей стенда больше не читается (но ещё лежит до задачи 3).
- [ ] **Step 7: Commit** — «Этап 9: скрипты ядра — ES-модули, страницы — import map».

## Task 3: Установка без `scriptMap`

**Files:** `setup/Setup.php`, `tests/tools/install-check.sh`, `tests/tools/tempdb.sh`, `docs/INSTALL.md`

- [ ] **Step 1: Setup.php** — удалить `scriptMapAction`, `writeScriptMap`, `parseScriptLoader`, `iterateScripts` и вызов
  `$this->scriptMapAction();` в установке; если действие перечислено в справке/списке действий — убрать; в `linkerAction`
  после раскладки ссылок: `@unlink(HTDOCS_DIR . '/system.jsmap.php');` с комментарием «карта зависимостей скриптов
  больше не нужна (этап 9)».
- [ ] **Step 2: install-check.sh** — условие `[ -s "$S2/web/system.jsmap.php" ]` → `[ ! -e "$S2/web/system.jsmap.php" ]`
  (и текст «карта …» в сообщении — «карты нет»); **tempdb.sh** — `system.jsmap.php` убрать из списка ссылок.
- [ ] **Step 3: INSTALL.md** — строки 26, 95, 127: без `system.jsmap.php` и `setup scriptMap`.
- [ ] **Step 4: Проверка** — `bash tests/tools/install-check.sh` (как в этапе 5г), `no-traces all`.
- [ ] **Step 5: Commit** — «Этап 9: установка без карты зависимостей скриптов».

## Task 4: Документы и итоговая проверка

- [ ] **Step 1:** `README.md` — абзац «Этап 9» (модули, import map, без `scriptMap`) и спецификация в списке;
  `tests/README.md` — `public` (модули, версия файла), `grids` (классы не глобальны), `no-traces modules`.
- [ ] **Step 2:** весь набор на стенде — `no-traces all`, регрессия, `public`, `grids`, `editors`, `theme`, `crawl`,
  `install-check`.
- [ ] **Step 3: Commit** — «Этап 9: документы».

## Task 5: Выкладка (после «да» владельца)

- [ ] **Step 1:** точка отката (`private/backup/stage9-<дата>/`: HEAD живого дерева, `web/system.jsmap.php`).
- [ ] **Step 2:** от web97 — перемотка живого дерева; `setup linker` (удаляет карту).
- [ ] **Step 3:** гостевая проверка, регрессия и аудиты на площадке; `chown`.
- [ ] **Step 4:** при провале — откат: `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`, карта из
  точки отката.
