# Этап 8, шаг 7 — структура сайта без MooTools, MooTools уходит: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `DivManager`, `DivSidebar`, `DivTree`, `getDirsTree` — на чистом JavaScript; `MooCompat.js` и
`mootools.min.js` удалены; ни одна страница сайта и админки MooTools не загружает.

**Architecture:** классы JavaScript с прежним интерфейсом; конструктор `DivManager` зовёт `setup(element)` —
`DivSidebar` переопределяет его (раньше он не вызывал конструктор родителя); адрес данных дерева — `treeDataURL()`
(`getDirsTree` — свой); выбор и раскрытие текущего узла — `showCurrent()`. У `TreeView` методы `adopt` → `appendNode`,
`addEvent` (у узла) → `on`. Правило `no-traces` `mootools` — по всем скриптам ядра и сайта.

**Tech Stack:** браузерный JavaScript (классические скрипты), PHP 8.5 (одна строка `FileRepository::getDirs`),
Playwright-аудиты, `tests/no-traces.sh`.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step7-structure-no-mootools-design.md`

## Global Constraints

- Клон `/var/www/clients/client1/web97/private/stage8/energine`, ветка `main`; стенд — `bash tests/tools/stand.sh …`;
  карта скриптов стенда после смены зависимостей — от web97 `php8.5 /tmp/stand-web97/site/web/index.php setup scriptMap`,
  ссылки — `… setup linker`.
- Коммиты — `bash tests/tools/stand.sh run git commit -q -m "…" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`;
  после git-операций от root — `chown -R web97:client1 /var/www/clients/client1/web97/private/stage8/energine`.
- В переписанных файлах нет совпадений с `MOOTOOLS_CODE` и в комментариях (`.adopt(`, `.addEvent(`, `.getElement(`,
  `$(`, `.each(` …); классы — `var Имя = class Имя …`, без `const`/`let` на верхнем уровне.
- Проверки на площадке не переставляют разделы и не переносят файлы: такие запросы перехватываются; всё созданное
  удаляется.
- База не меняется; адрес new.energine.org нигде не упоминается; пароли и `configs/system.config.*.php` не выводятся.
- Выкладка — без отдельного согласования (владелец: «продолжай без остановки»), с точкой отката.

## Review Focus

1. `DivSidebar.setup` и `DivTree`/`getDirsTree` поверх общего конструктора: у боковой панели нет вкладок и
   подгонки высоты по окну, у окна выбора — вычисление текущего раздела после `super()`, у переноса — свой адрес.
2. Пустые и неполные ответы дерева (нет разделов, нет `data`, нет хранилищ) — пустое дерево без ошибок JS.
3. Переход по двойному щелчку (`go`) и ответы окон (`add` → `go`, `add` → ещё раз) — в верхнем окне.
4. После удаления `mootools.min.js` ни один шаблон XSLT, PHP и встроенный скрипт не ссылается на MooTools, `Asset`,
   `$(`, `document.id`.
5. Кэш браузера: новые адреса скриптов (`?v=`) у всех изменённых файлов.

---

## Task 1: Проверки

**Files:**
- Modify: `tests/audit/crawl.js` (MooTools — в каждом окне каждой страницы)
- Modify: `tests/audit/public.js` (файлов MooTools на сайте нет)
- Modify: `tests/audit/editors.js` (блок 25: `getDirs` без папок)
- Modify: `tests/audit/grids.js` (блок шага 7 перед `    } finally {\n        db('remove');`)

**Interfaces:**
- Produces: красные до переделки — `crawl` (страницы с `mootools:`), две проверки 404 в `public`, «папки для
  переноса: getDirs …» в `editors` (на стенде без папок), «перенос в папку: пустой список …» в `grids`.

- [ ] **Step 1: crawl.js.** В `visit()` после строки `page.on('requestfailed', …);`:

```js
        // этап 8: MooTools не запрашивается ни одним окном страницы и нигде не определена
        page.on('request', (r) => { if (/mootools|moocompat/i.test(r.url())) errors.push('mootools: ' + r.url()); });
```

и после `await page.waitForTimeout(waitMs);`:

```js
            for (const frame of page.frames()) {
                if (await frame.evaluate(() => typeof window.MooTools !== 'undefined').catch(() => false)) {
                    errors.push('mootools: defined in ' + frame.url());
                }
            }
```

- [ ] **Step 2: public.js.** После цикла `// 1. the guest's pages in both languages`:

```js
        // 1a. the MooTools files are gone from the site (stage 8, step 7)
        for (const file of ['scripts/mootools.min.js', 'scripts/MooCompat.js']) {
            const r = await guest.request.get(BASE + file);
            check(`${file}: на сайте нет (404)`, r.status() === 404, r.status());
        }
```

- [ ] **Step 3: editors.js.** Перед строкой `    await browser.close();`:

```js
    // 25. the folders for moving a file (FileRepository::getDirs) — a JSON list with the repositories, also without
    //     any folder (here: the editors test makes none)
    {
        const p = await ctx.newPage();
        await p.goto(BASE + 'admin/users/single/adminPanel/file-library/', { waitUntil: 'networkidle' });
        const r = await p.evaluate(() => Energine.send(
            document.querySelector('[single_template]').getAttribute('single_template') + '/getDirs/', 'languageID=1'));
        check('папки для переноса: getDirs отвечает списком хранилищ', r.status === 200 && !!r.json && Array.isArray(r.json.data)
            && r.json.data.some((d) => d.upl_internal_type === 'repo'), JSON.stringify({ status: r.status, text: (r.text || '').slice(0, 200) }));
        await p.close();
    }

```

- [ ] **Step 4: grids.js.** Перед последним `    } finally {\n        db('remove');\n    }` вставить:

Full file `tests/audit/grids-step7-block.js`:
```js

        // ===== stage 8, step 7: the structure (DivManager, DivTree, getDirsTree) without MooTools =====
        // the tree manager of a page or a window (a global variable named by the component)
        const manager = (target) => target.evaluate(() => {
            for (const key of Object.keys(window)) {
                try {
                    const v = window[key];
                    if (v && v.tree && typeof v.loadTree === 'function') {
                        return key;
                    }
                } catch (e) {
                }
            }
            return null;
        });
        const nodeAnchor = (target, key, id) => target.evaluateHandle(([k, nodeId]) =>
            window[k].tree.getNodeById(nodeId).element.querySelector('a'), [key, id]);

        // 1. the structure page: the tree is built, the current page selected; a page enables every button, the root
        //    only its own; «Вниз»/«Вверх» move the node (answered here — the order stays); «Править» refreshes the node
        //    name (get-node-data, answered here); a double click opens the page
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const moves = [];
            await p.route(/\/\d+\/(up|down)$/, (route) => {
                const url = route.request().url();
                moves.push(url);
                route.fulfill({ status: 200, contentType: 'application/json',
                    body: JSON.stringify({ result: true, dir: url.endsWith('/up') ? '<' : '>' }) });
            });
            await p.goto(BASE + 'admin/structure/', { waitUntil: 'networkidle' });
            await p.waitForSelector('#divTree li', { timeout: 10000 });
            await p.waitForTimeout(500);
            const key = await manager(p);
            const info = () => p.evaluate((k) => {
                const m = window[k], sel = m.tree.getSelectedNode();
                const on = (id) => {
                    const c = m.toolbar.getControlById(id);
                    return c ? !c.disabled() : null;
                };
                return {
                    selected: sel ? { id: String(sel.getId()), segment: sel.getData().smap_segment } : null,
                    buttons: { add: on('add'), edit: on('edit'), del: on('delete'), up: on('up'), down: on('down') },
                };
            }, key);
            const start = await info();
            check('структура: дерево построено, выбран текущий раздел', !!key && !!start.selected && start.selected.segment === 'structure',
                JSON.stringify(start));
            const pick = await p.evaluate((k) => {
                const m = window[k];
                const root = m.tree.nodes.find((n) => !n.getData().smap_pid);
                const kids = m.tree.nodes.filter((n) => n.getData().smap_pid == root.getId());
                const x = kids.find((n, i) => i < kids.length - 1 && n.getData().smap_segment);
                return { root: String(root.getId()), x: String(x.getId()), segment: x.getData().smap_segment };
            }, key);
            await (await nodeAnchor(p, key, pick.x)).click();
            const onX = await info();
            await (await nodeAnchor(p, key, pick.root)).click();
            const onRoot = await info();
            check('структура: у раздела включены все кнопки, у корня — только «Добавить» и «Править»', onX.selected.id === pick.x
                && onX.buttons.edit && onX.buttons.del && onX.buttons.up && onX.buttons.down && onRoot.selected.id === pick.root
                && onRoot.buttons.add && onRoot.buttons.edit && !onRoot.buttons.del && !onRoot.buttons.up && !onRoot.buttons.down,
                JSON.stringify({ onX, onRoot }));

            const order = () => p.evaluate(([k, rootId]) => [...window[k].tree.getNodeById(rootId).childs.children]
                .map((li) => String(li.treeNode.getId())), [key, pick.root]);
            await (await nodeAnchor(p, key, pick.x)).click();
            const before = await order();
            await Promise.all([p.waitForResponse((r) => /\/down$/.test(r.url())), p.click('ul.toolbar li.down_btn')]);
            await p.waitForTimeout(300);
            const down = await order();
            await Promise.all([p.waitForResponse((r) => /\/up$/.test(r.url())), p.click('ul.toolbar li.up_btn')]);
            await p.waitForTimeout(300);
            const up = await order();
            check('структура: «Вниз» и «Вверх» — запросы …/<id>/down и …/<id>/up, раздел переставлен и вернулся', moves.length === 2
                && moves[0].endsWith(`/${pick.x}/down`) && moves[1].endsWith(`/${pick.x}/up`)
                && down.indexOf(pick.x) === before.indexOf(pick.x) + 1 && JSON.stringify(up) === JSON.stringify(before),
                JSON.stringify({ moves, before, down, up }));

            const data = await p.evaluate(([k, id]) => window[k].tree.getNodeById(id).getData(), [key, pick.x]);
            await p.route(/get-node-data$/, (route) => route.fulfill({ status: 200, contentType: 'application/json',
                body: JSON.stringify({ result: true, data: Object.assign({}, data, { smap_name: 'Claude renamed' }) }) }));
            await p.click('ul.toolbar li.edit_btn');
            const win = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const src = win ? await win.evaluate((f) => f.src) : '';
            await Promise.all([p.waitForRequest((r) => /get-node-data$/.test(r.url()), { timeout: 10000 }), p.evaluate(() => ModalBox.close())]);
            await p.waitForTimeout(400);
            const renamed = await p.evaluate(([k, id]) => window[k].tree.getNodeById(id).element.querySelector('a').textContent, [key, pick.x]);
            check('структура: «Править» — окно правки раздела, после него имя узла обновлено', src.endsWith(`/${pick.x}/edit`)
                && renamed === 'Claude renamed', JSON.stringify({ src, renamed }));

            await Promise.all([p.waitForNavigation({ timeout: 15000 }), (await nodeAnchor(p, key, pick.x)).dblclick()]);
            check('структура: двойной щелчок по разделу — его страница', new RegExp('/' + pick.segment + '/?$').test(p.url()), p.url());
            check('структура: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 2. the parent window of the page form (DivTree): the page itself cannot be chosen, another one goes back to
        //    the form (id, name, segment); the form is not saved
        {
            const pageId = execFileSync('php8.5', [path.join(__dirname, 'editors-db.php'), 'page-id'], { encoding: 'utf8' }).trim();
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
            await showTab(p, '#sitemap_selector');
            await p.click('#sitemap_selector');
            const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const f = await el.contentFrame();
            await f.waitForSelector('#divTree li', { timeout: 10000 });
            await f.waitForTimeout(500);
            const fk = await manager(f);
            const canSelect = () => f.evaluate((k) => !window[k].toolbar.getControlById('select').disabled(), fk);
            const other = await f.evaluate(([k, current]) => {
                const n = window[k].tree.nodes.find((x) => x.getId() != current && x.getData().smap_pid && x.getData().smap_segment
                    && !x.getParents().some((pa) => pa.id == current));
                return { id: String(n.getId()), name: n.element.querySelector('a').textContent, segment: n.getData().smap_segment };
            }, [fk, pageId]);
            await (await nodeAnchor(f, fk, pageId)).click();
            const onCurrent = await canSelect();
            await (await nodeAnchor(f, fk, other.id)).click();
            const onOther = await canSelect();
            await f.click('ul.toolbar li.select_btn');
            await p.waitForTimeout(600);
            const form = await p.evaluate(() => {
                const b = document.getElementById('sitemap_selector');
                return { id: document.getElementById(b.getAttribute('hidden_field')).value,
                    name: document.getElementById(b.getAttribute('span_field')).textContent,
                    segment: (document.getElementById('smap_pid_segment') || {}).textContent,
                    windows: document.querySelectorAll('.e-modalbox').length };
            });
            check('окно выбора родителя: текущий раздел выбрать нельзя, другой — «Выбрать» возвращает его в форму',
                onCurrent === false && onOther === true && form.id === other.id && form.name === other.name
                && form.segment === other.segment && form.windows === 0, JSON.stringify({ onCurrent, onOther, other, form }));
            check('окно выбора родителя: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 3. moving a file to a folder (getDirsTree; the move is answered here — the file stays): the folders, the
        //    choice enables «Перенести», the request …/<file>,<folder>/getDirsMove/, the window closes; an empty list
        //    of folders (answered here) — an empty tree without a JS error
        {
            const openMove = async (p) => {
                await p.goto(BASE + 'admin/users/single/adminPanel/file-library/', { waitUntil: 'networkidle' });
                await p.waitForSelector('tbody tr td', { timeout: 10000 });
                await p.waitForTimeout(500);
                await p.locator('.gridContainer tbody tr', { hasText: 'claude-grid-big' }).first().click();
                await p.click('ul.toolbar li.moveToDir_btn');
                const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
                const f = await el.contentFrame();
                await f.waitForLoadState('networkidle').catch(() => null);
                await f.waitForTimeout(800);
                return f;
            };
            await ctx.addCookies([{ name: 'NRGNFRPID', value: String(ids.dir), url: BASE }]);
            const p = await ctx.newPage();
            const errors = watch(p);
            const moved = [];
            await p.route(/\/getDirsMove\/$/, (route) => {
                moved.push(route.request().url());
                route.fulfill({ status: 200, contentType: 'application/json', body: '{"result":true}' });
            });
            const f = await openMove(p);
            const fk = await manager(f);
            const tree = await f.evaluate((k) => ({
                names: window[k].tree.nodes.map((n) => n.element.querySelector('a').textContent),
                ids: window[k].tree.nodes.map((n) => String(n.getId())),
                move: !window[k].toolbar.getControlById('saveDirsMove').disabled(),
            }), fk);
            const target = tree.ids[tree.names.findIndex((n) => n.includes('claude-grid-dir'))];
            if (target) {
                await (await nodeAnchor(f, fk, target)).click();
            }
            const enabled = await f.evaluate((k) => !window[k].toolbar.getControlById('saveDirsMove').disabled(), fk);
            await Promise.all([p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }).catch(() => null),
                f.click('ul.toolbar li.saveDirsMove_btn')]);
            await p.waitForTimeout(500);
            const windows = await p.evaluate(() => document.querySelectorAll('.e-modalbox').length);
            check('перенос в папку: окно папок, выбор включает «Перенести», запрос …/<файл>,<папка>/getDirsMove/, окно закрыто',
                !!target && !tree.move && enabled && moved.length === 1 && moved[0].endsWith(`/${ids.big},${target}/getDirsMove/`)
                && windows === 0, JSON.stringify({ tree, enabled, moved, windows }));
            check('перенос в папку: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();

            const q = await ctx.newPage();
            const qErrors = watch(q);
            await q.route(/\/getDirs\/$/, (route) => route.fulfill({ status: 200, contentType: 'application/json',
                body: '{"result":true,"data":[]}' }));
            const g = await openMove(q);
            const empty = await g.evaluate(() => document.querySelectorAll('#divTree li').length);
            check('перенос в папку: пустой список папок — пустое дерево без ошибки JS', empty === 0 && !qErrors.list().length,
                JSON.stringify({ empty, errors: qErrors.list() }));
            await q.close();
            await ctx.clearCookies({ name: 'NRGNFRPID' });
        }
```

(Файла `tests/audit/grids-step7-block.js` нет: блок вставляется в `grids.js` как есть.)

- [ ] **Step 5: Прогон до переделки.**

Run: `cd tests/audit && for t in public grids editors; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '$t'.js' > $W/t1-$t.log 2>&1; grep -E '^FAIL|failures' $W/t1-$t.log; done; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node crawl.js crawl-guest.txt crawl-admin.txt crawl-singles.txt '$W'/t1-crawl.json' > $W/t1-crawl.log 2>&1; tail -1 $W/t1-crawl.log`
Expected: `public` — FAIL две «…: на сайте нет (404)»; `grids` — FAIL «перенос в папку: пустой список папок — пустое
дерево без ошибки JS»; `editors` — FAIL «папки для переноса: getDirs отвечает списком хранилищ» (на стенде папок нет:
фатальная ошибка PHP); `crawl` — страницы с ошибками, у всех ошибок префикс `mootools:` (структура, боковая панель
администратора); остальные проверки — OK.

- [ ] **Step 6: Commit**

```bash
git add tests/audit/crawl.js tests/audit/public.js tests/audit/editors.js tests/audit/grids.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 7: проверки — MooTools нигде, структура, окна выбора раздела и папки, getDirs без папок" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 2: `TreeView` — новые имена; `DivManager` и наследники

**Files:**
- Modify: `core/modules/share/scripts/TreeView.js` (`adopt` → `appendNode` у дерева и узла, `addEvent` → `on`)
- Modify (весь файл): `core/modules/share/scripts/DivManager.js`, `DivSidebar.js`, `DivTree.js`, `getDirsTree.js`
- Modify: `tests/audit/grids.js` (проверки узлов шага 4: `adopt` → `appendNode`)
- Modify: `tests/no-traces.sh` (`VANILLA_JS` + четыре файла)

**Interfaces:**
- Consumes: `TreeView(element|id, {dblClick})` (`nodes`, `appendNode`, `empty`, `setupCssClasses`, `getSelectedNode`,
  `getNodeById`, `expandToNode`, `expandAllNodes`), `TreeView.Node(описание, дерево)` (`on`, `appendNode`,
  `injectInside`, `getParents`, `moveUp`, `moveDown`, `select`, `expand`, `getId`, `getData`, `setData`, `setName`,
  `id`), `TabPane`, `Toolbar` (`element`, `getControlById`, `disableControls`, `enableControls`, `bindTo`), `ModalBox`,
  `Energine.request`.
- Produces: `DivManager` (`setup`, `treeDataURL`, `showCurrent`, статические `element`, `treeList`), наследники.

- [ ] **Step 1: TreeView.** В `core/modules/share/scripts/TreeView.js`: `    adopt(node) {` (у `TreeView` и у
  `TreeView.Node`) → `    appendNode(node) {`; `    addEvent(type, handler) {` → `    on(type, handler) {`; в
  комментарии `addEvent('select', обработчик)` → `on('select', обработчик)`. В `tests/audit/grids.js` (проверки узлов
  шага 4) `tree.adopt(` / `root.adopt(` / `c.adopt(` → `….appendNode(`.

- [ ] **Step 2: DivManager.js.** Заменить целиком:

Full file `core/modules/share/scripts/DivManager.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivManager]{@link DivManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires TabPane
 * @requires Toolbar
 * @requires ModalBox
 * @requires TreeView
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

// TODO: DivManager class is very similar to the TreeView class! I think, one of them must be merged to another and remove the overloaded functionality. - wait for tests

ScriptLoader.load('TabPane', 'Toolbar', 'ModalBox', 'TreeView');

/**
 * Структура сайта: дерево разделов с панелью — добавить, править, удалить, переставить, выбрать (в окне), перейти на
 * страницу раздела (двойной щелчок).
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id).
 */
var DivManager = class DivManager {
    constructor(element) {
        /**
         * Toolbar.
         * @type {Toolbar}
         */
        this.toolbar = null;
        this.treeRoot = null;
        this.setup(element);
    }

    /**
     * Настройка: вкладки, дерево в #treeContainer, загрузка разделов; на странице панель подгоняется под окно.
     *
     * @param {Element|string} element
     */
    setup(element) {
        Energine.loadCSS('div.css');
        this.element = DivManager.element(element);
        this.tabPane = new TabPane(this.element);
        this.langId = this.element.getAttribute('lang_id');
        this.tree = new TreeView(DivManager.treeList(), {dblClick: () => this.go()});
        this.singlePath = this.element.getAttribute('single_template');
        this.loadTree();

        /* вешаем пересчет размеров формы на ресайз окна */
        if (!document.querySelector('.e-singlemode-layout')) {
            window.addEventListener('resize', () => this.fitTreeFormSize());
        }
    }

    /**
     * Панель — внизу; «Добавить», «Выбрать», «Закрыть», «Править» включены сразу, остальные — по выбору раздела.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        const toolbarContainer = this.element.querySelector('.e-pane-b-toolbar');
        this.toolbar = toolbar;
        (toolbarContainer || this.element).appendChild(this.toolbar.element);
        this.toolbar.disableControls();
        ['add', 'select', 'close', 'edit'].forEach((btnID) => {
            const btn = this.toolbar.getControlById(btnID);
            if (btn) {
                btn.enable();
            }
        });
        toolbar.bindTo(this);
    }

    /**
     * Адрес данных дерева.
     *
     * @returns {string}
     */
    treeDataURL() {
        return this.singlePath + 'get-data/';
    }

    /**
     * Загрузить разделы и построить дерево; на странице панель подгоняется под окно и прокручивается в видимую часть.
     */
    loadTree() {
        Energine.request(
            this.treeDataURL(),
            'languageID=' + this.langId,
            (response) => {
                this.buildTree(response.data, (response.current) ? response.current : null);
                /* растягиваем всю форму до высоты видимого окна */
                if (!document.querySelector('.e-singlemode-layout')) {
                    this.pane = this.element;
                    this.paneContent = this.pane.querySelector('.e-pane-item');
                    this.treeContainer = this.pane.querySelector('.e-divtree-select');
                    this.minPaneHeight = 300;
                    this.fitTreeFormSize();
                    this.pane.scrollIntoView({block: 'start'});
                }
            }
        );
    }

    /**
     * Дерево из списка разделов (родитель — smap_pid); пустой список — пустое дерево.
     *
     * @param {Object[]} nodes
     * @param {number|string} currentNodeID
     */
    buildTree(nodes, currentNodeID) {
        const treeInfo = {};
        (nodes || []).forEach((node) => {
            const pid = node['smap_pid'] || 'treeRoot';
            (treeInfo[pid] = treeInfo[pid] || []).push(node);
        });

        const lambda = (nodeId, parentNode) => {
            (treeInfo[nodeId] || []).forEach((child) => {
                const icon = (child['tmpl_icon'])
                        ? Energine.base + child['tmpl_icon']
                        : Energine.base + 'templates/icons/empty.icon.gif',
                    childId = child['smap_id'];
                const newNode = new TreeView.Node({
                    id: childId,
                    name: child['smap_name'],
                    data: {
                        'segment': child['smap_segment'],
                        'class': ((childId == currentNodeID) ? ' current' : ''),
                        'icon': icon
                    }
                }, this.tree);
                newNode.setData(child);
                newNode.on('select', (node) => this.onSelectNode(node));
                parentNode.appendNode(newNode);
                if (treeInfo[childId]) {
                    lambda(childId, newNode);
                }
            });
        };

        lambda('treeRoot', this.tree);
        this.showCurrent(currentNodeID);
    }

    /**
     * Текущий раздел выбран и раскрыт, иначе раскрыты все.
     *
     * @param {number|string} currentNodeID
     */
    showCurrent(currentNodeID) {
        this.tree.setupCssClasses();
        this.tree.expandToNode(currentNodeID);
        const current = this.tree.getNodeById(currentNodeID);
        if (current) {
            current.select();
            current.expand();
        } else {
            this.tree.expandAllNodes();
        }
    }

    /**
     * Панель на странице — по дереву, но не выше окна (и не ниже 300px).
     */
    fitTreeFormSize() {
        if (!this.pane) {
            return;
        }
        const windowHeight = document.documentElement.clientHeight - 10,
            treeContainerHeight = this.treeContainer.getBoundingClientRect().height,
            paneOthersHeight = this.pane.getBoundingClientRect().height - this.paneContent.getBoundingClientRect().height + 22;

        if (windowHeight > this.minPaneHeight) {
            const treePane = treeContainerHeight + paneOthersHeight;
            this.pane.style.height = Math.round((treePane > windowHeight) ? windowHeight : treePane) + 'px';
        } else {
            this.pane.style.height = this.minPaneHeight + 'px';
        }
    }

    reload() {
        this.tree.empty();
        this.loadTree();
    }

    // Actions:

    /**
     * Окно добавления раздела в выбранный; ответ окна: add — ещё раз, go — переход на новую страницу, иначе — дерево
     * заново.
     */
    add() {
        const nodeId = this.tree.getSelectedNode().getId();
        ModalBox.open({
            url: this.singlePath + 'add/' + nodeId + '/',
            onClose: (returnValue) => {
                if (returnValue) {
                    switch (returnValue.afterClose) {
                        case 'add':
                            this.add();
                            break;
                        case 'go':
                            window.top.location.href = Energine.base + returnValue.url;
                            break;
                        default:
                            this.reload();
                    }
                }
            },
            extraData: this.tree.getSelectedNode()
        });
    }

    /**
     * Окно правки раздела; после него — имя и место узла с сервера.
     */
    edit() {
        const nodeId = this.tree.getSelectedNode().getId();
        ModalBox.open({
            url: this.singlePath + nodeId + '/edit',
            onClose: () => this.refreshNode(),
            extraData: this.tree.getSelectedNode()
        });
    }

    del() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete record?';
        if (!confirm(MSG_CONFIRM_DELETE)) {
            return;
        }
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/delete/', '', () => this.reload());
    }

    /**
     * Ответ на «вверх»/«вниз»: узел переставляется по направлению из ответа.
     *
     * @param {Object} response {result, dir}
     */
    changeOrder(response) {
        if (!response.result) {
            return;
        }
        this.tree.getSelectedNode()[(response.dir == '<') ? 'moveUp' : 'moveDown']();
    }

    up() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/up', '', (response) => this.changeOrder(response));
    }

    down() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(this.singlePath + nodeId + '/down', '', (response) => this.changeOrder(response));
    }

    select() {
        ModalBox.setReturnValue(this.tree.getSelectedNode().getData());
        ModalBox.close();
    }

    close() {
        ModalBox.close();
    }

    /**
     * Перейти на страницу выбранного раздела — в верхнем окне.
     */
    go() {
        const nodeData = this.tree.getSelectedNode().getData();
        if (nodeData.smap_segment || !nodeData.smap_pid) {
            window.top.document.location = Energine.base + nodeData.smap_segment;
        }
    }

    // End actions

    /**
     * Выбран раздел: у раздела включены все кнопки, у корня — только «Закрыть», «Добавить», «Править», «Выбрать».
     *
     * @param {TreeView.Node} node
     */
    onSelectNode(node) {
        if (!this.toolbar) {
            return;
        }
        const data = node.getData(),
            buttons = [this.toolbar.getControlById('close')];
        if ((data != undefined) && data.smap_pid) {
            this.toolbar.enableControls();
        } else {
            this.toolbar.disableControls();
            buttons.push(
                this.toolbar.getControlById('add'),
                this.toolbar.getControlById('edit'),
                this.toolbar.getControlById('select')
            );
        }
        buttons.forEach((btn) => {
            if (btn) {
                btn.enable();
            }
        });
    }

    /**
     * Имя и место выбранного узла — с сервера (после окна правки).
     */
    refreshNode() {
        const nodeId = this.tree.getSelectedNode().getId();
        Energine.request(
            this.singlePath + 'get-node-data',
            'languageID=' + this.langId + '&id=' + nodeId,
            (response) => {
                if (response.data.smap_pid == null) {
                    response.data.smap_pid = '';
                }
                const smapPid = response.data.smap_pid,
                    currentNode = this.tree.getSelectedNode();
                if (smapPid != currentNode.getData().smap_pid) {
                    const parentNode = (smapPid) ? this.tree.getNodeById(smapPid) : this.treeRoot;
                    this.tree.expandToNode(parentNode);
                    currentNode.injectInside(parentNode);
                }
                currentNode.setData(response.data);
                currentNode.setName(response.data.smap_name);
            }
        );
    }

    /**
     * Элемент по id или сам элемент.
     *
     * @param {Element|string} element
     * @returns {Element}
     */
    static element(element) {
        return (typeof element === 'string') ? document.getElementById(element) : element;
    }

    /**
     * Список дерева (ul#divTree.treeview) в #treeContainer.
     *
     * @returns {Element}
     */
    static treeList() {
        const list = document.createElement('ul');
        list.id = 'divTree';
        list.classList.add('treeview');
        document.getElementById('treeContainer').appendChild(list);
        return list;
    }
};
```

- [ ] **Step 3: DivSidebar.js, DivTree.js, getDirsTree.js.** Заменить целиком:

Full file `core/modules/share/scripts/DivSidebar.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivSidebar]{@link DivSidebar}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('DivManager');

/**
 * Дерево разделов в боковой панели администратора: без вкладок и подгонки под окно, панель сверху, у html — класс
 * e-divtree-panel.
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
var DivSidebar = class DivSidebar extends DivManager {
    /**
     * Своя настройка вместо настройки DivManager.
     *
     * @param {Element|string} element
     */
    setup(element) {
        Energine.loadCSS('div.css');
        this.element = DivManager.element(element);
        const list = DivManager.treeList();
        this.langId = this.element.getAttribute('lang_id');
        this.tree = new TreeView(list, {dblClick: () => this.go()});
        this.singlePath = this.element.getAttribute('single_template');
        document.documentElement.classList.add('e-divtree-panel');
        this.loadTree();
    }

    /**
     * Панель — сверху, включены «Добавить» и «Выбрать».
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        if ((this.toolbar = toolbar)) {
            this.element.prepend(this.toolbar.element);
            this.toolbar.disableControls();
            const addBtn = this.toolbar.getControlById('add'),
                selectBtn = this.toolbar.getControlById('select');
            if (addBtn) {
                addBtn.enable();
            }
            if (selectBtn) {
                selectBtn.enable();
            }
            toolbar.bindTo(this);
        }
    }
};
```

Full file `core/modules/share/scripts/DivTree.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivTree]{@link DivTree}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('DivManager');

/**
 * Окно выбора раздела (родитель раздела): раздел формы, из которой окно открыто, и его потомков выбрать нельзя.
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} el The main holder element.
 */
var DivTree = class DivTree extends DivManager {
    constructor(el) {
        super(el);
        /**
         * Id раздела формы (поле #smap_id в одном из окон страницы) или 0.
         * @type {number}
         */
        this.currentID = 0;
        const srcWindows = [window.top];
        Array.from(window.top.document.getElementsByTagName('iframe')).forEach((iframe) => {
            if (iframe.contentWindow) {
                srcWindows.push(iframe.contentWindow);
            }
        });
        for (let i = 0; i < srcWindows.length; i++) {
            try {
                const result = srcWindows[i].document.getElementById('smap_id');
                if (result) {
                    this.currentID = parseInt(result.value, 10);
                    break;
                }
            } catch (e) {
            }
        }
    }

    /**
     * «Выбрать» выключена у раздела формы и у его потомков.
     *
     * @param {TreeView.Node} node
     */
    onSelectNode(node) {
        super.onSelectNode(node);
        const btnSelect = this.toolbar.getControlById('select');
        if (this.currentID) {
            if (this.currentID == node.id) {
                if (btnSelect) {
                    btnSelect.disable();
                }
            } else {
                const parents = node.getParents();
                for (let i = 0; i < parents.length; i++) {
                    if (parents[i].id == this.currentID) {
                        if (btnSelect) {
                            btnSelect.disable();
                        }
                        break;
                    }
                }
            }
        } else if (btnSelect) {
            btnSelect.enable();
        }
    }
};
```

Full file `core/modules/share/scripts/getDirsTree.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[getDirsTree]{@link getDirsTree}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires DivManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('DivManager');

/**
 * Окно выбора папки для переноса файла или папки: хранилища и папки репозитория без переносимой папки и её
 * содержимого; выбор включает «Перенести».
 *
 * @augments DivManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
var getDirsTree = class getDirsTree extends DivManager {
    treeDataURL() {
        return this.singlePath + '/getDirs/';
    }

    /**
     * Дерево папок (родитель — upl_pid) без переносимой (move_id у #treeContainer) и её содержимого.
     *
     * @param {Object[]} nodes
     * @param {number|string} currentNodeID
     */
    buildTree(nodes, currentNodeID) {
        const treeInfo = {},
            moveFromId = document.getElementById('treeContainer').getAttribute('move_id');
        (nodes || []).forEach((node) => {
            if (node['upl_id'] == moveFromId) {
                return;
            }
            const pid = node['upl_pid'] || 'treeRoot';
            if (pid == moveFromId) {
                return;
            }
            (treeInfo[pid] = treeInfo[pid] || []).push(node);
        });

        const lambda = (nodeId, parentNode) => {
            (treeInfo[nodeId] || []).forEach((child) => {
                const icon = (child['tmpl_icon'])
                        ? Energine.base + child['tmpl_icon']
                        : Energine.base + 'templates/icons/divisions_list.icon.gif',
                    childId = child['upl_id'];
                const newNode = new TreeView.Node({
                    id: childId,
                    name: child['upl_title'],
                    data: {
                        'segment': child['upl_segment'],
                        'class': ((childId == currentNodeID) ? ' current' : ''),
                        'icon': icon
                    }
                }, this.tree);
                newNode.setData(child);
                newNode.on('select', (node) => this.onSelectNode(node));
                parentNode.appendNode(newNode);
                if (treeInfo[childId]) {
                    lambda(childId, newNode);
                }
            });
        };

        lambda('treeRoot', this.tree);
        this.showCurrent(currentNodeID);
    }

    onSelectNode() {
        const btnSelect = this.toolbar.getControlById('saveDirsMove');
        if (btnSelect) {
            btnSelect.enable();
        }
    }

    // двойной щелчок ничего не делает
    go() {
    }

    /**
     * Перенести в выбранную папку; окно закрывается.
     */
    saveDirsMove() {
        const moveToId = this.tree.getSelectedNode().getId(),
            moveFromId = document.getElementById('treeContainer').getAttribute('move_id');
        Energine.request(
            this.singlePath + moveFromId + ',' + moveToId + '/getDirsMove/',
            'languageID=' + this.langId,
            () => this.close()
        );
    }
};
```

- [ ] **Step 4: no-traces.** В `VANILLA_JS` добавить `core/modules/share/scripts/DivManager.js
  core/modules/share/scripts/DivSidebar.js core/modules/share/scripts/DivTree.js core/modules/share/scripts/getDirsTree.js`.

- [ ] **Step 5: Карта стенда и прогон.**

Run: `runuser -u web97 -- php8.5 /tmp/stand-web97/site/web/index.php setup scriptMap; bash tests/tools/stand.sh run bash tests/no-traces.sh mootools; cd tests/audit && for t in grids editors; do …; done; … crawl …`
Expected: карта — `MooCompat` никому не нужна (остаётся только своя запись `MooCompat => mootools.min`); no-traces — 0;
grids — 0 (пустой список папок — OK); editors — FAIL только «папки для переноса: getDirs …» (задача 3); crawl —
`pages: 72, with errors: 0`.

- [ ] **Step 6: Commit**

```bash
git add core/modules/share/scripts/TreeView.js core/modules/share/scripts/DivManager.js core/modules/share/scripts/DivSidebar.js core/modules/share/scripts/DivTree.js core/modules/share/scripts/getDirsTree.js tests/audit/grids.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 7: структура сайта на чистом JavaScript, пустое дерево — без ошибки JS" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 3: MooTools уходит; `getDirs` без папок

**Files:**
- Delete: `core/modules/share/scripts/MooCompat.js`, `core/modules/share/scripts/mootools.min.js`
- Modify: `core/modules/share/components/FileRepository.php` (`getDirs`: `array_merge($repos ?: [], $folders ?: [])`)
- Modify: `tests/no-traces.sh` (категория `mootools` — по всем скриптам; файлов MooTools нет; `VANILLA_JS` и
  `first_dep` уходят; шапка)
- Modify: `core/modules/share/scripts/Energine.js` (комментарий `loadCSS` — без `Asset.css` и `mootools.min.js`),
  `core/modules/share/gears/Document.php` (комментарий о MooTools перед `javascript`)

- [ ] **Step 1: getDirs.** В `FileRepository::getDirs` строка `$d->load(array_merge($repos,$folders));` →
  `$d->load(array_merge($repos ?: [], $folders ?: []));` (`loadData` без строк отдаёт `false`).
- [ ] **Step 2: удаление.** `git rm core/modules/share/scripts/MooCompat.js core/modules/share/scripts/mootools.min.js`.
- [ ] **Step 3: no-traces.sh.**
  - шапка: строка «Этап 8 — без MooTools: mootools (…)» → «Этап 8 — без MooTools: mootools (в скриптах ядра и сайта,
    кроме Jodit, нет конструкций MooTools; файлов MooTools нет)»;
  - блок от комментария `# этап 8: MooTools уходит файл за файлом …` до конца массива `VANILLA_JS=(…)` заменить на
    комментарий `# этап 8: MooTools ушла (шаг 7): ни в одном скрипте ядра и сайта (кроме Jodit) нет её конструкций` и
    `MOOTOOLS_FILES='core/modules/share/scripts/mootools.min.js core/modules/share/scripts/MooCompat.js'` (строка
    `MOOTOOLS_CODE=…` остаётся); функцию `first_dep` удалить;
  - ветку `if [ "$m" = mootools ]; then … ` заменить на:

```bash
    if [ "$m" = mootools ]; then
      found=$(G "$MOOTOOLS_CODE" --include='*.js' --exclude-dir=jodit core site | cut -c1-160)
      for f in $MOOTOOLS_FILES; do [ -e "$R/$f" ] && found+=$'\n'"file $f"; done
```

- [ ] **Step 4: комментарии.** `Energine.js` перед `Energine.loadCSS`: «Стили элемента админки: stylesheets/<имя>
  подключается один раз; файл, уже подключённый ссылкой, второй раз не грузится.»; `Document.php`: строка
  `// MooTools — обычная библиотека в карте зависимостей: …` → `// скрипты страницы и их зависимости — по карте
  system.jsmap.php (setup scriptMap)`.
- [ ] **Step 5: Стенд и прогон.**

Run: `runuser -u web97 -- php8.5 /tmp/stand-web97/site/web/index.php setup linker && runuser -u web97 -- php8.5 /tmp/stand-web97/site/web/index.php setup scriptMap; ls /tmp/stand-web97/site/web/scripts/ | grep -ci moo; bash tests/tools/stand.sh run bash tests/no-traces.sh all; cd tests/audit && for t in public editors; do …; done`
Expected: в `web/scripts` нет `mootools*`/`MooCompat*` (0); карта без `MooCompat`; no-traces — 0; public — 0 (404 —
OK); editors — 0 (getDirs — OK).

- [ ] **Step 6: Commit**

```bash
git add -A core/modules/share/scripts/MooCompat.js core/modules/share/scripts/mootools.min.js core/modules/share/components/FileRepository.php tests/no-traces.sh core/modules/share/scripts/Energine.js core/modules/share/gears/Document.php
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 7: MooTools удалена; getDirs без папок не падает" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 4: Документы и итоговая проверка

**Files:** `README.md` (этап 8 — шаг 7, этап закончен; список спецификаций), `tests/README.md` (`crawl` — MooTools в
окнах; `grids` — структура, окна выбора раздела и папки; `public` — 404 файлов MooTools; `editors` — `getDirs`).

- [ ] **Step 1: README.md.** После предложения о шаге 6: «Шаг 7
  (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step7-structure-no-mootools-design.md`): структура сайта
  — на чистом JavaScript; `mootools.min.js` и `MooCompat.js` удалены, MooTools не загружает ни одна страница. Этап 8
  закончен.»; в список спецификаций — шаг 7.
- [ ] **Step 2: tests/README.md** — по одному предложению к `crawl`, `grids`, `public`, `editors` (см. «Files»).
- [ ] **Step 3: Весь набор на стенде** — no-traces all, регрессия, `public`, `grids`, `editors`, `theme`, `crawl`.
Expected: всё зелёное (регрессия 17/17, журнал PHP чист, `pages: 72, with errors: 0`).
- [ ] **Step 4: Commit** — «Этап 8, шаг 7: документы».

## Task 5: Выкладка и проверка на simple.energine.org

Без отдельного согласования. База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step7-<дата>/`.
- [ ] **Step 2: Код** — от web97: `git fetch <клон> <HEAD>` и `git merge --ff-only`.
- [ ] **Step 3: Статика** — от web97 в `web/`: `setup linker && setup scriptMap`; в `web/scripts` нет файлов MooTools,
  в карте нет `MooCompat` и `mootools.min`.
- [ ] **Step 4: Проверка гостем** — `live-guest.js`.
- [ ] **Step 5: Регрессия и аудиты на площадке**, затем `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 6: При провале** — откат: от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`
  (файлы MooTools вернутся вместе с кодом).
