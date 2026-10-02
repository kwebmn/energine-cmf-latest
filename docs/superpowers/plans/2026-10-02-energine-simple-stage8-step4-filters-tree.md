# Energine Simple, этап 8, шаг 4 — фильтры гридов и дерево разделов без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** фильтры гридов (`Filters`) и дерево разделов (`TreeView`) работают на чистом JavaScript с прежним интерфейсом; фильтр со «+», «&», «%» в значении находит нужное; удалённый узел дерева уходит из его списка.

**Architecture:** `Filters.js` и `TreeView.js` переписываются классами JavaScript без объявления `MooCompat`; события между внутренними классами фильтров — обратные вызовы; у узла дерева — свой небольшой механизм событий (`addEvent('select', …)`, его используют `DivManager` и `getDirsTree`). Скрипты на MooTools пользуются ими как прежде.

**Tech Stack:** JavaScript (классические скрипты, классы), PHP 8.5 (помощник теста), Playwright (аудиты), bash.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step4-filters-tree-design.md`

## Global Constraints

- Только современные браузеры; без сборки, npm и ES-модулей; классы — `var Имя = class Имя …`, вложенные — `Filter.Clause = class FilterClause …`, `TreeView.Node = class TreeViewNode …`.
- Интерфейс для скриптов на MooTools — прежний (спецификация, раздел 2); разметка и классы прежние.
- В файлах из `VANILLA_JS` нет конструкций MooTools — и в комментариях тоже (в том числе `.fireEvent(` и `.addEvent(`: метод событий узла дерева для своих вызовов называется `emit`).
- Зависимости скрипта — первый вызов `ScriptLoader.load('…')` в файле; у этих двух файлов зависимостей нет.
- Комментарии — по-русски; строки `@author` в шапках остаются.
- Проверки — на стенде; выкладка и проверка на площадке — задача 5, без отдельного согласования (владелец: «продолжай без остановки»); при провале на площадке — откат к точке отката.
- Коммиты — `bash tests/tools/stand.sh run git commit …`; последняя строка сообщения — `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Пароли и учётные данные не попадают в файлы, журналы и отчёты.

## Review Focus

- **Значение фильтра с «+» и «&».** Ожидание: находит своё (строка запроса кодируется). Тест — `grids.js`, «фильтр грида» (задача 1, красная до задачи 2).
- **Добавление и удаление фильтров.** Ожидание: у первого фильтра нет «и/или» и «−» выключена; у второго «и/или» есть, «−» включается у обоих; после удаления второго — как в начале. Тест — `grids.js`, «фильтр грида» (задача 1).
- **Панель фильтров в окне грида** закрыта по умолчанию. Ожидание: ссылка открывает её, второй щелчок закрывает. Тест — `grids.js`, «фильтр грида» (задача 1).
- **Перестановка и удаление узлов дерева.** Ожидание: «вверх»/«вниз» меняют порядок, удалённый узел не находится по id. Тест — `grids.js`, «узлы дерева» (задача 1, удаление — красное до задачи 3).
- **Щелчок по значку папки и по названию.** Ожидание: значок раскрывает и сворачивает папку, название выбирает раздел и включает кнопки. Тест — `grids.js`, «дерево» (задача 1).

---

### Task 1: Проверки — фильтр грида, дерево структуры, узлы дерева, категория `mootools`

**Files:**
- Modify: `tests/audit/grids-db.php` (`add` — пользователь с «+»), `tests/audit/grids.js` (блоки после «журнал действий: фильтр по дате»; в проверке имени узла — `querySelector`), `tests/no-traces.sh` (`VANILLA_JS`)

**Interfaces:**
- Consumes: помощники `grids.js` (`ctx`, `watch`, `check`, `BASE`), `grids-db.php add/remove` (метка `claude-grid-%`).
- Produces: проверки, по которым задачи 2–3 видят красное и зелёное; `VANILLA_JS` с `Filters.js` и `TreeView.js`.

- [ ] **Step 1: `tests/audit/grids-db.php`** — в `case 'add':` перед выводом JSON добавить пользователя (его удаляет `remove` по метке `claude-grid-%`):

```php
        // пользователь с «+» в логине — для фильтра грида: значение фильтра должно дойти до сервера как есть
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            ['claude-grid-a+b@example.org', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), 'Claude Grid Plus']);
```

- [ ] **Step 2: `tests/audit/grids.js`** — в проверке «дерево страниц: имя с разметкой» заменить `const a = node.element.getElement('a');` на `const a = node.element.querySelector('a');`. После блока «журнал действий: фильтр по дате» (перед `// панель страницы (PageToolbar)…`) вставить:

```js
        // фильтр грида (Filters) в окне грида пользователей: панель закрыта и открывается ссылкой, второй щелчок её
        // закрывает; «+» добавляет фильтр с «и/или», «−» его убирает; значение с «+» доходит до сервера как есть;
        // «Сбросить» возвращает все строки
        {
            const fp = await ctx.newPage();
            const fErrors = watch(fp);
            const bodies = [];
            fp.on('request', (r) => { if (r.url().includes('/get-data/')) bodies.push(r.postData() || ''); });
            await fp.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            const panel = () => fp.evaluate(() => {
                const inner = document.querySelector('.filters_block_inner');
                return { toggled: inner.classList.contains('toggled'), height: Math.round(inner.getBoundingClientRect().height) };
            });
            const closed = await panel();
            await fp.click('.filter_toggle');
            await fp.waitForTimeout(900);
            const opened = await panel();
            check('фильтр грида: в окне грида панель закрыта и открывается ссылкой',
                closed.toggled && closed.height === 0 && !opened.toggled && opened.height > 0, JSON.stringify({ closed, opened }));
            const filters = () => fp.evaluate(() => [...document.querySelectorAll('.filters .filter')].map((f) => ({
                operand: f.querySelector('.filters_operand').offsetParent !== null,
                removable: !f.querySelector('.remove_filter').disabled,
            })));
            await fp.click('button.add_filter');
            const two = await filters();
            await fp.evaluate(() => [...document.querySelectorAll('.filters .filter')].pop().querySelector('.remove_filter').click());
            const one = await filters();
            check('фильтр грида: «+» добавляет фильтр с «и/или», у обоих включается «−», «−» убирает второй',
                two.length === 2 && !two[0].operand && two[1].operand && two.every((f) => f.removable)
                && one.length === 1 && !one[0].operand && !one[0].removable, JSON.stringify({ two, one }));
            const rows = () => fp.evaluate(() => [...document.querySelectorAll('tbody tr')].filter((tr) => tr.querySelector('td'))
                .map((tr) => tr.textContent));
            const all = (await rows()).length;
            await fp.fill('.filters .filter .f_query_container input.query', 'grid-a+b');
            await Promise.all([fp.waitForResponse((r) => r.url().includes('/get-data/')), fp.click('button.f_apply')]);
            await fp.waitForTimeout(500);
            const found = await rows();
            check('фильтр грида: значение с «+» доходит до сервера как есть — найден свой пользователь',
                found.length === 1 && found[0].includes('claude-grid-a+b@example.org'),
                JSON.stringify({ found, body: bodies[bodies.length - 1] }));
            await Promise.all([fp.waitForResponse((r) => r.url().includes('/get-data/')), fp.click('a.f_reset')]);
            await fp.waitForTimeout(500);
            const back = (await rows()).length;
            check('фильтр грида: «Сбросить» возвращает все строки', back === all && all > 1, JSON.stringify({ all, back }));
            await fp.click('.filter_toggle');
            await fp.waitForTimeout(900);
            const again = await panel();
            check('фильтр грида: второй щелчок по ссылке закрывает панель', again.toggled && again.height === 0, JSON.stringify(again));
            check('фильтр грида: без ошибок JS и 404', !fErrors.list().length, fErrors.list().join(' | '));
            await fp.close();
        }

        // дерево разделов (TreeView) в структуре: щелчок по названию выбирает раздел и включает «Редактировать»,
        // щелчок по значку слева от свёрнутой папки раскрывает её, второй — сворачивает
        {
            const dp = await ctx.newPage();
            const dErrors = watch(dp);
            await dp.goto(BASE + 'admin/structure/', { waitUntil: 'networkidle' });
            await dp.waitForSelector('#divTree li a', { timeout: 10000 }).catch(() => null);
            const target = await dp.evaluate(() => {
                const li = [...document.querySelectorAll('#divTree li.folder')]
                    .find((el) => !el.classList.contains('opened') && !el.classList.contains('selected'));
                if (!li) return null;
                li.setAttribute('data-test-node', '1');
                const r = li.getBoundingClientRect();
                return { x: r.left + 4, y: r.top + 8 };
            });
            const nodeState = () => dp.evaluate(() => {
                const li = document.querySelector('[data-test-node]');
                const edit = document.querySelector('ul.toolbar li.edit_btn');
                return { selected: li.classList.contains('selected'), opened: li.classList.contains('opened'),
                    hidden: li.querySelector(':scope > ul').classList.contains('hidden'),
                    selectedCount: document.querySelectorAll('#divTree li.selected').length,
                    edit: !!edit && !edit.classList.contains('disabled') };
            });
            let s1 = null, s2 = null, s3 = null;
            if (target) {
                await dp.click('[data-test-node] > a');
                s1 = await nodeState();
                await dp.mouse.click(target.x, target.y);
                s2 = await nodeState();
                await dp.mouse.click(target.x, target.y);
                s3 = await nodeState();
            }
            check('дерево: щелчок по названию выбирает раздел (выбран один) и включает «Редактировать»',
                !!s1 && s1.selected && s1.selectedCount === 1 && s1.edit && s1.hidden, JSON.stringify(s1));
            check('дерево: щелчок по значку слева от папки раскрывает её, второй — сворачивает',
                !!s2 && s2.opened && !s2.hidden && !!s3 && !s3.opened && s3.hidden, JSON.stringify({ s2, s3 }));
            check('дерево: без ошибок JS и 404', !dErrors.list().length, dErrors.list().join(' | '));
            await dp.close();
        }

        // узлы дерева (TreeView.Node) на своём дереве: классы folder и last; «вверх» и «вниз»; путь к узлу раскрывается;
        // удалённый узел уходит из списка дерева (не находится по id), остальные находятся
        {
            const np = await ctx.newPage();
            const nErrors = watch(np);
            await np.goto(BASE + 'admin/structure/', { waitUntil: 'networkidle' });
            const r = await np.evaluate(() => {
                const ul = document.createElement('ul');
                document.body.appendChild(ul);
                const tree = new TreeView(ul, {});
                const make = (id) => new TreeView.Node({ id, name: 'N' + id, data: { segment: 'n' + id, icon: '' } }, tree);
                const [root, a, b, c, d] = [0, 1, 2, 3, 4].map(make);
                tree.adopt(root);
                root.adopt(a);
                root.adopt(b);
                root.adopt(c);
                c.adopt(d);
                tree.setupCssClasses();
                const names = () => [...root.childs.children].map((li) => li.querySelector('a').textContent).join(',');
                const result = { order0: names(), cFolder: c.element.classList.contains('folder'),
                    cLast: c.element.classList.contains('last'), aLast: a.element.classList.contains('last') };
                c.moveUp();
                result.order1 = names();
                a.moveDown();
                result.order2 = names();
                tree.expandToNode(4);
                result.opened = root.opened && c.opened && !c.childs.classList.contains('hidden');
                result.parents = d.getParent() === c && d.getParents().length === 2;
                b.remove();
                result.order3 = names();
                result.removedFound = !!tree.getNodeById(2);
                result.othersFound = [0, 1, 3, 4].every((id) => !!tree.getNodeById(id));
                ul.remove();
                return result;
            });
            check('узлы дерева: классы folder и last, «вверх» и «вниз»', r.order0 === 'N1,N2,N3' && r.cFolder && r.cLast && !r.aLast
                && r.order1 === 'N1,N3,N2' && r.order2 === 'N3,N1,N2', JSON.stringify(r));
            check('узлы дерева: путь к узлу раскрывается, родители узла', r.opened && r.parents, JSON.stringify(r));
            check('узлы дерева: удалённый узел уходит из списка дерева, остальные находятся',
                r.order3 === 'N3,N1' && !r.removedFound && r.othersFound, JSON.stringify(r));
            check('узлы дерева: без ошибок JS', !nErrors.list().length, nErrors.list().join(' | '));
            await np.close();
        }

```

- [ ] **Step 3: `tests/no-traces.sh` — `VANILLA_JS`** — строку `core/modules/share/scripts/Toolbar.js core/modules/share/scripts/PageToolbar.js)` заменить на `core/modules/share/scripts/Toolbar.js core/modules/share/scripts/PageToolbar.js` и добавить строку `            core/modules/share/scripts/Filters.js core/modules/share/scripts/TreeView.js)`.

- [ ] **Step 4: Новые проверки — на нынешнем коде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step4-filters-tree
bash -n tests/no-traces.sh && node --check tests/audit/grids.js && php8.5 -l tests/audit/grids-db.php
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools > "$L/t1-no-traces.log" 2>&1; echo "no-traces $?"; head -4 "$L/t1-no-traces.log"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t1-regression.log" 2>&1; echo "regression $?"
cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js' > "$L/t1-grids.log" 2>&1; echo "grids exit $?"; grep -E '^FAIL' "$L/t1-grids.log" | head -10; cd ../..
```
Expected: `no-traces` — выход 1 (конструкции MooTools в `Filters.js` и `TreeView.js`); регрессия — выход 0; `grids` — выход 1, ровно два провала: «значение с «+» доходит до сервера как есть» (сервер читает «+» как пробел) и «удалённый узел уходит из списка дерева» (прежний `remove()` убирает последний узел списка).

- [ ] **Step 5: Commit**

```bash
git add tests/audit/grids-db.php tests/audit/grids.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 4: проверки — фильтр грида, дерево структуры, узлы дерева" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `Filters` на чистом JavaScript

**Files:**
- Modify: `core/modules/share/scripts/Filters.js` (переписать целиком)

**Interfaces:**
- Consumes: проверки `grids.js` (фильтр грида, фильтр журнала по дате).
- Produces: `new Filters(gridManager)` — `element`, `filters`, `active`, `getValue(): string`, `remove(filter)`, `reset(): boolean`, `use(): boolean`, `isEmpty(): boolean`.

- [ ] **Step 1: `Filters.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Filters]{@link Filters}</li>
 *     <li>[Filter]{@link Filter}</li>
 *     <li>[Filter.QueryControls]{@link Filter.QueryControls}</li>
 *     <li>[Filter.Clause]{@link Filter.Clause}</li>
 *     <li>[Filter.ClauseSet]{@link Filter.ClauseSet}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 */

/**
 * Образец фильтра: разметка первого фильтра (.filter) копируется для каждого нового.
 *
 * @constructor
 * @param {Element} templateEl
 */
var FiltersFabric = class FiltersFabric {
    constructor(templateEl) {
        this.parentContainer = templateEl.parentElement.closest('.filters');
        this.template = templateEl.cloneNode(true);
        templateEl.remove();
    }

    create() {
        const element = this.template.cloneNode(true);
        this.parentContainer.appendChild(element);
        return new Filter(element);
    }
};

/**
 * Панель фильтров грида: один или несколько фильтров «поле — условие — значение», объединённых «и/или».
 *
 * @constructor
 * @param {GridManager} gridManager
 */
var Filters = class Filters {
    constructor(gridManager) {
        this.filters = [];
        this.active = false;
        this.fabric = null;
        this.gridManager = gridManager;
        this.element = gridManager.element.querySelector('.filters_block');
        if (!this.element) {
            return;
        }
        this.fabric = new FiltersFabric(this.element.querySelector('.filter'));
        this.add();
        const inner = this.element.querySelector('.filters_block_inner');
        // ссылка открывает и закрывает панель фильтров
        this.element.querySelector('.filter_toggle').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            if (inner.classList.contains('toggled')) {
                inner.style.height = '';
                inner.classList.remove('toggled');
            } else {
                inner.style.height = '0px';
                inner.classList.add('toggled');
            }
        });
        this.element.querySelector('.add_filter').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            this.add();
            Filters.resized();
        });
        this.element.querySelector('.f_apply').addEventListener('click', () => {
            if (this.use()) {
                this.gridManager.reload();
            }
        });
        this.element.querySelector('.f_reset').addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            if (this.reset()) {
                this.gridManager.reload();
            }
        });
    }

    // размер панели изменился: гриды подгоняют свой (они слушают resize окна)
    static resized() {
        window.dispatchEvent(new Event('resize'));
    }

    add() {
        const filter = this.fabric.create();
        filter.onApply = () => {
            if (this.use()) {
                this.gridManager.reload();
            }
        };
        filter.onDelete = (f) => this.remove(f);
        this.filters.push(filter);
        if (this.filters.length == 1) {
            filter.element.querySelector('.operand_container').style.display = 'none';
            filter.element.querySelector('.remove_filter').disabled = true;
        } else {
            const operand = filter.element.querySelector('.filters_operand');
            if (getComputedStyle(operand).display === 'none') {
                operand.style.display = 'block';
            }
            this.element.querySelectorAll('.remove_filter').forEach((button) => {
                button.disabled = false;
            });
        }
    }

    remove(filter) {
        if (!filter) {
            return;
        }
        Filters.resized();
        filter.onDelete = null;
        const index = this.filters.indexOf(filter);
        if (index !== -1) {
            this.filters.splice(index, 1);
        }
        filter.reset();
        if (this.filters.length == 1) {
            this.filters[0].element.querySelector('.operand_container').style.display = 'none';
            this.filters[0].element.querySelector('.remove_filter').disabled = true;
        }
    }

    // все фильтры убираются, остаётся один пустой; false — сбрасывать нечего
    reset() {
        if (!this.active && this.filters.length <= 1) {
            return false;
        }
        while (this.filters.length) {
            this.filters[0].reset();
        }
        this.element.classList.remove('active');
        this.add();
        this.active = false;
        return true;
    }

    use() {
        if (!this.isEmpty()) {
            this.element.classList.add('active');
            this.active = true;
        } else {
            this.reset();
        }
        return this.active;
    }

    // строка запроса для грида; JSON кодируется — «+», «&» и «%» в значении доходят до сервера как есть
    getValue() {
        if (!this.active || this.isEmpty()) {
            return '';
        }
        const set = new Filter.ClauseSet();
        this.filters.forEach((filter) => set.add(filter.getValue()));
        return 'filter=' + encodeURIComponent(JSON.stringify(set)) + '&';
    }

    // пуст ли хоть один фильтр
    isEmpty() {
        return this.filters.some((filter) => filter.isEmpty());
    }
};

/**
 * Фильтр: поле, условие, значение (одно, период или дата); «−» убирает фильтр.
 *
 * @constructor
 * @param {Element} element
 */
var Filter = class Filter {
    constructor(element) {
        this.element = element;
        // обратные вызовы панели фильтров
        this.onApply = null;
        this.onDelete = null;
        this.inputs = new Filter.QueryControls(element.querySelectorAll('.f_query_container'), () => {
            if (this.onApply) {
                this.onApply();
            }
        });
        this.removeBtn = element.querySelector('.remove_filter');
        this.removeBtn.addEventListener('click', () => this.reset());
        this.condition = element.querySelector('.f_condition');
        // у условия — типы полей, для которых оно есть (data-types); без них условие есть для всех
        this.conditionOptions = [...this.condition.children];
        this.conditionTypes = new Map();
        this.conditionOptions.forEach((option) => {
            const types = option.getAttribute('data-types');
            if (types) {
                this.conditionTypes.set(option, types.split('|'));
                option.removeAttribute('data-types');
            }
        });
        this.fields = element.querySelector('.f_fields');
        this.fields.addEventListener('change', () => this.checkCondition());
        this.condition.addEventListener('change', (event) => this.switchInputs(event.target.value, this.fieldType()));
        this.checkCondition();
        this.operator = element.querySelector('.filters_operand');
    }

    fieldType() {
        const option = this.fields.options[this.fields.selectedIndex];
        return option ? option.getAttribute('type') : null;
    }

    // условия — для типа выбранного поля; поля значения — для условия; для дат — поля даты
    checkCondition() {
        const fieldType = this.fieldType();
        const isDate = (fieldType == 'datetime' || fieldType == 'date');
        this.conditionOptions.forEach((option) => {
            const types = this.conditionTypes.get(option);
            if (types) {
                if (types.includes(fieldType)) {
                    this.condition.appendChild(option);
                } else {
                    option.remove();
                }
            }
        });
        this.condition.selectedIndex = 0;
        this.switchInputs(this.condition.value, fieldType);
        this.disableInputField(isDate);
        this.inputs.showDateInputs(isDate);
        const first = this.inputs.inputs[0];
        if (getComputedStyle(first).display !== 'none') {
            first.focus();
        }
    }

    // логическое поле — без значения; «между» — два поля; иначе одно
    switchInputs(condition, type) {
        if (type == 'boolean') {
            this.inputs.hide();
        } else if (condition == 'between') {
            this.inputs.asPeriod();
        } else {
            this.inputs.asScalar();
        }
    }

    // для дат текстовые поля выключены и пусты (значение — в полях даты)
    disableInputField(disable) {
        if (disable) {
            this.inputs.inputs.forEach((input) => {
                input.disabled = true;
                input.value = '';
            });
        } else if (this.inputs.inputs[0].disabled) {
            this.inputs.inputs.forEach((input) => {
                input.disabled = false;
            });
        }
    }

    isEmpty() {
        return !(this.fieldType() == 'boolean' || this.inputs.hasValues());
    }

    // фильтр уходит со страницы и из панели
    reset() {
        this.element.remove();
        if (this.onDelete) {
            this.onDelete(this);
        }
    }

    getValue() {
        const field = this.fields.options[this.fields.selectedIndex];
        return this.inputs.getValues(new Filter.Clause(
            field.value,
            this.condition.options[this.condition.selectedIndex].value,
            field.getAttribute('type'),
            this.operator.offsetParent ? this.operator.options[this.operator.selectedIndex].value : null
        ));
    }
};

/**
 * Поля значения фильтра: по контейнеру на значение (второй — для периода), в каждом — текстовое поле и поле даты.
 *
 * @constructor
 * @param {NodeList} containers .f_query_container
 * @param {function} onApply Enter в непустом поле.
 */
Filter.QueryControls = class FilterQueryControls {
    constructor(containers, onApply) {
        this.containers = [...containers];
        this.isDate = false;
        this.containers[0].classList.remove('hidden');
        this.inputs = this.containers.map((container) => container.querySelector('input'));
        this.dpsInputs = this.inputs.map((input, n) => {
            const date = input.cloneNode(true);
            date.type = 'date';
            date.classList.add('hidden');
            this.containers[n].appendChild(date);
            return date;
        });
        this.all().forEach((input) => input.addEventListener('keydown', (event) => {
            if (event.key === 'Enter' && event.target.value !== '') {
                onApply();
            }
        }));
    }

    all() {
        return [...this.dpsInputs, ...this.inputs];
    }

    hasValues() {
        return (this.isDate ? this.dpsInputs : this.inputs).some((input) => input.value);
    }

    getValues(clause) {
        (this.isDate ? this.dpsInputs : this.inputs).forEach((input) => clause.setValue(String(input.value)));
        return clause;
    }

    asPeriod() {
        this.show();
        this.all().forEach((input) => input.classList.add('small'));
    }

    asScalar() {
        this.show();
        this.containers[1].classList.add('hidden');
        this.all().forEach((input) => input.classList.remove('small'));
    }

    show() {
        this.containers.forEach((container) => container.classList.remove('hidden'));
    }

    hide() {
        this.containers.forEach((container) => container.classList.add('hidden'));
    }

    showDateInputs(toShow) {
        this.isDate = toShow;
        this.inputs.forEach((input) => input.classList.toggle('hidden', toShow));
        this.dpsInputs.forEach((input) => input.classList.toggle('hidden', !toShow));
    }
};

/**
 * Условие фильтра для сервера: поле, условие, тип поля, «и/или» с предыдущим, значение (у периода — два).
 *
 * @constructor
 */
Filter.Clause = class FilterClause {
    constructor(fieldName, condition, type, operator) {
        this.field = fieldName;
        this.condition = condition;
        this.type = type;
        this.operator = (typeof operator !== 'undefined') ? operator : '';
    }

    setValue(value) {
        if (value) {
            if (this.type == 'phone') {
                value = value.replace(/\D/g, '');
            }
            if (this.value) {
                this.value = [this.value, value];
            } else {
                this.value = value;
            }
        }
        return this;
    }
};

/**
 * Набор условий фильтра (JSON для сервера: {"children": [...]}).
 *
 * @constructor
 */
Filter.ClauseSet = class FilterClauseSet {
    constructor(...clauses) {
        this.children = [];
        clauses.forEach((clause) => this.add(clause));
    }

    add(clause) {
        this.children.push(clause);
    }
};
```

- [ ] **Step 2: Пересобрать стенд и проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step4-filters-tree
node --check core/modules/share/scripts/Filters.js
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js' > "$L/t2-grids.log" 2>&1; echo "grids exit $?"; grep -E '^FAIL' "$L/t2-grids.log" | head -10; cd ../..
```
Expected: синтаксис без ошибок; `grids` — выход 1, единственный провал «удалённый узел уходит из списка дерева» (его закрывает задача 3); фильтр со «+», фильтр журнала по дате — OK.

- [ ] **Step 3: Commit**

```bash
git add core/modules/share/scripts/Filters.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 4: фильтры гридов на чистом JavaScript, значение фильтра кодируется" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: `TreeView` на чистом JavaScript

**Files:**
- Modify: `core/modules/share/scripts/TreeView.js` (переписать целиком)

**Interfaces:**
- Consumes: проверки `grids.js` (дерево, узлы дерева, боковая панель, выбор родителя, имя с разметкой).
- Produces: `new TreeView(element, {dblClick})` — `element`, `options`, `nodes`, `selectedNode`, `adopt`, `empty`, `setupCssClasses`, `getSelectedNode`, `getNodeById`, `expandToNode`, `expandAllNodes`, `nodeToggleListener(event, node)`, `nodeSelectListener(event, node)`; `new TreeView.Node(info|li, tree)` — `element`, `id`, `data`, `childs`, `opened`, `selected`, `addEvent(type, handler)`, `adopt`, `injectBefore`, `injectInside`, `removeChilds`, `getPrevious`, `getNext`, `getParent`, `getParents`, `isParentOf`, `swap`, `moveUp`, `moveDown`, `remove`, `toggle`, `expand`, `collapse`, `select`, `unselect`, `getId`, `setName`, `setData`, `setIcon`, `getData`.

- [ ] **Step 1: `TreeView.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[TreeView]{@link TreeView}</li>
 *     <li>[TreeView.Node]{@link TreeView.Node}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Дерево разделов: ul с узлами li > a; у папки — вложенный ul. Двойной щелчок по названию — options.dblClick.
 *
 * @constructor
 * @param {Element|string} element
 * @param {Object} [options]
 * @param {function} [options.dblClick] Двойной щелчок по названию узла.
 */
var TreeView = class TreeView {
    constructor(element, options) {
        Energine.loadCSS('treeview.css');
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        this.options = Object.assign({}, options);
        this.selectedNode = null;
        this.nodes = [];
    }

    // узел верхнего уровня
    adopt(node) {
        this.nodes.push(node);
        this.element.appendChild(node.element);
    }

    empty() {
        this.nodes.length = 0;
        this.element.replaceChildren();
    }

    // folder — у узла есть вложенные, last — последний среди соседей
    setupCssClasses() {
        this.element.querySelectorAll('li').forEach((item) => {
            const node = item.treeNode;
            item.classList.toggle('folder', !!(node && node.childs && node.childs.childNodes.length));
            item.classList.toggle('last', !item.nextElementSibling);
        });
    }

    getSelectedNode() {
        return this.selectedNode;
    }

    getNodeById(id) {
        return this.nodes.find((node) => node.id == id) || null;
    }

    // раскрыть все папки на пути к узлу (узел или его id)
    expandToNode(nodeId) {
        const parents = [];
        let node = (nodeId instanceof TreeView.Node) ? nodeId : this.getNodeById(nodeId);
        while (node && (node = node.getParent())) {
            parents.push(node);
        }
        parents.reverse().forEach((parent) => parent.expand());
    }

    expandAllNodes() {
        this.nodes.forEach((node) => node.expand());
    }

    // щелчок по строке узла: значок слева от папки (8×8 у верха строки) раскрывает и сворачивает её
    nodeToggleListener(event, node) {
        event.preventDefault();
        event.stopPropagation();
        if (event.target !== node.element) {
            return;
        }
        const rect = node.element.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        if (x < 0 || x > 8 || y < 4 || y > 12) {
            return;
        }
        node.toggle();
    }

    // щелчок по названию: узел выбирается (по ссылке не переходим — это делает двойной щелчок владельца дерева)
    nodeSelectListener(event, node) {
        event.preventDefault();
        event.stopPropagation();
        node.select();
    }
};

/**
 * Узел дерева: li > a (название — ссылка на страницу) и, у папки, ul с вложенными узлами. События узла —
 * addEvent('select', обработчик): обработчик получает узел.
 *
 * @constructor
 * @param {Object|Element} nodeInfo Описание {id, name, data: {segment, icon, class}} или готовый li.
 * @param {TreeView} tree
 */
TreeView.Node = class TreeViewNode {
    constructor(nodeInfo, tree) {
        this.tree = tree;
        this.events = {};
        this.selected = false;
        this.id = null;
        this.data = null;
        if (nodeInfo && nodeInfo.nodeType === 1) {
            this.element = nodeInfo;
            this.element.querySelector('a').setAttribute('href', Energine.base + Energine.lang + '/');
            this.id = this.element.getAttribute('id');
        } else {
            this.element = document.createElement('li');
            const link = document.createElement('a');
            link.setAttribute('href', Energine.base + Energine.lang + '/' + nodeInfo.data.segment);
            link.textContent = nodeInfo.name;
            this.element.appendChild(link);
            this.id = nodeInfo.id;
            this.data = nodeInfo.data;
            this.setIcon(nodeInfo.data.icon);
        }
        this.element.treeNode = this;
        const anchor = this.element.querySelector('a');
        if (nodeInfo.data && nodeInfo.data['class']) {
            anchor.classList.add(...String(nodeInfo.data['class']).split(/\s+/).filter(Boolean));
        }
        this.childs = this.element.querySelector('ul');
        this.opened = this.element.classList.contains('opened');
        this.element.addEventListener('click', (event) => this.tree.nodeToggleListener(event, this));
        if (typeof this.tree.options.dblClick === 'function') {
            anchor.addEventListener('dblclick', this.tree.options.dblClick);
        }
        anchor.addEventListener('click', (event) => this.tree.nodeSelectListener(event, this));
    }

    addEvent(type, handler) {
        (this.events[type] = this.events[type] || []).push(handler);
        return this;
    }

    emit(type) {
        (this.events[type] || []).forEach((handler) => handler.call(this, this));
        return this;
    }

    static of(element) {
        return (element && element.treeNode) || null;
    }

    // вложенный узел — в конец папки (новая папка свёрнута)
    adopt(node) {
        if (!(node instanceof TreeView.Node)) {
            return;
        }
        if (!this.childs) {
            this.childs = document.createElement('ul');
            this.childs.classList.add('hidden');
            this.element.appendChild(this.childs);
        }
        this.childs.appendChild(node.element);
        this.tree.nodes.push(node);
    }

    // этот узел — перед другим, на его уровне
    injectBefore(node) {
        if (!(node instanceof TreeView.Node)) {
            return;
        }
        node.element.before(this.element);
    }

    // этот узел — первым в папку другого узла; папка раскрывается
    injectInside(parentNode) {
        if (!(parentNode instanceof TreeView.Node)) {
            return;
        }
        if (!parentNode.childs) {
            parentNode.childs = document.createElement('ul');
            parentNode.childs.classList.add('hidden');
            parentNode.element.appendChild(parentNode.childs);
        }
        parentNode.childs.prepend(this.element);
        parentNode.expand();
        this.tree.setupCssClasses();
    }

    removeChilds() {
        if (!this.childs) {
            return;
        }
        [...this.childs.children].forEach((child) => {
            if (child.treeNode) {
                child.treeNode.remove();
            }
        });
    }

    getPrevious() {
        return TreeView.Node.of(this.element.previousElementSibling);
    }

    getNext() {
        return TreeView.Node.of(this.element.nextElementSibling);
    }

    // li / ul / li
    getParent() {
        const list = this.element.parentElement;
        return TreeView.Node.of(list && list.parentElement);
    }

    getParents() {
        const result = [];
        for (let node = this.getParent(); node; node = node.getParent()) {
            result.push(node);
        }
        return result;
    }

    isParentOf(node) {
        return [...this.element.querySelectorAll('li')].some((item) => item.treeNode === node);
    }

    // поменять местами с соседом
    swap(node) {
        if (!(node instanceof TreeView.Node) || this.isParentOf(node) || node.isParentOf(this)) {
            return;
        }
        const next = this.getNext();
        if (next) {
            if (next === node) {
                node.swap(this);
            } else {
                this.injectBefore(node);
                node.injectBefore(next);
            }
        } else {
            // этот узел — последний: он встаёт на место соседа, сосед — в конец
            this.injectBefore(node);
            this.element.parentElement.appendChild(node.element);
        }
        this.tree.setupCssClasses();
    }

    moveUp() {
        this.swap(this.getPrevious());
    }

    moveDown() {
        this.swap(this.getNext());
    }

    // узел уходит со страницы и из списка дерева
    remove() {
        this.removeChilds();
        this.element.remove();
        const index = this.tree.nodes.indexOf(this);
        if (index !== -1) {
            this.tree.nodes.splice(index, 1);
        }
        this.tree.setupCssClasses();
    }

    toggle() {
        if (this.childs && this.childs.childNodes.length) {
            this.element.classList.toggle('opened');
            this.opened = this.element.classList.contains('opened');
            this.childs.classList.toggle('hidden');
        }
    }

    expand() {
        if (!this.opened) {
            this.toggle();
        }
    }

    collapse() {
        if (this.opened) {
            this.toggle();
        }
    }

    // выбор узла; повторный выбор выбранного сообщает о выборе ещё раз — как прежде
    select() {
        if (this === this.tree.selectedNode) {
            this.emit('select');
        }
        if (this.tree.selectedNode) {
            this.tree.selectedNode.unselect();
        }
        this.tree.selectedNode = this;
        this.element.classList.add('selected');
        this.selected = true;
        this.emit('select');
    }

    unselect() {
        this.element.classList.remove('selected');
        this.selected = false;
    }

    getId() {
        return this.id;
    }

    // название — текстом
    setName(name) {
        this.element.querySelector('a').textContent = name;
    }

    setData(data) {
        this.data = data;
    }

    setIcon(icon) {
        const link = this.element.querySelector('a');
        link.style.backgroundImage = 'url(' + icon + ')';
        link.style.backgroundPosition = '1px 1px';
        link.style.backgroundRepeat = 'no-repeat';
    }

    getData() {
        return this.data;
    }
};
```

- [ ] **Step 2: Пересобрать стенд и проверить всё**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step4-filters-tree
node --check core/modules/share/scripts/TreeView.js
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools; echo "no-traces $?"
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t3-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t3-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in grids editors crawl theme public; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t3-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t3-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t3-$t.log" | head -10; done; cd ../..
```
Expected: синтаксис без ошибок; `no-traces code mootools` — выход 0; регрессия — выход 0; `grids`, `editors`, `crawl`, `theme`, `public` — выход 0.

- [ ] **Step 3: Commit**

```bash
git add core/modules/share/scripts/TreeView.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 4: дерево разделов на чистом JavaScript, удалённый узел уходит из списка" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Документы и итоговая проверка

**Files:**
- Modify: `README.md`, `tests/README.md`

- [ ] **Step 1: `README.md`** — после предложения о шаге 3 дописать: «Шаг 4 (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step4-filters-tree-design.md`): фильтры гридов и дерево разделов — на чистом JavaScript; значение фильтра со «+», «&», «%» доходит до сервера как есть.» и в список спецификаций — строку `` `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step4-filters-tree-design.md` (этап 8, шаг 4) ``.
- [ ] **Step 2: `tests/README.md`** — в «Гриды админки» перед «Записи теста удаляются.» дописать: «Фильтр грида пользователей в окне: панель открывается и закрывается ссылкой, «+» и «−» фильтров, значение с «+» находит своего пользователя, «Сбросить» возвращает все строки. Дерево структуры: выбор раздела, раскрытие папки по значку; узлы на своём дереве: классы, «вверх» и «вниз», путь к узлу, удалённый узел уходит из списка.»
- [ ] **Step 3: Итоговая проверка на чистом стенде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-step4-filters-tree
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
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 4: документы" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Выкладка и проверка на simple.energine.org

Без отдельного согласования (владелец: «продолжай без остановки»). База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step4-<дата>/`.
- [ ] **Step 2: Код** — от имени web97: `git fetch <клон> main && git merge --ff-only FETCH_HEAD` в живом дереве.
- [ ] **Step 3: Статика** — в `web/` от web97: `setup linker && setup scriptMap`; карта: у `Filters` и `TreeView` нет зависимостей.
- [ ] **Step 4: Проверка гостем** — `live-guest.js`.
- [ ] **Step 5: Регрессия и аудиты на площадке** (`regression.sh`, `public`, `grids`, `editors`, `theme`, `crawl`), затем `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 6: При провале** — откат: от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`; отчёт владельцу.
