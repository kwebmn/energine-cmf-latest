# Energine Simple, этап 8, шаг 2 — основа админки без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** затемнение (`Overlay`), окна (`ModalBox`), вкладки (`TabPane`) и листалка (`PageList`) админки работают на чистом JavaScript с прежним интерфейсом; ошибка под полем уходит и при вставке.

**Architecture:** четыре файла переписываются классами JavaScript (`ModalBox` — общий объект верхнего окна, как прежде) без объявления `MooCompat`; скрипты на MooTools пользуются ими как раньше — MooTools на страницах админки по-прежнему грузится по их собственным объявлениям. Стили элементов — новый `Energine.loadCSS` (замена вставки `Asset.css` из собранной MooTools). Данные вкладок шаблоны пишут как JSON.

**Tech Stack:** JavaScript (классические скрипты, классы), XSLT 1.0 (`list.xslt`, `form.xslt`), Playwright (аудиты), bash.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md`

## Global Constraints

- Только современные браузеры; без сборки, npm и ES-модулей; классы — `var Имя = class Имя …`.
- Интерфейс четырёх файлов для скриптов на MooTools — прежний (спецификация, раздел 3.1): те же имена, параметры, свойства, обработчики `onPageSelect`, `onTabChange`, `onClose`; разметка и классы прежние.
- Зависимости скрипта — первый вызов `ScriptLoader.load('…')` в файле; в комментариях такой вызов с именами в кавычках не пишется.
- В файлах из `VANILLA_JS` (`tests/no-traces.sh`) нет конструкций MooTools — и в комментариях тоже.
- Щелчок по затемнению и Esc окно не закрывают (спецификация, раздел 3.3).
- Комментарии — по-русски; строки `@author` в шапках остаются.
- Проверки — только на стенде (`tests/tools/stand.sh`); площадка — только в задаче 6 после «да» владельца.
- Коммиты — `bash tests/tools/stand.sh run git commit …`; последняя строка сообщения — `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Пароли и учётные данные не попадают в файлы, журналы и отчёты.

## Review Focus

- **Затемнение: показать — убрать — показать подряд** (быстрая загрузка грида, потом новая). Ожидание: затемнение видно, не исчезает от прежнего «убрать»; убранное — уходит со страницы. Тест — `grids.js` (задача 1, зелёная всё время).
- **Щелчок по листалке, пока страница грузится.** Ожидание: ничего не происходит — второго запроса нет, загружается выбранная первой. Тест — `grids.js` (задача 1, зелёная всё время).
- **Окно в окне.** Ожидание: «Закрыть» внутреннего оставляет внешнее и затемнение, «Закрыть» внешнего убирает всё. Тест — `grids.js` (задача 1, зелёная всё время).
- **Вкладка языка в гриде** — данные вкладки теперь JSON. Ожидание: строки перезагружаются с `languageID` вкладки. Тест — `grids.js` (задача 1, зелёная всё время).
- **Выключенная вкладка** (форма файла до загрузки). Ожидание: не открывается, после загрузки — открывается. Тест — `editors.js`, шаг 12 (задача 1, зелёная всё время).

---

### Task 1: Проверки — листалка, затемнение, вкладки, окна, ошибка при вставке, категория `mootools`

**Files:**
- Modify: `tests/audit/grids.js` (два блока перед «журнал действий: фильтр по дате»; окна — в блоке «Настройки сайта»), `tests/audit/editors.js` (шаг 12 — выключенная вкладка; шаг 14 — вкладки формы), `tests/audit/public.js` (вход — значение без клавиш), `tests/no-traces.sh` (`VANILLA_JS`)

**Interfaces:**
- Consumes: помощники `grids.js` (`ctx`, `watch`, `check`, `BASE`), `editors.js` (`ctx`, `watch`, `check`, `BASE`), `public.js` (`open`, `fieldError`, `check`, `visitor`).
- Produces: проверки, по которым задачи 2–4 видят красное и зелёное; `VANILLA_JS` с четырьмя файлами.

- [ ] **Step 1: `tests/audit/grids.js` — затемнение и листалка, вкладки языков**

Перед блоком `// журнал действий: фильтр по дате — встроенное поле даты браузера` (внутри `try`, отступ 8 пробелов) вставить:

```js
        // затемнение (Overlay): показать — убрать — показать подряд оставляет его видимым (новая загрузка сразу после
        // быстрой); убранное после исчезновения уходит со страницы
        {
            const op = await ctx.newPage();
            await op.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const race = await op.evaluate(async () => {
                const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                const box = document.createElement('div');
                document.body.appendChild(box);
                const overlay = new Overlay(box);
                overlay.show();
                overlay.hide();
                overlay.show();
                await wait(900);
                const shown = { inDom: box.contains(overlay.element), opacity: +getComputedStyle(overlay.element).opacity };
                overlay.hide();
                await wait(900);
                const hidden = { inDom: box.contains(overlay.element) };
                box.remove();
                return { shown, hidden };
            });
            check('затемнение: показать — убрать — показать подряд оставляет его видимым', race.shown.inDom && race.shown.opacity > 0.4,
                JSON.stringify(race));
            check('затемнение: убранное после исчезновения уходит со страницы', !race.hidden.inDom, JSON.stringify(race));
            await op.close();
        }

        // листалка, затемнение и вкладки языков грида (PageList, Overlay, TabPane) — грид переводов: 18 страниц по 50
        // строк, вкладки двух языков. Щелчок по странице показывает другие строки и отмечает её текущей; пока страница
        // грузится, грид затемнён, а листалка не реагирует; после загрузки затемнения нет; на последней странице нет
        // стрелки «дальше»; вкладка другого языка перезагружает строки на этом языке. Грид в одну страницу — без листалки
        {
            const gp = await ctx.newPage();
            const gErrors = watch(gp);
            const loads = [];
            gp.on('request', (r) => { if (r.url().includes('/transEditor/get-data/')) loads.push({ url: r.url(), body: r.postData() || '' }); });
            await gp.goto(BASE + 'admin/translations/', { waitUntil: 'networkidle' });
            const state = () => gp.evaluate(() => {
                const list = document.querySelector('.e-pagelist');
                const items = list ? [...list.querySelectorAll('li')] : [];
                return {
                    visible: !!list && list.checkVisibility(),
                    current: ((list && list.querySelector('li.current')) || {}).textContent || '',
                    prev: items.some((li) => li.querySelector('img[alt="previous"]')),
                    next: items.some((li) => li.querySelector('img[alt="next"]')),
                    first: ((document.querySelector('tbody tr') || {}).textContent || '').trim(),
                    overlays: [...document.querySelectorAll('.e-overlay')].map((o) => +getComputedStyle(o).opacity),
                    tab: ((document.querySelector('ul.e-tabs li.current a')) || {}).textContent || '',
                    css: ['tabpane.css', 'pagelist.css'].map((name) => [...document.querySelectorAll('link[rel="stylesheet"]')]
                        .filter((l) => l.href.endsWith('/stylesheets/' + name)).length),
                };
            });
            const s1 = await state();
            check('грид переводов: листалка видна, текущая — 1, стрелки «назад» нет; стили вкладок и листалки — по разу',
                s1.visible && s1.current === '1' && !s1.prev && s1.next && s1.css.join() === '1,1', JSON.stringify(s1));
            // ответ сервера задерживается: видно затемнение и выключенную листалку
            await gp.route('**/transEditor/get-data/**', async (route) => {
                await new Promise((resolve) => setTimeout(resolve, 1500));
                await route.continue();
            });
            const before = loads.length;
            const loaded = gp.waitForResponse((r) => r.url().includes('/transEditor/get-data/'), { timeout: 15000 });
            await gp.click('.e-pagelist li[index="2"]');
            await gp.waitForTimeout(500);
            const during = await state();
            await gp.click('.e-pagelist li[index="3"]');
            await loaded;
            await gp.waitForTimeout(1000);
            const s2 = await state();
            check('листалка: пока страница грузится, грид затемнён', during.overlays.some((o) => o > 0), JSON.stringify(during));
            check('листалка: во время загрузки щелчок по другой странице ничего не делает', loads.length - before === 1,
                JSON.stringify(loads.slice(before)));
            check('листалка: страница 2 — другие строки, текущая — 2, стрелка «назад» есть, затемнения нет',
                s2.current === '2' && s2.first !== s1.first && s2.prev && !s2.overlays.length, JSON.stringify(s2));
            await gp.unroute('**/transEditor/get-data/**');
            await Promise.all([gp.waitForResponse((r) => r.url().includes('/transEditor/get-data/')), gp.click('.e-pagelist li[index="18"]')]);
            await gp.waitForTimeout(800);
            const s3 = await state();
            check('листалка: последняя страница — текущая, стрелки «дальше» нет', s3.current === '18' && !s3.next && s3.prev,
                JSON.stringify(s3));
            await Promise.all([gp.waitForResponse((r) => r.url().includes('/transEditor/get-data/')), gp.click('ul.e-tabs li:nth-child(2) a')]);
            await gp.waitForTimeout(800);
            const s4 = await state();
            const last = loads[loads.length - 1] || { body: '' };
            check('вкладка языка: строки перезагружены на этом языке с первой страницы',
                s4.tab === 'Українська' && /(^|&)languageID=2(&|$)/.test(last.body) && s4.current === '1', JSON.stringify({ s4, last }));
            check('грид переводов: без ошибок JS и 404', !gErrors.list().length, gErrors.list().join(' | '));
            await gp.close();

            const up = await ctx.newPage();
            await up.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const one = await up.evaluate(() => {
                const list = document.querySelector('.e-pagelist');
                return { exists: !!list, visible: !!list && list.checkVisibility() };
            });
            check('грид в одну страницу (пользователи): листалки не видно', one.exists && !one.visible, JSON.stringify(one));
            await up.close();
        }

```

- [ ] **Step 2: `tests/audit/grids.js` — окна**

В блоке «Настройки сайта» после проверки `'панель страницы: «Настройки сайта» — окно с гридом одной записи'` (внутри `if`, перед его закрывающей скобкой) вставить:

```js
            // окна (ModalBox, Overlay): Esc окно не закрывает (клиент просил не закрывать окно случайно); «Редактировать»
            // открывает второе окно поверх первого, его «Закрыть» оставляет первое и затемнение; «Закрыть» первого
            // убирает и окно, и затемнение; стили окон подключены один раз
            const boxes = () => sp.evaluate(() => ({
                boxes: document.querySelectorAll('.e-modalbox').length,
                overlays: [...document.querySelectorAll('.e-overlay')].map((o) => +getComputedStyle(o).opacity),
                css: [...document.querySelectorAll('link[rel="stylesheet"]')].filter((l) => l.href.endsWith('/stylesheets/modalbox.css')).length,
            }));
            if (frame) {
                await sp.waitForTimeout(700);
                await sp.keyboard.press('Escape');
                await sp.waitForTimeout(300);
                const esc = await boxes();
                check('окно: Esc его не закрывает', esc.boxes === 1 && esc.overlays.length === 1 && esc.overlays[0] > 0.4, JSON.stringify(esc));
                await frame.click('li.edit_btn');
                await sp.waitForFunction(() => document.querySelectorAll('.e-modalbox').length === 2, null, { timeout: 10000 }).catch(() => null);
                const innerEl = (await sp.$$('.e-modalbox iframe'))[1];
                const inner = innerEl && await innerEl.contentFrame();
                if (check('окно в окне: «Редактировать» открывает второе окно', !!inner)) {
                    await inner.waitForSelector('li.list_btn', { timeout: 10000 }).catch(() => null);
                    await inner.click('li.list_btn');
                    await sp.waitForTimeout(800);
                    const one = await boxes();
                    check('окно в окне: «Закрыть» второго оставляет первое и затемнение',
                        one.boxes === 1 && one.overlays.length === 1 && one.overlays[0] > 0.4, JSON.stringify(one));
                }
                await frame.click('li.close_btn');
                await sp.waitForTimeout(900);
                const none = await boxes();
                check('окно: «Закрыть» убирает окно и затемнение; стили окон подключены один раз',
                    none.boxes === 0 && !none.overlays.length && none.css === 1, JSON.stringify(none));
            }
```

- [ ] **Step 3: `tests/audit/editors.js` — выключенная вкладка (шаг 12) и вкладки формы (шаг 14)**

В шаге 12 после определения `state` (перед `const dir = fs.mkdtempSync(…)`) вставить:

```js
        // the second tab (the small picture) is closed until an image is uploaded (TabPane.disableTab, enableTab)
        const tabs = () => p.evaluate(() => [...document.querySelectorAll('ul.e-tabs li')].map((li) => {
            const href = li.querySelector('a').getAttribute('href');
            const pane = document.getElementById(href.slice(href.lastIndexOf('#') + 1));
            return { current: li.classList.contains('current'), disabled: li.classList.contains('disabled'), shown: !!pane && pane.checkVisibility() };
        }));
        await p.click('ul.e-tabs li:nth-child(2)');
        await p.waitForTimeout(200);
        let t = await tabs();
        check('форма файла: вкладка «Маленькое изображение» до загрузки выключена и не открывается',
            t.length === 2 && t[1].disabled && !t[1].current && !t[1].shown && t[0].current && t[0].shown, JSON.stringify(t));
```

В шаге 12 после строки `const j = await ok.json().catch(() => null);` и следующей за ней `await p.waitForTimeout(500);` вставить:

```js
            t = await tabs();
            check('форма файла: после загрузки картинки вкладка «Маленькое изображение» включена', !t[1].disabled, JSON.stringify(t));
            await p.click('ul.e-tabs li:nth-child(2)');
            await p.waitForTimeout(200);
            t = await tabs();
            check('форма файла: включённая вкладка открывается, прежняя прячется', t[1].current && t[1].shown && !t[0].current && !t[0].shown,
                JSON.stringify(t));
            await p.click('ul.e-tabs li:nth-child(1)');
```

После шага 13 (перед `    await browser.close();`) вставить:

```js
    // 14. tabs of a form (TabPane): a click on a tab shows its pane, hides the previous one, marks the tab current and
    //     puts the focus into the pane's first text field
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'admin/mail-templates/single/mailTemplateEditor/1/edit/', { waitUntil: 'networkidle' });
        const tabsState = () => p.evaluate(() => [...document.querySelectorAll('ul.e-tabs li')].map((li) => {
            const href = li.querySelector('a').getAttribute('href');
            const pane = document.getElementById(href.slice(href.lastIndexOf('#') + 1));
            return { current: li.classList.contains('current'), shown: !!pane && pane.checkVisibility(),
                focus: !!pane && pane.contains(document.activeElement) };
        }));
        // the tab of the second language's name field
        const idx = await p.evaluate(() => {
            const pane = document.getElementById('template_name_2').closest('.e-pane-item');
            return [...document.querySelectorAll('ul.e-tabs li')].findIndex((li) => li.querySelector('a').getAttribute('href').endsWith('#' + pane.id));
        });
        const before = await tabsState();
        const was = before.findIndex((t) => t.current);
        await p.click(`ul.e-tabs li:nth-child(${idx + 1})`);
        await p.waitForTimeout(300);
        const after = await tabsState();
        check('вкладки формы: щелчок показывает панель вкладки, прячет прежнюю, отмечает вкладку и ставит фокус в первое поле',
            idx > 0 && idx !== was && after[idx].current && after[idx].shown && after[idx].focus && !after[was].current && !after[was].shown,
            JSON.stringify({ idx, was, before, after }));
        check('вкладки формы: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    }

```

- [ ] **Step 4: `tests/audit/public.js` — значение без клавиш убирает ошибку**

В шаге 2 (вход) заменить:
```js
            await p.locator('#username').pressSequentially(visitor.login);
```
на:
```js
            // a value put in without keys (paste, autofill) removes the field's error at once
            await p.fill('#username', visitor.login);
            const pasted = await fieldError(p, '#username');
            check('вход: значение, вставленное без клавиш, сразу убирает ошибку поля', !pasted.invalid && pasted.error === '',
                JSON.stringify(pasted));
```
(пароль по-прежнему набирается по клавише — `pressSequentially`).

- [ ] **Step 5: `tests/no-traces.sh` — `VANILLA_JS`**

Список заменить на:
```bash
VANILLA_JS=(core/modules/share/scripts/Energine.js core/modules/share/scripts/Validator.js
            core/modules/share/scripts/ValidForm.js core/modules/user/scripts/LoginForm.js
            core/modules/user/scripts/Register.js core/modules/user/scripts/UserProfile.js
            core/modules/share/scripts/Overlay.js core/modules/share/scripts/ModalBox.js
            core/modules/share/scripts/TabPane.js core/modules/share/scripts/PageList.js)
```

- [ ] **Step 6: Новые проверки — на нынешнем коде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step2-admin-building-blocks
bash -n tests/no-traces.sh && for t in grids editors public; do node --check tests/audit/$t.js; done
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools > "$L/t1-no-traces.log" 2>&1; echo "no-traces $?"; head -5 "$L/t1-no-traces.log"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t1-regression.log" 2>&1; echo "regression $?"
cd tests/audit && for t in grids editors public; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/t1-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t1-$t.log" | head -10; done; cd ../..
```
Expected: `no-traces` — выход 1 (конструкции MooTools в четырёх файлах); регрессия — выход 0 (она создаёт `tests/claude-test.png` для `editors.js`); `grids` и `editors` — выход 0 (новые проверки проходят на нынешнем коде); `public` — выход 1, единственный провал «значение, вставленное без клавиш, сразу убирает ошибку поля».

- [ ] **Step 7: Commit**

```bash
git add tests/audit/grids.js tests/audit/editors.js tests/audit/public.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 2: проверки — листалка, затемнение, вкладки, окна, ошибка при вставке" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `Energine.loadCSS`, `Overlay`, `ModalBox` на чистом JavaScript

**Files:**
- Modify: `core/modules/share/scripts/Energine.js` (добавить `Energine.loadCSS`), `core/modules/share/scripts/Overlay.js`, `core/modules/share/scripts/ModalBox.js` (переписать целиком)

**Interfaces:**
- Consumes: проверки `grids.js` (затемнение, окна) и `editors.js` (окна редактора) из задачи 1.
- Produces: `Energine.loadCSS(name: string)`; `new Overlay(parentElement?: Element, options?: {opacity, duration, indicator})` с `show()`, `hide()`, `element`; `ModalBox` с `init()`, `open(options)`, `close()`, `getCurrent()`, `getExtraData()`, `setReturnValue(value)`, `initialized`, `boxes`, `overlay`.

- [ ] **Step 1: `Energine.js` — `Energine.loadCSS`** — после определения `Energine.csrfInput` вставить:

```js
/**
 * Стили элемента админки: stylesheets/<имя> подключается один раз. Для скриптов на MooTools то же делает Asset.css
 * (вставка Energine в mootools.min.js); файл, уже подключённый ссылкой, второй раз не грузится.
 *
 * @param {string} name Имя файла в stylesheets/.
 */
Energine.loadCSS = function (name) {
    var href = new URL((Energine['static'] || '') + 'stylesheets/' + name, document.baseURI).href;
    var links = document.querySelectorAll('link[rel="stylesheet"]');
    for (var i = 0; i < links.length; i++) {
        if (links[i].href === href) {
            return;
        }
    }
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.media = 'Screen, projection';
    link.href = href;
    document.head.appendChild(link);
};
```

- [ ] **Step 2: `Overlay.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Overlay]{@link Overlay}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Затемнение («занято»): полупрозрачный слой поверх элемента, по умолчанию — поверх всей страницы верхнего окна.
 *
 * @constructor
 * @param {Element} [parentElement] Что затемняется; по умолчанию — body верхнего окна.
 * @param {Object} [options]
 * @param {number} [options.opacity = 0.5] Непрозрачность видимого затемнения.
 * @param {number} [options.duration = 500] Длительность появления и исчезновения, мс.
 * @param {boolean} [options.indicator = true] Знак загрузки (класс e-overlay-loading).
 */
var Overlay = class Overlay {
    constructor(parentElement, options) {
        this.options = Object.assign({duration: 500, opacity: 0.5, indicator: true}, options);
        this.container = parentElement || window.top.document.body;
        this.element = document.createElement('div');
        this.element.className = 'e-overlay' + (this.options.indicator ? ' e-overlay-loading' : '');
        this.element.style.opacity = '0';
        this.element.style.transition = 'opacity ' + this.options.duration + 'ms ease-in-out';
        this.removal = null;
    }

    show() {
        clearTimeout(this.removal);
        this.removal = null;
        // у элемента одно затемнение: если оно уже есть, второе не добавляется
        if (![...this.container.children].some((child) => child.classList.contains('e-overlay'))) {
            this.container.appendChild(this.element);
        }
        // без расчёта начального состояния браузер не показал бы появление
        void this.element.offsetWidth;
        this.element.style.opacity = String(this.options.opacity);
    }

    // затемнение исчезает и уходит со страницы; новое show() до конца исчезновения его оставляет
    hide() {
        this.element.style.opacity = '0';
        clearTimeout(this.removal);
        this.removal = setTimeout(() => {
            this.removal = null;
            this.element.remove();
        }, this.options.duration);
    }
};
```

- [ ] **Step 3: `ModalBox.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ModalBox]{@link ModalBox}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires Overlay
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Overlay');

/**
 * Окна админки: страница в iframe поверх текущей. Объект общий для вложенных окон: внутри окна работает объект
 * верхнего окна (window.top.ModalBox), и окна открываются друг над другом в одном документе. Щелчок по затемнению и
 * Esc окно не закрывают — клиент просил не закрывать окно случайно.
 *
 * @namespace
 */
var ModalBox = window.top.ModalBox || /** @lends ModalBox */{
    /**
     * Открытые окна, последнее — верхнее.
     * @type {Element[]}
     */
    boxes: [],

    /**
     * @type {boolean}
     */
    initialized: false,

    // стили окон и общее затемнение (без знака загрузки)
    init: function () {
        Energine.loadCSS('modalbox.css');
        this.overlay = new Overlay(null, {indicator: false});
        this.initialized = true;
    },

    /**
     * Открыть окно.
     *
     * @param {Object} options
     * @param {string} [options.url] Адрес страницы окна.
     * @param {string} [options.post] Данные, которые уходят в окно формой (поле modalBoxData, с токеном).
     * @param {Element} [options.code] Элемент вместо страницы.
     * @param {function} [options.onClose] Вызывается при закрытии со значением из setReturnValue.
     * @param {*} [options.extraData] Данные для страницы окна (getExtraData).
     */
    open: function (options) {
        var box = document.createElement('div');
        box.className = 'e-modalbox';
        document.body.appendChild(box);
        box.options = Object.assign({url: null, onClose: function () {}, extraData: null, post: null}, options);

        if (box.options.url) {
            var name = 'modalBoxIframe' + this.boxes.length,
                src = box.options.url,
                form = null;
            if (box.options.post) {
                form = document.createElement('form');
                form.target = name;
                form.action = src;
                form.method = 'post';
                var data = document.createElement('input');
                data.type = 'hidden';
                data.name = 'modalBoxData';
                data.value = box.options.post;
                form.appendChild(data);
                form.appendChild(Energine.csrfInput());
                src = 'about:blank';
            }
            var iframe = document.createElement('iframe');
            iframe.name = name;
            iframe.src = src;
            iframe.frameBorder = '0';
            iframe.scrolling = 'no';
            iframe.className = 'e-modalbox-frame';
            box.iframe = iframe;
            box.appendChild(iframe);
            if (form) {
                box.appendChild(form);
                form.submit();
                form.remove();
            }
        } else if (box.options.code) {
            box.appendChild(box.options.code);
        }

        this.boxes.push(box);
        if (this.boxes.length === 1) {
            this.overlay.show();
        }
    },

    /**
     * @returns {Element|null} Верхнее окно.
     */
    getCurrent: function () {
        return this.boxes.length ? this.boxes[this.boxes.length - 1] : null;
    },

    getExtraData: function () {
        var box = this.getCurrent();
        return box ? box.options.extraData : null;
    },

    // значение, которое получит onClose верхнего окна
    setReturnValue: function (value) {
        var box = this.getCurrent();
        if (box) {
            box.returnValue = value;
        }
    },

    close: function () {
        if (!this.boxes.length) {
            return;
        }
        var box = this.boxes.pop();
        box.options.onClose(box.returnValue);
        // окно убирается после обработчика: он ещё может читать страницу окна
        setTimeout(function () {
            if (box.iframe) {
                box.iframe.src = 'about:blank';
                box.iframe.remove();
            }
            box.remove();
        }, 1);
        if (!this.boxes.length) {
            this.overlay.hide();
        }
    }
};

if (!ModalBox.initialized) {
    document.addEventListener('DOMContentLoaded', function () {
        ModalBox.init();
    });
}
```

- [ ] **Step 4: Пересобрать стенд и проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step2-admin-building-blocks
for f in Energine Overlay ModalBox; do node --check core/modules/share/scripts/$f.js || echo "BAD $f"; done
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
php8.5 -r '$m = include "/tmp/stand-web97/site/web/system.jsmap.php"; echo json_encode(["ModalBox" => $m["ModalBox"] ?? null, "Overlay" => $m["Overlay"] ?? null]), "\n";'
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t2-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t2-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in grids editors crawl theme; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t2-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t2-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t2-$t.log" | head -10; done; cd ../..
```
Expected: синтаксис без ошибок; карта: `ModalBox` → `["Overlay"]`, `Overlay` → `null`; регрессия — выход 0; `grids`, `editors`, `crawl`, `theme` — выход 0.

- [ ] **Step 5: Commit**

```bash
git add core/modules/share/scripts/Energine.js core/modules/share/scripts/Overlay.js core/modules/share/scripts/ModalBox.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 2: затемнение и окна админки на чистом JavaScript, Energine.loadCSS" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: `TabPane`, `PageList` на чистом JavaScript, данные вкладок — JSON

**Files:**
- Modify: `core/modules/share/scripts/TabPane.js`, `core/modules/share/scripts/PageList.js` (переписать целиком), `core/modules/share/transformers/list.xslt:100`, `core/modules/share/transformers/form.xslt:81`

**Interfaces:**
- Consumes: `Energine.loadCSS` (задача 2); проверки `grids.js` (листалка, вкладки языков) и `editors.js` (шаги 12–14) из задачи 1.
- Produces: `new TabPane(element: Element|string, options?: {onTabChange(data)})` — `element`, `tabs` (массив `li`, у каждого `data`, `pane`), `currentTab`, `show(tab)`, `getTabs()`, `whereIs(element)`, `enableTab(index)`, `disableTab(index)`; `new PageList(options?: {onPageSelect(page)})` — `build(numPages, currentPage)`, `enable()`, `disable()`, `getElement()`, `currentPage`.

- [ ] **Step 1: `list.xslt` и `form.xslt` — данные вкладки JSON**

`core/modules/share/transformers/list.xslt`: `<span class="data">{ lang: <xsl:value-of select="$FIELDS[@tabName=$TAB_NAME]/@language"/> }</span>` → `<span class="data">{"lang": <xsl:value-of select="$FIELDS[@tabName=$TAB_NAME]/@language"/>}</span>`.

`core/modules/share/transformers/form.xslt`: `<span class="data">{ lang: <xsl:value-of select="$FIELDS[@tabName=$TAB_NAME][1]/@language" /> }</span>` → `<span class="data">{"lang": <xsl:value-of select="$FIELDS[@tabName=$TAB_NAME][1]/@language" />}</span>`.

- [ ] **Step 2: `TabPane.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[TabPane]{@link TabPane}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Вкладки формы или грида: ul.e-tabs (li > a[href="#панель"]) и панели div#панель. Несколько вкладок могут вести на
 * одну панель (вкладки языков грида). Данные вкладки — JSON в span.data ({"lang": N}).
 *
 * @constructor
 * @param {Element|string} element
 * @param {Object} [options]
 * @param {function} [options.onTabChange] Вызывается при смене вкладки с её данными.
 */
var TabPane = class TabPane {
    constructor(element, options) {
        Energine.loadCSS('tabpane.css');
        this.options = Object.assign({}, options);
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;

        const list = this.element.querySelector('ul.e-tabs');
        list.classList.add('clearfix');
        this.tabs = [...list.querySelectorAll('li')];
        this.currentTab = this.tabs[0];
        this.element.classList.add('e-items-count-' + this.tabs.length);

        this.tabs.forEach((tab) => {
            tab.setAttribute('unselectable', 'on');
            const anchor = tab.querySelector('a');
            const href = anchor.getAttribute('href');
            anchor.addEventListener('click', (event) => event.preventDefault());

            const data = tab.querySelector('span.data');
            tab.data = data ? JSON.parse(data.textContent) : {};
            tab.pane = this.element.querySelector('div#' + CSS.escape(href.slice(href.lastIndexOf('#') + 1)));
            tab.pane.classList.add('e-pane-item');
            tab.pane.style.display = 'none';
            tab.pane.tab = tab;

            tab.addEventListener('mouseover', () => {
                if (tab !== this.currentTab) {
                    tab.classList.add('highlighted');
                }
            });
            tab.addEventListener('mouseout', () => tab.classList.remove('highlighted'));
            tab.addEventListener('click', () => {
                if (tab !== this.currentTab && !tab.classList.contains('disabled')) {
                    this.show(tab);
                }
            });
        });

        this.selectTab(this.currentTab);
    }

    show(tab) {
        this.selectTab(tab);
        if (this.options.onTabChange) {
            this.options.onTabChange(this.currentTab.data);
        }
    }

    // вкладка становится текущей, её панель — видимой; фокус — в первое текстовое поле панели
    selectTab(tab) {
        if (!tab) {
            return;
        }
        this.currentTab.classList.remove('current');
        this.currentTab.pane.style.display = 'none';
        tab.classList.add('current');
        tab.pane.style.display = '';
        this.currentTab = tab;

        const firstInput = tab.pane.querySelector('div.field div.control input[type=text]')
            || tab.pane.querySelector('div.field div.control textarea');
        if (firstInput) {
            firstInput.focus();
        }
    }

    getTabs() {
        return this.tabs;
    }

    // вкладка, на панели которой лежит элемент (null — не на вкладке)
    whereIs(element) {
        for (let el = element.parentElement; el; el = el.parentElement) {
            if (el.classList.contains('e-pane-item') && el.tab) {
                return el.tab;
            }
        }
        return null;
    }

    enableTab(tabIndex) {
        if (this.tabs[tabIndex]) {
            this.tabs[tabIndex].classList.remove('disabled');
        }
    }

    disableTab(tabIndex) {
        if (this.tabs[tabIndex]) {
            this.tabs[tabIndex].classList.add('disabled');
        }
    }
};
```

- [ ] **Step 3: `PageList.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageList]{@link PageList}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

/**
 * Листалка страниц грида: номера около текущей, первые и последние страницы, многоточия, стрелки.
 *
 * @constructor
 * @param {Object} [options]
 * @param {function} [options.onPageSelect] Вызывается с номером выбранной страницы.
 */
var PageList = class PageList {
    constructor(options) {
        Energine.loadCSS('pagelist.css');
        this.options = Object.assign({}, options);
        this.currentPage = 1;
        this.disabled = false;
        this.element = document.createElement('ul');
        this.element.className = 'e-pane-toolbar e-pagelist';
        this.element.setAttribute('unselectable', 'on');
    }

    getElement() {
        return this.element;
    }

    // пока грид грузится, листалка полупрозрачна и не реагирует
    disable() {
        this.disabled = true;
        this.element.style.opacity = '0.25';
    }

    enable() {
        this.disabled = false;
        this.element.style.opacity = '1';
    }

    build(numPages, currentPage) {
        this.currentPage = currentPage;
        this.element.replaceChildren();
        if (numPages <= 1) {
            this.element.style.display = 'none';
            return;
        }
        this.element.style.display = '';

        // сколько номеров видно с каждой стороны от текущего
        const VISIBLE_PAGES_COUNT = 2;
        const startPage = (currentPage > VISIBLE_PAGES_COUNT) ? currentPage - VISIBLE_PAGES_COUNT : 1;
        const endPage = Math.min(currentPage + VISIBLE_PAGES_COUNT, numPages);
        const add = (title, index) => this.element.appendChild(this.createPageLink(title, index));

        if (startPage > 1) {
            add(1, 1);
            if (startPage > 2) {
                add(2, 2);
                if (startPage > 3) {
                    add('...');
                }
            }
        }
        for (let i = startPage; i <= endPage; i++) {
            add(i, i);
        }
        if (endPage < numPages) {
            if (endPage < numPages - 1) {
                if (endPage < numPages - 2) {
                    add('...');
                }
                add(numPages - 1, numPages - 1);
            }
            add(numPages, numPages);
        }
        this.element.querySelector('li[index="' + this.currentPage + '"]').classList.add('current');

        if (currentPage != 1) {
            this.element.prepend(this.createPageLink('previous', currentPage - 1, 'images/prev_page.gif'));
        }
        if (currentPage != numPages) {
            this.element.appendChild(this.createPageLink('next', currentPage + 1, 'images/next_page.gif'));
        }
    }

    selectPage(listItem) {
        const current = this.element.querySelector('li.current');
        if (current) {
            current.classList.remove('current');
        }
        this.currentPage = parseInt(listItem.getAttribute('index'), 10);
        if (this.options.onPageSelect) {
            this.options.onPageSelect(this.currentPage);
        }
    }

    // пункт листалки: номер, многоточие (index 0 — без действий) или стрелка-картинка
    createPageLink(title, index, image) {
        index = index || 0;
        const listItem = document.createElement('li');
        if (image) {
            const img = document.createElement('img');
            img.src = image;
            img.setAttribute('border', '0');
            img.setAttribute('align', 'absmiddle');
            img.alt = title;
            img.title = title;
            img.style.width = '6px';
            img.style.height = '11px';
            listItem.appendChild(img);
        } else {
            listItem.appendChild(document.createTextNode(title));
        }
        listItem.setAttribute('index', index);

        if (index) {
            listItem.addEventListener('mouseover', () => {
                if (!this.disabled) {
                    listItem.classList.add('highlighted');
                }
            });
            listItem.addEventListener('mouseout', () => listItem.classList.remove('highlighted'));
            listItem.addEventListener('click', () => {
                if (!this.disabled && listItem.getAttribute('index') != String(this.currentPage)) {
                    this.selectPage(listItem);
                }
            });
        }
        return listItem;
    }
};
```

- [ ] **Step 4: Пересобрать стенд и проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step2-admin-building-blocks
for f in TabPane PageList; do node --check core/modules/share/scripts/$f.js || echo "BAD $f"; done
for x in list form; do php8.5 -r '$d = new DOMDocument(); exit($d->load("core/modules/share/transformers/'"$x"'.xslt") ? 0 : 1);' && echo "$x xml-ok"; done
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools; echo "no-traces $?"
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t3-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t3-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in grids editors crawl theme; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t3-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t3-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t3-$t.log" | head -10; done; cd ../..
```
Expected: синтаксис без ошибок; `no-traces code mootools` — выход 0; регрессия — выход 0; `grids`, `editors`, `crawl`, `theme` — выход 0.

- [ ] **Step 5: Commit**

```bash
git add core/modules/share/scripts/TabPane.js core/modules/share/scripts/PageList.js core/modules/share/transformers/list.xslt core/modules/share/transformers/form.xslt
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 2: вкладки и листалка админки на чистом JavaScript, данные вкладок — JSON" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: `Validator` — ошибка уходит и при вставке

**Files:**
- Modify: `core/modules/share/scripts/Validator.js` (`validateElement`)

**Interfaces:**
- Consumes: проверка `public.js` «значение, вставленное без клавиш, сразу убирает ошибку поля» (задача 1).
- Produces: у поля с ошибкой — слушатели `blur` (проверка), `keydown` и `input` (снять ошибку).

- [ ] **Step 1: Правка** — в `validateElement` заменить:

```js
        // после первой ошибки поле проверяется при уходе с него, а ввод убирает ошибку
        if (!field.getAttribute('check')) {
            field.addEventListener('blur', () => this.validateElement(field));
            field.addEventListener('keydown', () => this.removeError(field));
            field.setAttribute('check', 'check');
        }
```
на:
```js
        // после первой ошибки поле проверяется при уходе с него, а ввод убирает ошибку — и с клавиатуры, и вставкой
        // или автозаполнением (они клавиш не нажимают, и без этого кнопка уезжала бы из-под щелчка)
        if (!field.getAttribute('check')) {
            field.addEventListener('blur', () => this.validateElement(field));
            field.addEventListener('keydown', () => this.removeError(field));
            field.addEventListener('input', () => this.removeError(field));
            field.setAttribute('check', 'check');
        }
```

- [ ] **Step 2: Проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step2-admin-building-blocks
node --check core/modules/share/scripts/Validator.js
cd tests/audit && for t in public editors; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/t4-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t4-$t.log" | head; done; cd ../..
```
Expected: `public` и `editors` — выход 0.

- [ ] **Step 3: Commit**

```bash
git add core/modules/share/scripts/Validator.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 2: ошибка под полем уходит и при вставке и автозаполнении" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Документы и итоговая проверка

**Files:**
- Modify: `README.md` (абзац об этапе 8), `tests/README.md` (разделы «Гриды админки», «Редакторы и загрузка», «Публичные страницы без MooTools»)

- [ ] **Step 1: `README.md`** — в абзаце об этапе 8 после предложения «Шаг 1 сделан: … с прежним интерфейсом.» дописать: «Шаг 2 (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md`): основа админки — затемнение, окна, вкладки и листалка — тоже на чистом JavaScript.» и в список спецификаций — строку `` `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step2-admin-building-blocks-design.md` (этап 8, шаг 2) ``.
- [ ] **Step 2: `tests/README.md`** — в «Гриды админки»: «затемнение: показать — убрать — показать подряд оставляет его видимым, убранное уходит; грид переводов: листалка (другие строки на странице 2, во время загрузки затемнение и листалка не реагирует, на последней странице нет стрелки «дальше»), вкладка языка перезагружает строки на этом языке; грид в одну страницу — без листалки; окна «Настройки сайта»: Esc их не закрывает, окно в окне, «Закрыть» убирает окно и затемнение, стили окон — один раз.» В «Редакторы и загрузка» — пункты «вкладка формы файла выключена до загрузки картинки и открывается после» и «вкладки формы: щелчок показывает панель, прячет прежнюю, фокус — в первое поле». В «Публичные страницы без MooTools» — «значение, вставленное без клавиш, сразу убирает ошибку поля».
- [ ] **Step 3: Итоговая проверка на чистом стенде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step2-admin-building-blocks
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/no-traces.sh all > "$L/final-no-traces.log" 2>&1; echo "no-traces $?"
bash tests/tools/stand.sh run bash tests/tools/install-check.sh > "$L/final-install.log" 2>&1; echo "install $?"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/final-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/final-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in public grids editors theme crawl; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/final-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/final-$t.log" 2>&1; echo "$t exit $?"; done; cd ../..
bash tests/tools/stand.sh run bash tests/tools/fresh-check.sh > "$L/final-fresh.log" 2>&1; echo "fresh $?"
```
Expected: всё — выход 0.

- [ ] **Step 4: Commit**

```bash
git add README.md tests/README.md
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 2: документы" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Выкладка на simple.energine.org

Требует отдельного «да» владельца. База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step2-<дата>/`.
- [ ] **Step 2: Код** — от имени web97: `git -C <живое дерево> fetch <клон> main && git -C <живое дерево> merge --ff-only FETCH_HEAD`.
- [ ] **Step 3: Статика** — в `web/` от web97: `php8.5 index.php setup linker && php8.5 index.php setup scriptMap`; карта: `ModalBox` → `Overlay`, у `TabPane`, `PageList`, `Overlay` зависимостей нет.
- [ ] **Step 4: Проверка** — гостем: публичные страницы без MooTools и ошибок JS; регрессию и аудиты на площадке — по слову владельца; после прогонов от root — `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 5: Откат при провале** — от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`.
