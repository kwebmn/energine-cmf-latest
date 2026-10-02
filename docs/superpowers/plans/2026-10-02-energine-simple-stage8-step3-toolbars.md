# Energine Simple, этап 8, шаг 3 — панели админки без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** панели кнопок админки (`Toolbar` и кнопки) и панель страницы (`PageToolbar`) работают на чистом JavaScript с прежним интерфейсом; администратор на страницах сайта вне режима правки не получает MooTools.

**Architecture:** `Toolbar.js` и `PageToolbar.js` переписываются классами JavaScript (`Toolbar.Button extends Toolbar.Control` и т. д., `PageToolbar extends Toolbar`) без объявления `MooCompat`; оба файла меняются одной задачей — класс MooTools не может наследовать класс JavaScript. Скрипты на MooTools (гриды, формы, дерево) пользуются панелями как прежде; неиспользуемые классы и методы уходят.

**Tech Stack:** JavaScript (классические скрипты, классы), Playwright (аудиты), bash.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step3-toolbars-design.md`

## Global Constraints

- Только современные браузеры; без сборки, npm и ES-модулей; классы — `var Имя = class Имя …`, вложенные — `Toolbar.Button = class ToolbarButton extends Toolbar.Control …`.
- Интерфейс панелей для скриптов на MooTools и встроенных скриптов XSLT — прежний (спецификация, разделы 3.1–3.2); разметка и классы прежние.
- Зависимости скрипта — первый вызов `ScriptLoader.load('…')` в файле; в комментариях такой вызов с именами в кавычках не пишется.
- В файлах из `VANILLA_JS` (`tests/no-traces.sh`) нет конструкций MooTools — и в комментариях тоже.
- Комментарии — по-русски; строки `@author` в шапках остаются.
- Проверки — только на стенде (`tests/tools/stand.sh`); площадка — только в задаче 4 после «да» владельца.
- Коммиты — `bash tests/tools/stand.sh run git commit …`; последняя строка сообщения — `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Пароли и учётные данные не попадают в файлы, журналы и отчёты.

## Review Focus

- **Пустой `class` у кнопок гридов.** Шаблон `toolbar.xslt` передаёт `class: ''` каждой кнопке; `classList.add('')` бросает исключение, и панель грида не построилась бы. Ожидание: кнопки на месте и работают. Тест — `grids.js`, «панель грида» (задача 1).
- **Кнопка, выключенная в описании** (`disabled: 'disabled'`). Ожидание: после `enableControls()` остаётся выключенной и не срабатывает; `enable(true)` её включает. Тест — `grids.js`, «кнопки панели» (задача 1).
- **Выключенный переключатель.** Ожидание: щелчок не меняет состояние и не вызывает действие. Тест — `grids.js`, «кнопки панели» (задача 1).
- **Смена выпадающего списка панели.** Ожидание: вызывается действие с самим списком, `getValue()` возвращает выбранное. Тест — `grids.js`, «кнопки панели» (задача 1).
- **Нажатие мыши на кнопку панели формы.** Ожидание: фокус остаётся в поле (прежний код гасил `mousedown`). Тест — `editors.js`, шаг 15 (задача 1).

---

### Task 1: Проверки — панель страницы, панель грида, кнопки, панель формы, переключатель режима правки

**Files:**
- Modify: `tests/audit/grids.js` (три блока перед «Настройки сайта»), `tests/audit/editors.js` (шаги 15–16), `tests/no-traces.sh` (`VANILLA_JS`)

**Interfaces:**
- Consumes: помощники `grids.js` (`ctx`, `watch`, `check`, `BASE`), `editors.js` (`ctx`, `watch`, `check`, `BASE`, `showTabOf`, `isJodit`).
- Produces: проверки, по которым задача 2 видит красное и зелёное; `VANILLA_JS` с `Toolbar.js` и `PageToolbar.js`.

- [ ] **Step 1: `tests/audit/grids.js` — панель страницы, панель грида, кнопки панели**

Перед блоком `// «Настройки сайта» с панели страницы: окно с гридом единственной записи сайта` вставить:

```js
        // панель страницы (PageToolbar) у администратора на главной: верхняя рамка с панелью, страница — в основной
        // рамке, значок, боковая панель с iframe; щелчок по значку открывает боковую панель и запоминает это в cookie,
        // второй закрывает; стили панелей — по разу; MooTools в документе страницы не запрашивается и не определена (вне
        // режима правки панель страницы — единственный скрипт админки там)
        {
            const hp = await ctx.newPage();
            const hErrors = watch(hp);
            const moo = [];
            hp.on('request', (r) => { if (/mootools/i.test(r.url()) && r.frame() === hp.mainFrame()) moo.push(r.url()); });
            await hp.goto(BASE, { waitUntil: 'networkidle' });
            const st = () => hp.evaluate(() => ({
                html: document.documentElement.className,
                top: !!document.querySelector('body > .e-topframe ul.toolbar.docked_toolbar li.editMode_btn'),
                main: !!document.querySelector('body > .e-mainframe'),
                logo: !!document.querySelector('.e-topframe img.pagetb_logo'),
                side: ((document.querySelector('.e-sideframe .e-sideframe-content iframe') || {}).src || ''),
                css: ['toolbar.css', 'pagetoolbar.css'].map((name) => [...document.querySelectorAll('link[rel="stylesheet"]')]
                    .filter((l) => l.href.endsWith('/stylesheets/' + name)).length),
                moo: typeof window.MooTools !== 'undefined',
            }));
            const s = await st();
            check('панель страницы: верхняя рамка с панелью, страница — в основной рамке, значок, боковая панель; стили — по разу',
                /\be-has-topframe1\b/.test(s.html) && s.top && s.main && s.logo && /\/show\/$/.test(s.side) && s.css.join() === '1,1',
                JSON.stringify(s));
            check('панель страницы: MooTools у администратора на главной не запрашивается и не определена', !moo.length && !s.moo,
                moo.join(' ') || 'MooTools определена');
            const sidebar = async () => ((await ctx.cookies(BASE)).find((c) => c.name === 'sidebar') || {}).value;
            await hp.click('.e-topframe img.pagetb_logo');
            const open = { html: (await st()).html, cookie: await sidebar() };
            await hp.click('.e-topframe img.pagetb_logo');
            const closed = { html: (await st()).html, cookie: await sidebar() };
            check('панель страницы: значок открывает боковую панель и запоминает это, второй щелчок закрывает',
                /\be-has-sideframe\b/.test(open.html) && open.cookie === '1' && !/\be-has-sideframe\b/.test(closed.html) && closed.cookie === '0',
                JSON.stringify({ open, closed }));
            check('панель страницы: без ошибок JS и 404', !hErrors.list().length, hErrors.list().join(' | '));
            await hp.close();
        }

        // панель грида (Toolbar, кнопки из toolbar.xslt — с пустым class): выключенная кнопка ничего не делает,
        // включённая выполняет действие (окно добавления)
        {
            const tp = await ctx.newPage();
            const tErrors = watch(tp);
            await tp.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const toolbar = (method) => tp.evaluate((m) => {
                const id = Object.keys(window.componentToolbars)[0];
                window.componentToolbars[id][m]('add');
            }, method);
            const boxes = () => tp.evaluate(() => document.querySelectorAll('.e-modalbox').length);
            const buttons = await tp.evaluate(() => ['add_btn', 'edit_btn', 'delete_btn'].filter((c) => document.querySelector('ul.toolbar li.' + c)).length);
            await toolbar('disableControls');
            const off = await tp.evaluate(() => document.querySelector('li.add_btn').classList.contains('disabled'));
            await tp.click('li.add_btn');
            await tp.waitForTimeout(800);
            const whenOff = await boxes();
            await toolbar('enableControls');
            await tp.click('li.add_btn');
            await tp.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const whenOn = await boxes();
            check('панель грида: кнопки на месте; выключенная ничего не делает, включённая открывает окно добавления',
                buttons === 3 && off && whenOff === 0 && whenOn === 1, JSON.stringify({ buttons, off, whenOff, whenOn }));
            await tp.evaluate(() => ModalBox.close());
            await tp.waitForTimeout(700);
            check('панель грида: без ошибок JS и 404', !tErrors.list().length, tErrors.list().join(' | '));
            await tp.close();
        }

        // кнопки панели (Toolbar): выключенная в описании остаётся выключенной после enableControls() и включается
        // enable(true); выключенный переключатель не меняет состояние и не вызывает действие; смена списка вызывает
        // действие с самим списком, getValue() — выбранное значение
        {
            const ap = await ctx.newPage();
            const aErrors = watch(ap);
            await ap.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const api = await ap.evaluate(() => {
                const calls = [];
                const box = document.createElement('div');
                document.body.appendChild(box);
                const tb = new Toolbar('claude_tb');
                tb.bindTo({ act: (data) => calls.push(data && data.properties ? 'select:' + data.getValue() : 'act') });
                tb.appendControl(new Toolbar.Button({ id: 'off', title: 'Off', action: 'act', disabled: 'disabled' }),
                    new Toolbar.Switcher({ id: 'sw', title: 'Sw', action: 'act', state: '0' }),
                    new Toolbar.Select({ id: 'sel', title: 'Sel', action: 'act' }, { a: 'A', b: 'B' }, 'a'));
                box.appendChild(tb.getElement());
                tb.enableControls();
                const off = tb.getControlById('off');
                const stillOff = !!off.disabled() && off.element.classList.contains('disabled');
                off.element.click();
                const callsWhenOff = calls.length;
                off.enable(true);
                const nowOn = !off.disabled() && !off.element.classList.contains('disabled');
                const sw = tb.getControlById('sw');
                sw.disable();
                sw.element.click();
                const swState = { state: sw.getState(), pressed: sw.element.classList.contains('pressed'), calls: calls.length };
                const sel = tb.getControlById('sel');
                const initial = sel.getValue();
                sel.select.value = 'b';
                sel.select.dispatchEvent(new Event('change'));
                const result = { stillOff, callsWhenOff, nowOn, swState, initial, calls: calls.slice(), value: sel.getValue() };
                box.remove();
                return result;
            });
            check('кнопки панели: выключенная в описании остаётся выключенной после enableControls(), enable(true) её включает',
                api.stillOff && api.callsWhenOff === 0 && api.nowOn, JSON.stringify(api));
            check('кнопки панели: выключенный переключатель не меняет состояние и не вызывает действие',
                api.swState.state === false && !api.swState.pressed && api.swState.calls === 0, JSON.stringify(api));
            check('кнопки панели: список — начальное значение, смена вызывает действие с самим списком, getValue() — выбранное',
                api.initial === 'a' && api.calls.join() === 'select:b' && api.value === 'b', JSON.stringify(api));
            check('кнопки панели: без ошибок JS', !aErrors.list().length, aErrors.list().join(' | '));
            await ap.close();
        }

```

- [ ] **Step 2: `tests/audit/editors.js` — панель формы (шаг 15), переключатель режима правки (шаг 16)**

После шага 14 (перед `    await browser.close();`) вставить:

```js
    // 15. the form toolbar (Toolbar): the «after saving» select shows the value remembered in the cookie and getValue()
    //     returns it; pressing the mouse on a toolbar button does not take the focus from the field
    {
        await ctx.addCookies([{ name: 'after_add_default_action', value: 'editNext', url: BASE }]);
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'admin/mail-templates/single/mailTemplateEditor/1/edit/', { waitUntil: 'networkidle' });
        const sel = await p.evaluate(() => {
            const id = Object.keys(window.componentToolbars)[0];
            const control = window.componentToolbars[id].getControlById('after_save_action');
            return { shown: document.querySelector('li.select select').value, value: control && control.getValue() };
        });
        check('панель формы: список «после сохранения» показывает значение из cookie, getValue() его возвращает',
            sel.shown === 'editNext' && sel.value === 'editNext', JSON.stringify(sel));
        await showTabOf(p, '#template_name_1');
        await p.focus('#template_name_1');
        const btn = await p.locator('li.save_btn').boundingBox();
        await p.mouse.move(btn.x + btn.width / 2, btn.y + btn.height / 2);
        await p.mouse.down();
        const focus = await p.evaluate(() => document.activeElement && document.activeElement.id);
        // the button is released elsewhere: no click, nothing is saved
        await p.mouse.move(btn.x + btn.width / 2, btn.y + btn.height + 200);
        await p.mouse.up();
        check('панель формы: нажатие мыши на кнопку не уводит фокус из поля', focus === 'template_name_1', focus);
        check('панель формы: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
        await ctx.clearCookies({ name: 'after_add_default_action' });
    }

    // 16. the edit mode switcher of the page toolbar (Toolbar.Switcher, PageToolbar.editMode): pressed in edit mode,
    //     a second click leaves edit mode
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE, { waitUntil: 'networkidle' });
        const pressed = () => p.evaluate(() => document.querySelector('li.editMode_btn').classList.contains('pressed'));
        const before = await pressed();
        await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
        const inEdit = { pressed: await pressed(), jodit: await isJodit(p, '.nrgnEditor[num="1"]') };
        await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
        const after = { pressed: await pressed(), jodit: await isJodit(p, '.nrgnEditor[num="1"]') };
        check('переключатель «Режим правки»: в режиме правки нажат, повторный щелчок из него выходит',
            !before && inEdit.pressed && inEdit.jodit && !after.pressed && !after.jodit, JSON.stringify({ before, inEdit, after }));
        check('переключатель «Режим правки»: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    }

```

- [ ] **Step 3: `tests/no-traces.sh` — `VANILLA_JS`**

В список добавить строку:
```bash
            core/modules/share/scripts/Toolbar.js core/modules/share/scripts/PageToolbar.js
```
(перед закрывающей скобкой списка — после строки с `TabPane.js` и `PageList.js`, у которой скобка переносится на новую строку).

- [ ] **Step 4: Новые проверки — на нынешнем коде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step3-toolbars
bash -n tests/no-traces.sh && for t in grids editors; do node --check tests/audit/$t.js; done
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools > "$L/t1-no-traces.log" 2>&1; echo "no-traces $?"; head -4 "$L/t1-no-traces.log"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t1-regression.log" 2>&1; echo "regression $?"
cd tests/audit && for t in grids editors; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/t1-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t1-$t.log" | head -10; done; cd ../..
```
Expected: `no-traces` — выход 1 (конструкции MooTools в `Toolbar.js` и `PageToolbar.js`); регрессия — выход 0; `grids` — выход 1, единственный провал «MooTools у администратора на главной не запрашивается и не определена»; `editors` — выход 0.

- [ ] **Step 5: Commit**

```bash
git add tests/audit/grids.js tests/audit/editors.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 3: проверки — панель страницы, панели гридов и форм, кнопки, режим правки" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `Toolbar` и `PageToolbar` на чистом JavaScript

**Files:**
- Modify: `core/modules/share/scripts/Toolbar.js`, `core/modules/share/scripts/PageToolbar.js` (переписать целиком)

**Interfaces:**
- Consumes: `Energine.loadCSS` (шаг 2), `ModalBox` (шаг 2); проверки задачи 1.
- Produces: `new Toolbar(name, props)` — `name`, `element`, `properties`, `controls`, `boundTo`, `dock()`, `getElement()`, `bindTo(object)`, `appendControl(...controls)`, `getControlById(id)`, `disableControls(...ids)`, `enableControls(...ids)`, `callAction(action, data)`; `Toolbar.Control`, `Toolbar.Button`, `Toolbar.File`, `Toolbar.Switcher`, `Toolbar.Separator`, `Toolbar.Select` (раздел 3.1 спецификации); `new PageToolbar(componentPath, documentId, toolbarName, controlsDesc, props)` с действиями `editMode`, `add`, `edit`, `toggleSidebar`, `showTmplEditor`, `showTransEditor`, `showUserEditor`, `showRoleEditor`, `showLangEditor`, `showFileRepository`, `showSiteSettings`, `_reloadWindowInEditMode`.

- [ ] **Step 1: `Toolbar.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Toolbar]{@link Toolbar}</li>
 *     <li>[Toolbar.Control]{@link Toolbar.Control}</li>
 *     <li>[Toolbar.Button]{@link Toolbar.Button}</li>
 *     <li>[Toolbar.File]{@link Toolbar.File}</li>
 *     <li>[Toolbar.Switcher]{@link Toolbar.Switcher}</li>
 *     <li>[Toolbar.Separator]{@link Toolbar.Separator}</li>
 *     <li>[Toolbar.Select]{@link Toolbar.Select}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

/**
 * Панель кнопок: ul.toolbar с кнопками li. Действие кнопки — метод объекта, к которому панель привязана (bindTo).
 *
 * @constructor
 * @param {string} toolbarName Имя панели: класс ul и начало id кнопок со значками.
 * @param {Object} [props] Свойства панели (например, noSideFrame у панели страницы).
 */
var Toolbar = class Toolbar {
    constructor(toolbarName, props) {
        Energine.loadCSS('toolbar.css');
        this.name = toolbarName;
        this.boundTo = null;
        this.controls = [];
        this.element = document.createElement('ul');
        this.element.classList.add('toolbar', 'clearfix');
        if (this.name) {
            this.element.classList.add(this.name);
        }
        this.properties = (props && typeof props === 'object') ? props : {};
    }

    // панель прикреплена к верху окна (панель страницы)
    dock() {
        this.element.classList.add('docked_toolbar');
    }

    getElement() {
        return this.element;
    }

    bindTo(object) {
        this.boundTo = object;
    }

    /**
     * Добавить кнопки: готовые (Toolbar.Control) или описания {type, id, onclick, …} — по описанию создаётся
     * Toolbar[Тип], onclick становится действием. Остальное пропускается.
     */
    appendControl(...controls) {
        controls.forEach((control) => {
            if (control && control.type && control.id) {
                const type = control.type.charAt(0).toUpperCase() + control.type.slice(1);
                control.action = control.onclick;
                delete control.onclick;
                control = new Toolbar[type](control);
            }
            if (control instanceof Toolbar.Control) {
                control.toolbar = this;
                control.build();
                if (control.element) {
                    this.element.appendChild(control.element);
                }
                this.controls.push(control);
            }
        });
    }

    getControlById(id) {
        return this.controls.find((control) => control.properties.id == id) || null;
    }

    // без id — все кнопки, кроме «Закрыть»
    disableControls(...ids) {
        if (!ids.length) {
            this.controls.forEach((control) => {
                if (control.properties.id != 'close') {
                    control.disable();
                }
            });
            return;
        }
        ids.forEach((id) => {
            const control = this.getControlById(id);
            if (control) {
                control.disable();
            }
        });
    }

    // без id — все кнопки; выключенные в описании остаются выключенными (enable(true) включает и их)
    enableControls(...ids) {
        const controls = ids.length ? ids.map((id) => this.getControlById(id)).filter(Boolean) : this.controls;
        controls.forEach((control) => control.enable());
    }

    callAction(action, data) {
        if (this.boundTo && typeof this.boundTo[action] === 'function') {
            this.boundTo[action](data);
        }
    }
};

/**
 * Кнопка панели — основа: свойства id, icon, title, tooltip, action, disabled, class.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Control = class ToolbarControl {
    constructor(properties) {
        this.toolbar = null;
        this.element = null;
        this.properties = Object.assign({id: '', icon: '', title: '', tooltip: '', action: '', disabled: false}, properties);
        if (this.properties.disabled) {
            this.properties.isDisabled = !!this.properties.disabled;
            this.properties.isInitiallyDisabled = this.properties.isDisabled;
        }
    }

    // кнопка-значок: картинка фоном, подпись — в подсказке
    buildAsIcon(icon) {
        this.element.classList.add('icon', 'unselectable');
        this.element.id = this.toolbar.name + this.properties.id;
        this.element.title = this.properties.title + (this.properties.tooltip ? ' (' + this.properties.tooltip + ')' : '');
        this.element.style.userSelect = 'none';
        this.element.style.backgroundImage = 'url(' + Energine.base + icon + ')';
    }

    build() {
        if (!this.toolbar || !this.properties.id) {
            return;
        }
        this.element = document.createElement('li');
        this.element.setAttribute('unselectable', 'on');
        if (this.properties.icon) {
            this.buildAsIcon(this.properties.icon);
        } else {
            this.element.title = this.properties.tooltip;
            this.element.appendChild(document.createTextNode(this.properties.title));
        }
        if (this.properties.isDisabled) {
            this.disable();
        }
    }

    disable() {
        this.properties.isDisabled = true;
        this.element.classList.add('disabled');
        this.element.style.opacity = '0.25';
    }

    // выключенная в описании включается только с force
    enable(force) {
        if (force) {
            this.properties.isInitiallyDisabled = false;
        }
        if (!this.properties.isInitiallyDisabled) {
            this.properties.isDisabled = false;
            this.element.classList.remove('disabled');
            this.element.style.opacity = '1';
        }
    }

    disabled() {
        return this.properties.isDisabled;
    }
};

/**
 * Кнопка: класс <id>_btn, подсветка при наведении, щелчок — действие (с событием щелчка).
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Button = class ToolbarButton extends Toolbar.Control {
    build() {
        super.build();
        if (!this.element) {
            return;
        }
        this.element.classList.add(this.properties.id + '_btn');
        if (this.properties.class) {
            this.element.classList.add(...String(this.properties.class).split(/\s+/).filter(Boolean));
        }
        this.element.addEventListener('mouseover', () => {
            if (!this.properties.isDisabled) {
                this.element.classList.add('highlighted');
            }
        });
        this.element.addEventListener('mouseout', () => this.element.classList.remove('highlighted'));
        this.element.addEventListener('click', (event) => this.callAction(event));
        // нажатие мыши не уводит фокус из поля формы и не выделяет текст
        this.element.addEventListener('mousedown', (event) => {
            event.preventDefault();
            event.stopPropagation();
        });
    }

    // выключить по признаку (например, при выборе нескольких строк грида) …
    DisableAndSetProperty(property) {
        if (!this.properties.isDisabled) {
            this.properties[property] = true;
            this.properties.isDisabled = true;
            this.element.classList.add('disabled');
            this.element.style.opacity = '0.25';
        }
    }

    // … и включить, только если выключена по этому признаку
    EnableByProperty(property) {
        if (this.properties[property] === true) {
            this.properties[property] = false;
            this.properties.isDisabled = false;
            this.element.classList.remove('disabled');
            this.element.style.opacity = '1';
        }
    }

    callAction(data) {
        if (!this.properties.isDisabled) {
            this.toolbar.callAction(this.properties.action, data);
        }
    }
};

/**
 * Кнопка выбора файла: открывает выбор файла, действие получает прочитанный файл (FileReader).
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.File = class ToolbarFile extends Toolbar.Button {
    build() {
        super.build();
        if (!this.element) {
            return;
        }
        const input = document.createElement('input');
        input.type = 'file';
        input.id = this.properties.id;
        input.addEventListener('change', (event) => {
            const file = event.target.files[0];
            if (!file) {
                return;
            }
            const reader = new FileReader();
            reader.onload = (e) => {
                if (!this.properties.isDisabled) {
                    this.toolbar.callAction(this.properties.action, e.target);
                }
            };
            reader.readAsDataURL(file);
        });
        this.element.appendChild(input);
    }

    callAction() {
        this.element.querySelector('input[type=file]').click();
    }
};

/**
 * Кнопка-переключатель: state — нажата ли, aicon — значок нажатой. Действие срабатывает до смены состояния.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Switcher = class ToolbarSwitcher extends Toolbar.Button {
    constructor(properties) {
        super(properties);
        this.properties.state = this.properties.state ? !!parseInt(this.properties.state, 10) : false;
    }

    build() {
        super.build();
        if (!this.element) {
            return;
        }
        const toggle = () => {
            if (this.properties.state) {
                if (this.properties.aicon) {
                    this.buildAsIcon(this.properties.aicon);
                } else {
                    this.element.classList.add('pressed');
                }
            } else if (this.properties.icon) {
                this.buildAsIcon(this.properties.icon);
            } else {
                this.element.classList.remove('pressed');
            }
        };
        // обработчик действия кнопки добавлен раньше — состояние меняется после действия
        this.element.addEventListener('click', () => {
            if (!this.properties.isDisabled) {
                this.properties.state = !this.properties.state;
                toggle();
            }
        });
        toggle();
    }

    getState() {
        return this.properties.state;
    }
};

/**
 * Разделитель кнопок; не выключается.
 *
 * @constructor
 * @param {Object} [properties]
 */
Toolbar.Separator = class ToolbarSeparator extends Toolbar.Control {
    build() {
        super.build();
        if (this.element) {
            this.element.classList.add('separator');
        }
    }

    disable() {
    }
};

/**
 * Выпадающий список: подпись и select; смена — действие с самим списком.
 *
 * @constructor
 * @param {Object} properties Свойства (id, title, action; options и initialValue — вместо следующих параметров).
 * @param {Object} [options] Значения: {значение: текст}.
 * @param {string} [initialValue] Выбранное значение.
 */
Toolbar.Select = class ToolbarSelect extends Toolbar.Control {
    constructor(properties, options, initialValue) {
        super();
        properties = properties || {};
        this.properties = Object.assign({id: null, title: '', tooltip: '', action: null, disabled: false}, properties);
        this.options = options || properties.options || {};
        this.initial = initialValue || properties.initialValue || false;
        this.select = null;
    }

    build() {
        if (!this.toolbar || !this.properties.id) {
            return;
        }
        this.element = document.createElement('li');
        this.element.setAttribute('unselectable', 'on');
        this.element.classList.add('select');
        if (this.properties.title) {
            const label = document.createElement('span');
            label.className = 'label';
            label.textContent = this.properties.title;
            this.element.appendChild(label);
        }
        this.select = document.createElement('select');
        this.select.addEventListener('change', () => this.toolbar.callAction(this.properties.action, this));
        this.element.appendChild(this.select);
        if (this.properties.isDisabled) {
            this.disable();
        }
        Object.keys(this.options).forEach((key) => {
            const option = document.createElement('option');
            option.value = key;
            option.textContent = this.options[key];
            if (key == this.initial) {
                option.selected = true;
            }
            this.select.appendChild(option);
        });
    }

    disable() {
        if (!this.properties.isDisabled) {
            this.properties.isDisabled = true;
            this.select.disabled = true;
        }
    }

    enable() {
        if (this.properties.isDisabled) {
            this.properties.isDisabled = false;
            this.select.disabled = false;
        }
    }

    getValue() {
        const selected = [...this.select.selectedOptions];
        return selected.length ? selected[selected.length - 1].value : null;
    }

    setSelected(itemId) {
        if (this.options[itemId] && this.select) {
            const option = [...this.select.options].find((o) => o.value === String(itemId));
            if (option) {
                option.selected = true;
            }
        }
    }
};
```

- [ ] **Step 2: `PageToolbar.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageToolbar]{@link PageToolbar}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Toolbar
 * @requires ModalBox
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Toolbar', 'ModalBox');

/**
 * Панель страницы у администратора на сайте: прикреплена сверху, страница — в основной рамке, сбоку — панель разделов
 * (iframe). Действия кнопок — методы панели: режим правки и окна админки.
 *
 * @constructor
 * @param {string} componentPath Адрес компонента панели (…/single/adminPanel/).
 * @param {number} documentId id страницы.
 * @param {string} toolbarName
 * @param {Object[]} [controlsDesc] Описания кнопок {type, id, title, onclick, …}.
 * @param {Object} [props] Свойства панели (noSideFrame — без боковой панели).
 */
var PageToolbar = class PageToolbar extends Toolbar {
    constructor(componentPath, documentId, toolbarName, controlsDesc, props) {
        super(toolbarName, props);
        Energine.loadCSS('pagetoolbar.css');
        this.componentPath = componentPath;
        this.documentId = documentId;
        this.dock();
        this.bindTo(this);
        if (controlsDesc) {
            controlsDesc.forEach((control) => this.appendControl(control));
        }
        this.setupLayout();
    }

    // верхняя рамка с панелью и значком, основная рамка со страницей, боковая панель
    setupLayout() {
        const html = document.documentElement;
        html.classList.add('e-has-topframe1');

        // содержимое страницы, кроме затемнений, переходит в основную рамку
        const currentBody = [...document.body.children]
            .filter((element) => element.tagName.toLowerCase() === 'svg' || !element.classList.contains('e-overlay'));
        const mainFrame = document.createElement('div');
        mainFrame.className = 'e-mainframe';
        const topFrame = document.createElement('div');
        topFrame.className = 'e-topframe';
        document.body.append(topFrame, mainFrame);
        mainFrame.append(...currentBody);
        topFrame.appendChild(this.element);

        const gear = document.createElement('img');
        gear.src = Energine['static'] + (Energine.debug ? 'images/toolbar/nrgnptbdbg.png' : 'images/toolbar/nrgnptb.png');
        gear.className = 'pagetb_logo';
        topFrame.prepend(gear);

        if (!this.properties.noSideFrame) {
            if (PageToolbar.readCookie('sidebar') == 1) {
                html.classList.add('e-has-sideframe');
            }
            const sidebarFrame = document.createElement('div');
            sidebarFrame.className = 'e-sideframe';
            const sidebarFrameContent = document.createElement('div');
            sidebarFrameContent.className = 'e-sideframe-content';
            const sidebarFrameBorder = document.createElement('div');
            sidebarFrameBorder.className = 'e-sideframe-border';
            document.body.appendChild(sidebarFrame);
            sidebarFrame.append(sidebarFrameContent, sidebarFrameBorder);
            const iframe = document.createElement('iframe');
            iframe.src = this.componentPath + 'show/';
            iframe.frameBorder = '0';
            sidebarFrameContent.appendChild(iframe);
            gear.addEventListener('click', () => this.toggleSidebar());
        }
    }

    // Действия кнопок

    // режим правки: включить — страница приходит заново формой (editMode=1), выключить — перезагрузкой
    editMode() {
        const control = this.getControlById('editMode');
        if (control && control.getState() == 0) {
            this._reloadWindowInEditMode();
        } else {
            window.location = window.location;
        }
    }

    add() {
        ModalBox.open({url: this.componentPath + 'add/' + this.documentId});
    }

    edit() {
        ModalBox.open({url: this.componentPath + this.documentId + '/edit'});
    }

    // боковая панель: открыть или закрыть и запомнить это в cookie на 30 дней (домен — главного сайта, если адрес
    // сайта на нём)
    toggleSidebar() {
        const html = document.documentElement;
        html.classList.toggle('e-has-sideframe');
        const base = new URL(Energine.base, document.baseURI);
        const root = new URL(Energine.root || Energine.base, document.baseURI);
        const url = base.hostname.includes(root.hostname) ? root : base;
        PageToolbar.writeCookie('sidebar', html.classList.contains('e-has-sideframe') ? 1 : 0,
            '.' + url.hostname, url.pathname.replace(/[^/]*$/, ''), 30);
    }

    showTmplEditor() {
        ModalBox.open({url: this.componentPath + 'template'});
    }

    showTransEditor() {
        ModalBox.open({url: this.componentPath + 'translation'});
    }

    showUserEditor() {
        ModalBox.open({url: this.componentPath + 'user'});
    }

    showRoleEditor() {
        ModalBox.open({url: this.componentPath + 'role'});
    }

    showLangEditor() {
        ModalBox.open({url: this.componentPath + 'languages'});
    }

    showFileRepository() {
        ModalBox.open({url: this.componentPath + 'file-library'});
    }

    showSiteSettings() {
        ModalBox.open({url: this.componentPath + 'site-settings/'});
    }

    // вход в режим правки: та же страница формой POST editMode=1 с токеном
    _reloadWindowInEditMode() {
        const form = document.createElement('form');
        form.style.display = 'none';
        form.action = '';
        form.method = 'post';
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'editMode';
        input.value = '1';
        form.append(input, Energine.csrfInput());
        document.body.appendChild(form);
        form.submit();
    }

    static readCookie(name) {
        const pair = document.cookie.split(/;\s*/).find((item) => item.startsWith(name + '='));
        return pair ? decodeURIComponent(pair.slice(name.length + 1)) : null;
    }

    static writeCookie(name, value, domain, path, days) {
        const expires = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toUTCString();
        document.cookie = name + '=' + encodeURIComponent(value) + '; domain=' + domain + '; path=' + path
            + '; expires=' + expires;
    }
};
```

- [ ] **Step 3: Пересобрать стенд и проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step3-toolbars
for f in Toolbar PageToolbar; do node --check core/modules/share/scripts/$f.js || echo "BAD $f"; done
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools; echo "no-traces $?"
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
php8.5 -r '$m = include "/tmp/stand-web97/site/web/system.jsmap.php"; echo json_encode(["Toolbar" => $m["Toolbar"] ?? null, "PageToolbar" => $m["PageToolbar"] ?? null]), "\n";'
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t2-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t2-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in grids editors crawl theme public; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t2-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t2-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t2-$t.log" | head -10; done; cd ../..
```
Expected: синтаксис без ошибок; `no-traces code mootools` — выход 0; карта: `Toolbar` → `null`, `PageToolbar` → `["Toolbar","ModalBox"]`; регрессия — выход 0; `grids`, `editors`, `crawl`, `theme`, `public` — выход 0.

- [ ] **Step 4: Commit**

```bash
git add core/modules/share/scripts/Toolbar.js core/modules/share/scripts/PageToolbar.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 3: панели админки и панель страницы на чистом JavaScript" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Документы и итоговая проверка

**Files:**
- Modify: `README.md` (абзац об этапе 8, список спецификаций), `tests/README.md` (разделы «Гриды админки», «Редакторы и загрузка»)

- [ ] **Step 1: `README.md`** — после предложения о шаге 2 дописать: «Шаг 3 (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step3-toolbars-design.md`): панели кнопок админки и панель страницы — на чистом JavaScript; администратор на страницах сайта вне режима правки MooTools не получает.» и в список спецификаций — строку `` `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step3-toolbars-design.md` (этап 8, шаг 3) ``.
- [ ] **Step 2: `tests/README.md`** — в «Гриды админки» перед «Записи теста удаляются.» дописать: «Панель страницы у администратора на главной: рамки, значок, боковая панель и её cookie, MooTools не загружается. Панель грида: выключенная кнопка ничего не делает, включённая открывает окно. Кнопки панели: выключенная в описании, выключенный переключатель, выпадающий список.» В «Редакторы и загрузка» — пункты «панель формы: список «после сохранения» из cookie, нажатие мыши на кнопку не уводит фокус» и «переключатель «Режим правки»: нажат в режиме правки, повторный щелчок из него выходит».
- [ ] **Step 3: Итоговая проверка на чистом стенде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step3-toolbars
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
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 3: документы" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Выкладка на simple.energine.org

Требует отдельного «да» владельца. База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step3-<дата>/`.
- [ ] **Step 2: Код** — от имени web97: `git -C <живое дерево> fetch <клон> main && git -C <живое дерево> merge --ff-only FETCH_HEAD`.
- [ ] **Step 3: Статика** — в `web/` от web97: `php8.5 index.php setup linker && php8.5 index.php setup scriptMap`; карта: `PageToolbar` → `Toolbar`, `ModalBox`; у `Toolbar` зависимостей нет.
- [ ] **Step 4: Проверка** — гостем: публичные страницы без MooTools и ошибок JS; регрессию и аудиты на площадке — по слову владельца; после прогонов от root — `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 5: Откат при провале** — от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`.
