// Browser test: escaping of HTML in the admin grids (stage 5a). Markup that a visitor could send
// (registration) or an editor could write (a file title, a page name) is shown as text in the grids —
// users, file repository — and in the page tree, and nothing of it is parsed or run.
// The grids' own markup (activity checkboxes, image previews, the file link) stays.
// Everything the test adds is removed (grids-db.php remove).
// Run in a subshell, like crawl.js:
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const { execFileSync } = require('child_process');
const path = require('path');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const PAYLOAD = '<img src="x" onerror="window.claudeXss=(window.claudeXss||0)+1"><b>claude-grid</b>';
const db = (...args) => execFileSync('php8.5', [path.join(__dirname, 'grids-db.php'), ...args], { encoding: 'utf8' });
let fail = 0;
function check(label, cond, detail = '') {
    console.log((cond ? 'OK   ' : 'FAIL ') + label + (cond ? '' : ': ' + String(detail).replace(/\s+/g, ' ').slice(0, 300)));
    if (!cond) fail++;
    return cond;
}
function watch(page) {
    const raw = [];
    page.on('console', (m) => { if (m.type() === 'error') raw.push('console: ' + m.text()); });
    page.on('pageerror', (e) => raw.push('pageerror: ' + e.message));
    page.on('response', (r) => { if (r.status() >= 400) raw.push(`http ${r.status()}: ${r.url()}`); });
    return {
        list() {
            // исключений нет (этап 5в): спрайт старой темы убран, любая 404 — ошибка
            const e = [...new Set(raw)];
            return e;
        },
    };
}
// what the page shows of the payload
const inspect = (page) => page.evaluate(() => {
    const cells = [...document.querySelectorAll('td')];
    return {
        literal: cells.some((td) => td.textContent.includes('<img src="x"')),
        parsedImg: !!document.querySelector('img[src="x"]'),
        parsedB: [...document.querySelectorAll('td b')].some((b) => b.textContent === 'claude-grid'),
        ran: window.claudeXss || 0,
        checkboxes: document.querySelectorAll('td img[src*="checkbox_"]').length,
        previews: document.querySelectorAll('td img').length,
        fileLink: [...document.querySelectorAll('td a[target="_blank"]')].some((a) => a.textContent.includes('<img src="x"')),
    };
});

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    const ctx = await browser.newContext({ locale: 'ru-RU' });
    const lp = await ctx.newPage();
    await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
    await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
    await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
    await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
    await lp.close();

    db('remove');
    const ids = JSON.parse(db('add'));
    try {
        const grids = [
            { label: 'пользователи', url: 'admin/users/', extra: (r) => check('пользователи: флажки активности на месте', r.checkboxes > 0, JSON.stringify(r)) },
            {
                label: 'файлы', url: 'admin/users/single/adminPanel/file-library/', folder: ids.root,
                extra: (r) => check('файлы: ссылка на файл и превью на месте, название — текстом', r.fileLink && r.previews > 0, JSON.stringify(r)),
            },
        ];
        for (const g of grids) {
            if (g.folder) await ctx.addCookies([{ name: 'NRGNFRPID', value: String(g.folder), url: BASE }]);
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + g.url, { waitUntil: 'networkidle' });
            await p.waitForTimeout(1000);
            const r = await inspect(p);
            check(`${g.label}: разметка из данных показана текстом`, r.literal, JSON.stringify(r));
            check(`${g.label}: разметка не разобрана и не исполнена`, !r.parsedImg && !r.parsedB && !r.ran, JSON.stringify(r));
            if (g.extra) g.extra(r);
            check(`${g.label}: без ошибок JS и 404`, !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // the page tree: a node named with markup, and a renamed node (as after saving a page)
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'admin/structure/', { waitUntil: 'networkidle' });
        const t = await p.evaluate(async (payload) => {
            const TreeView = window.TreeView || (await import('TreeView')).TreeView;
            // a stand-in for the tree: the node only binds its listeners
            const tree = { nodeToggleListener() {}, nodeSelectListener() {}, options: { dblClick() {} } };
            const node = new TreeView.Node({ id: 'claude', name: payload, data: { segment: 'claude', icon: '' } }, tree);
            const a = node.element.querySelector('a');
            const created = { text: a.textContent, img: !!a.querySelector('img') };
            node.setName(payload);
            return { created, renamed: { text: a.textContent, img: !!a.querySelector('img') }, ran: window.claudeXss || 0 };
        }, PAYLOAD);
        check('дерево страниц: имя с разметкой — текстом', !t.error && t.created.text === PAYLOAD && !t.created.img
            && t.renamed.text === PAYLOAD && !t.renamed.img && !t.ran, JSON.stringify(t));
        check('дерево страниц: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
        await p.close();

        // одно дерево разделов: без выбора сайта, узлы загружаются (редактор структуры и окно выбора родителя
        // в форме раздела — кнопка «…» у поля родителя открывает состояние list/ редактора разделов)
        for (const [label, url] of [['структура', 'admin/structure/'],
            ['выбор родителя в форме раздела', 'admin/structure/single/divEditor/list/']]) {
            const tp = await ctx.newPage();
            const tErrors = watch(tp);
            await tp.goto(BASE + url, { waitUntil: 'networkidle' });
            await tp.waitForSelector('.treeview li a', { timeout: 10000 }).catch(() => null);
            const r = await tp.evaluate(() => ({
                selector: !!document.querySelector('#treeContainer select'),
                nodes: document.querySelectorAll('.treeview li a').length,
            }));
            check(`${label}: дерево без выбора сайта, узлы загружены`, !r.selector && r.nodes > 1, JSON.stringify(r));
            check(`${label}: без ошибок JS и 404`, !tErrors.list().length, tErrors.list().join(' | '));
            await tp.close();
        }

        // запросы админки через Energine.request: заголовки и тело — как у прежнего запроса MooTools (грид
        // пользователей при открытии); отказ сервера (чужой токен — 422 с текстом ERR_CSRF) — текст отказа и
        // onUserError. Панель грида привязана к гриду: встроенный скрипт панели (toolbar.xslt) запускается после
        // поведений страницы (document.xslt)
        {
            const rp = await ctx.newPage();
            const rErrors = watch(rp);
            const sent = [];
            rp.on('request', (r) => {
                if (r.url().includes('/get-data/')) sent.push({ url: r.url(), method: r.method(), headers: r.headers(), body: r.postData() });
            });
            await rp.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const q = sent[0] || { headers: {} };
            const h = q.headers;
            check('Energine.request: POST, заголовки X-Request, X-Requested-With, Accept, тип тела и токен',
                q.method === 'POST' && h['x-request'] === 'JSON' && h['x-requested-with'] === 'XMLHttpRequest'
                && h['accept'] === 'application/json'
                && /^application\/x-www-form-urlencoded; charset=utf-8$/i.test(h['content-type'] || '')
                && /^[0-9a-f]{64}$/.test(h['x-csrf-token'] || ''), JSON.stringify({ method: q.method, headers: h }));
            check('Energine.request: тело запроса грида при открытии — пустое', !!sent.length && !q.body, String(q.body));
            const tb = await rp.evaluate(() => Object.keys(window.componentToolbars || {}).map((id) => ({ id,
                attached: !!window[id] && window[id].toolbar === window.componentToolbars[id] })));
            const buttons = await rp.evaluate(() => document.querySelectorAll('.e-pane-t-toolbar li.add_btn, .e-pane-t-toolbar li.edit_btn').length);
            check('грид пользователей: панель привязана к гриду, кнопки на месте', tb.length === 1 && tb[0].attached && buttons === 2,
                JSON.stringify({ tb, buttons }));
            const dialogs = [];
            rp.on('dialog', (d) => { dialogs.push(d.message()); d.accept(); });
            const outcome = await rp.evaluate((url) => new Promise((resolve) => {
                const csrf = Energine.csrf;
                Energine.csrf = '0'.repeat(64);
                Energine.request(url, null, () => resolve('success'), () => resolve('userError'),
                    (text) => resolve('serverError: ' + text));
                Energine.csrf = csrf;
                setTimeout(() => resolve('timeout'), 10000);
            }), q.url || '');
            check('Energine.request: отказ сервера (422) — текст отказа и onUserError', outcome === 'userError'
                && dialogs.length === 1 && dialogs[0].includes('Форма устарела'), JSON.stringify({ outcome, dialogs }));
            // отказ 422 здесь ожидаем; всё прочее — ошибка
            const other = rErrors.list().filter((e) => !/^http 422: .*\/get-data\//.test(e) && !/status of 422/.test(e));
            check('Energine.request: без других ошибок JS и 404', !other.length, other.join(' | '));
            // the answer breaks off while its body is read (the connection is lost after the headers): a network
            // error — onServerError(''), as the spec says; nothing left hanging (an overlay waits for a handler)
            const broken = await rp.evaluate((url) => new Promise((resolve) => {
                const text = Response.prototype.text;
                Response.prototype.text = function () {
                    Response.prototype.text = text;
                    return Promise.reject(new TypeError('network error'));
                };
                Energine.request(url, null, () => resolve('success'), () => resolve('userError'),
                    (body) => resolve('serverError:' + JSON.stringify(body)));
                setTimeout(() => resolve('timeout'), 10000);
            }), q.url || '');
            check('Energine.request: ответ оборвался на чтении тела — onServerError(\'\')', broken === 'serverError:""', broken);
            await rp.close();
        }


        // затемнение (Overlay): показать — убрать — показать подряд оставляет его видимым (новая загрузка сразу после
        // быстрой); убранное после исчезновения уходит со страницы
        {
            const op = await ctx.newPage();
            await op.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const race = await op.evaluate(async () => {
                const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
                const box = document.createElement('div');
                document.body.appendChild(box);
                const Overlay = window.Overlay || (await import('Overlay')).Overlay;
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
                await route.continue().catch(() => {});
            });
            const before = loads.length;
            const loaded = gp.waitForResponse((r) => r.url().includes('/transEditor/get-data/'), { timeout: 15000 });
            await gp.click('.e-pagelist li[index="2"]');
            await gp.waitForTimeout(500);
            const during = await state();
            // щелчок прямо по номеру страницы (мышь не прошла бы сквозь затемнение): выключенная листалка его не берёт
            await gp.evaluate(() => document.querySelector('.e-pagelist li[index="3"]').click());
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
            // номер страницы за последней (сервер его не ограничивает — так бывает после удаления единственной записи
            // последней страницы): листалка отмечает последнюю страницу, грид не остаётся затемнённым
            const beyond = await gp.evaluate(async () => {
                const id = document.querySelector('.e-pagelist').closest('[id]').id;
                window[id].loadPage(99);
                await new Promise((resolve) => setTimeout(resolve, 2500));
                const list = document.querySelector('.e-pagelist');
                return { current: ((list.querySelector('li.current')) || {}).textContent || '',
                    next: !!list.querySelector('img[alt="next"]'), overlays: document.querySelectorAll('.e-overlay').length };
            });
            check('листалка: страница за последней — отмечена последняя, стрелки «дальше» нет, затемнения нет',
                beyond.current === '18' && !beyond.next && !beyond.overlays, JSON.stringify(beyond));
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

        // журнал действий: фильтр по дате — встроенное поле даты браузера (input type="date"); за сегодня (запись
        // теста) строки находятся, за день без записей — нет
        {
            const lp = await ctx.newPage();
            const lErrors = watch(lp);
            await lp.goto(BASE + 'admin/action-log/', { waitUntil: 'networkidle' });
            await lp.waitForTimeout(1000);
            const picked = await lp.evaluate(() => {
                const sel = document.querySelector('.filters .filter .f_fields');
                const opt = sel && [...sel.options].find((o) => ['date', 'datetime'].includes(o.getAttribute('type')));
                if (!opt) return null;
                sel.value = opt.value;
                sel.dispatchEvent(new Event('change'));
                return opt.value;
            });
            // панель фильтра раскрывается ссылкой только в окне грида и на узком экране, иначе она открыта
            if (await lp.isVisible('.filter_toggle')) {
                await lp.click('.filter_toggle');
                await lp.waitForTimeout(800);
            }
            const input = lp.locator('.filters .filter .f_query_container input[type="date"]:visible').first();
            if (check('журнал действий: фильтр по дате — встроенное поле даты', !!picked && await input.count() > 0, picked)) {
                const rowsFor = async (day) => {
                    await input.fill(day);
                    const [resp] = await Promise.all([
                        lp.waitForResponse((r) => r.url().includes('get-data'), { timeout: 15000 }),
                        lp.click('button.f_apply'),
                    ]);
                    const j = await resp.json().catch(() => null);
                    // строк нет — в ответе нет и data
                    return j && j.result ? (Array.isArray(j.data) ? j.data.length : 0) : -1;
                };
                const today = await rowsFor(ids.today);
                const empty = await rowsFor('2001-01-01');
                check('журнал действий: фильтр по дате находит записи дня и не находит чужие', today > 0 && empty === 0,
                    JSON.stringify({ day: ids.today, today, empty }));
                // «между» — два поля; после смены условия на одиночное второе поле скрыто и в запрос не уходит
                const sentValue = await lp.evaluate(() => {
                    const cond = document.querySelector('.filters .filter .f_condition');
                    const between = [...cond.options].find((o) => o.value === 'between');
                    if (!between) return 'no between';
                    cond.value = 'between';
                    cond.dispatchEvent(new Event('change'));
                    const dates = [...document.querySelectorAll('.filters .filter .f_query_container input[type="date"]')];
                    dates[1].value = '2099-12-31';
                    const single = [...cond.options].find((o) => o.value !== 'between');
                    cond.value = single.value;
                    cond.dispatchEvent(new Event('change'));
                    return single.value;
                });
                await input.fill(ids.today);
                const [resp] = await Promise.all([
                    lp.waitForResponse((r) => r.url().includes('get-data'), { timeout: 15000 }),
                    lp.click('button.f_apply'),
                ]);
                const body = decodeURIComponent((resp.request().postData() || '').replace(/^.*?filter=/, '').replace(/&.*$/, ''));
                const clause = (() => { try { return JSON.parse(body).children[0]; } catch (e) { return null; } })();
                check('журнал действий: после «между» одиночное условие уходит с одним значением — видимым',
                    !!clause && clause.value === ids.today, JSON.stringify({ sentValue, clause, body: body.slice(0, 300) }));
            }
            check('журнал действий, фильтр по дате: без ошибок JS и 404', !lErrors.list().length, lErrors.list().join(' | '));
            await lp.close();
        }

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
            // значение стёрто — «Применить» снимает фильтр и возвращает все строки
            await fp.fill('.filters .filter .f_query_container input.query', '');
            const cleared = await Promise.all([fp.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 5000 }).catch(() => null),
                fp.click('button.f_apply')]).then(([resp]) => !!resp);
            await fp.waitForTimeout(500);
            const afterClear = { reloaded: cleared, rows: (await rows()).length,
                active: await fp.evaluate(() => document.querySelector('.filters_block').classList.contains('active')) };
            check('фильтр грида: «Применить» со стёртым значением снимает фильтр — все строки', afterClear.reloaded
                && afterClear.rows === all && !afterClear.active, JSON.stringify({ all, afterClear }));
            await fp.fill('.filters .filter .f_query_container input.query', 'grid-a+b');
            await Promise.all([fp.waitForResponse((r) => r.url().includes('/get-data/')), fp.click('button.f_apply')]);
            await fp.waitForTimeout(500);
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
            const r = await np.evaluate(async () => {
                const ul = document.createElement('ul');
                document.body.appendChild(ul);
                const TreeView = window.TreeView || (await import('TreeView')).TreeView;
                const tree = new TreeView(ul, {});
                const make = (id) => new TreeView.Node({ id, name: 'N' + id, data: { segment: 'n' + id, icon: '' } }, tree);
                const [root, a, b, c, d] = [0, 1, 2, 3, 4].map(make);
                tree.appendNode(root);
                root.appendNode(a);
                root.appendNode(b);
                root.appendNode(c);
                c.appendNode(d);
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
            // окна с панели страницы открываются над страницей без MooTools: грид в каждом строится (скрипты окна на
            // MooTools не должны вызывать её методы у документа родительского окна)
            for (const btn of ['transEditor', 'language', 'user', 'role', 'fileRepository', 'siteSettings']) {
                await hp.click(`li.${btn}_btn`);
                const frameEl = await hp.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
                const frame = frameEl && await frameEl.contentFrame();
                const built = !!frame && !!(await frame.waitForSelector('ul.toolbar li', { timeout: 10000 }).catch(() => null));
                check(`панель страницы: окно «${btn}» — грид с панелью построен`, built);
                await hp.evaluate(() => ModalBox.close());
                await hp.waitForTimeout(700);
            }
            // боковая панель: скрипты разделов на MooTools в iframe над страницей без MooTools — дерево и панель
            // строятся, щелчок по разделу включает «Редактировать», оно открывает окно формы раздела через окна страницы
            await hp.click('.e-topframe img.pagetb_logo');
            const sideEl = await hp.$('.e-sideframe iframe');
            const side = sideEl && await sideEl.contentFrame();
            let tree = { nodes: 0, buttons: 0 }, editOn = false, opened = false;
            if (side) {
                await side.waitForSelector('#divTree li a', { timeout: 10000 }).catch(() => null);
                tree = await side.evaluate(() => ({ nodes: document.querySelectorAll('#divTree li a').length,
                    buttons: document.querySelectorAll('ul.toolbar li').length }));
                await side.click('#divTree li a').catch(() => null);
                await side.waitForTimeout(300);
                editOn = await side.evaluate(() => {
                    const b = document.querySelector('ul.toolbar li.edit_btn');
                    return !!b && !b.classList.contains('disabled');
                });
                if (editOn) {
                    await side.click('ul.toolbar li.edit_btn');
                    const winEl = await hp.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
                    const win = winEl && await winEl.contentFrame();
                    opened = !!win && !!(await win.waitForSelector('ul.toolbar li', { timeout: 10000 }).catch(() => null));
                    await hp.evaluate(() => ModalBox.close());
                    await hp.waitForTimeout(700);
                }
            }
            check('панель страницы: боковая панель — дерево разделов и панель, «Редактировать» открывает окно раздела',
                tree.nodes > 1 && tree.buttons > 0 && editOn && opened, JSON.stringify({ tree, editOn, opened }));
            await hp.click('.e-topframe img.pagetb_logo');
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
            const api = await ap.evaluate(async () => {
                const calls = [];
                const box = document.createElement('div');
                document.body.appendChild(box);
                const Toolbar = window.Toolbar || (await import('Toolbar')).Toolbar;
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

        // «Настройки сайта» с панели страницы: окно с гридом единственной записи сайта
        const sp = await ctx.newPage();
        const spErrors = watch(sp);
        await sp.goto(BASE, { waitUntil: 'networkidle' });
        const btn = sp.locator('ul.toolbar li', { hasText: 'Настройки сайта' }).first();
        if (check('панель страницы: кнопка «Настройки сайта»', await btn.count() > 0)) {
            await btn.click();
            const frameEl = await sp.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const frame = frameEl && await frameEl.contentFrame();
            let rows = -1, src = '';
            if (frame) {
                await frame.waitForSelector('tbody tr td', { timeout: 10000 }).catch(() => null);
                src = frame.url();
                rows = await frame.evaluate(() => [...document.querySelectorAll('tbody tr')].filter((tr) => tr.querySelector('td')).length);
            }
            check('панель страницы: «Настройки сайта» — окно с гридом одной записи', /site-settings\/$/.test(src) && rows === 1,
                `src=${src} rows=${rows}`);
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
        }
        check('панель страницы, «Настройки сайта»: без ошибок JS и 404', !spErrors.list().length, spErrors.list().join(' | '));
        await sp.close();

        // ===== stage 8, step 6: the grids without MooTools — what they do stays as it was =====
        const SITE_PATH = new URL(BASE).pathname;
        const showTab = (page, selector) => page.evaluate((sel) => {
            for (let el = document.querySelector(sel); el; el = el.parentElement) {
                const link = el.id && document.querySelector('a[href="#' + el.id + '"]');
                if (link) {
                    link.click();
                    return true;
                }
            }
            return false;
        }, selector);
        const gridState = (target) => target.evaluate(() => {
            const gm = [...document.querySelectorAll('.e-pane')].find((pane) => pane.GridManager).GridManager;
            return {
                rows: [...gm.grid.tbody.querySelectorAll('tr')].filter((tr) => tr.record)
                    .map((tr) => ({ key: String(tr.record[gm.grid.keyFieldName]), sel: tr.classList.contains('selected'), text: tr.textContent.trim() })),
                keys: String(gm.grid.getSelectedRecordKey(true)),
            };
        });
        const filterGrid = async (page, value) => {
            await page.click('.filter_toggle');
            await page.waitForTimeout(300);
            await page.fill('.filters .filter .f_query_container input.query', value);
            await Promise.all([page.waitForResponse((r) => r.url().includes('/get-data/')), page.click('button.f_apply')]);
            await page.waitForTimeout(500);
        };

        // 1. no MooTools: the grid pages and the file library in a form window (requests of the checked document
        //    only: the sidebar of a full page — DivSidebar — keeps MooTools till step 7)
        {
            const mooFree = async (label, open) => {
                const p = await ctx.newPage();
                const errors = watch(p);
                const requests = [];
                p.on('request', (r) => { if (/mootools/i.test(r.url())) requests.push(r); });
                const target = await open(p);
                const frame = target && (target.mainFrame ? target.mainFrame() : target);
                const asked = requests.filter((r) => r.frame() === frame).map((r) => r.url());
                const moo = target ? await target.evaluate(() => typeof window.MooTools) : 'no window';
                check(`гриды без MooTools: ${label}`, moo === 'undefined' && !asked.length, JSON.stringify({ moo, asked }));
                check(`гриды без MooTools: ${label} — без ошибок JS и 404`, !errors.list().length, errors.list().join(' | '));
                await p.close();
            };
            for (const [label, url] of [['пользователи', 'admin/users/'], ['роли', 'admin/users/roles/'],
                ['языки', 'admin/translations/languages/'], ['переводы', 'admin/translations/'],
                ['шаблоны писем', 'admin/mail-templates/'], ['журнал действий', 'admin/action-log/'],
                ['репозиторий файлов', 'admin/users/single/adminPanel/file-library/']]) {
                await mooFree(label, async (p) => {
                    await p.goto(BASE + url, { waitUntil: 'networkidle' });
                    return p;
                });
            }
            await mooFree('библиотека файлов в окне формы', async (p) => {
                await p.goto(BASE + `admin/users/single/userEditor/${ids.user}/edit/`, { waitUntil: 'networkidle' });
                await showTab(p, 'button[onclick*="openFileLib"]');
                await p.click('button[onclick*="openFileLib"]');
                const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
                const f = el && await el.contentFrame();
                if (f) {
                    await f.waitForLoadState('networkidle').catch(() => null);
                    await f.waitForSelector('tbody tr td', { timeout: 10000 }).catch(() => null);
                }
                return f;
            });
        }

        // 2. rows (users window, the test users by the grid filter): a click selects one row, Shift — a range,
        //    Ctrl — one more; the keys go comma-separated; a double click opens the record; «Удалить» two rows
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const dialogs = [];
            p.on('dialog', (d) => { dialogs.push(d.type()); d.accept(); });
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            await filterGrid(p, 'claude-grid-del');
            const rows = p.locator('.gridContainer tbody tr');
            const s0 = await gridState(p);
            await rows.nth(0).click();
            const s1 = await gridState(p);
            await rows.nth(2).click({ modifiers: ['Shift'] });
            const s2 = await gridState(p);
            await rows.nth(1).click();
            await rows.nth(2).click({ modifiers: ['Control'] });
            const s3 = await gridState(p);
            check('выбор строк: щелчок — одна строка', s0.rows.length === 3 && s1.rows.filter((r) => r.sel).length === 1 && s1.rows[0].sel,
                JSON.stringify({ s0, s1 }));
            check('выбор строк: Shift+щелчок — диапазон', s2.rows.every((r) => r.sel)
                && s2.keys === [s2.rows[0].key, s2.rows[1].key, s2.rows[2].key].join(','), JSON.stringify(s2));
            check('выбор строк: Ctrl+щелчок — ещё одна, ключи через запятую', !s3.rows[0].sel && s3.rows[1].sel && s3.rows[2].sel
                && s3.keys === [s3.rows[1].key, s3.rows[2].key].join(','), JSON.stringify(s3));

            await rows.nth(1).dblclick();
            const win = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const src = win ? await win.evaluate((f) => f.src) : '';
            check('двойной щелчок по строке — окно правки этой записи', src.endsWith(`/${s3.rows[1].key}/edit`), src);
            await p.evaluate(() => ModalBox.close());
            await p.waitForTimeout(600);

            await rows.nth(1).click();
            await rows.nth(2).click({ modifiers: ['Control'] });
            const keys = (await gridState(p)).keys;
            const [del] = await Promise.all([
                p.waitForRequest((r) => /\/delete\/?$/.test(r.url()), { timeout: 10000 }),
                p.click('ul.toolbar li.delete_btn'),
            ]);
            await p.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 10000 }).catch(() => null);
            await p.waitForTimeout(600);
            const left = await gridState(p);
            check('«Удалить» двух выбранных: подтверждение, запрос …/id1,id2/delete/, осталась одна строка', dialogs.includes('confirm')
                && del.url().endsWith(`/${keys}/delete/`) && left.rows.length === 1 && left.rows[0].key === s3.rows[0].key,
                JSON.stringify({ dialogs, url: del.url(), keys, left }));
            check('выбор и удаление строк: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 3. sorting, columns, window size (users window): the header cycles asc → desc → none; the head columns are
        //    as wide as the body ones; the grid follows the window height
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const urls = [];
            p.on('request', (r) => { if (r.url().includes('/get-data/')) urls.push(r.url()); });
            await p.setViewportSize({ width: 1280, height: 720 });
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            const head = '.gridHeadContainer th[name="u_name"]';
            const clickSort = async () => {
                await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), p.click(head)]);
                await p.waitForTimeout(300);
                return { url: urls[urls.length - 1], cls: await p.evaluate((s) => document.querySelector(s).className, head) };
            };
            const a = await clickSort(), d = await clickSort(), n = await clickSort();
            check('сортировка: щелчок по заголовку — по возрастанию, второй — по убыванию, третий — без сортировки',
                /get-data\/u_name-asc\/page-1$/.test(a.url) && a.cls === 'asc' && /get-data\/u_name-desc\/page-1$/.test(d.url)
                && d.cls === 'desc' && /get-data\/page-1$/.test(n.url) && n.cls === '', JSON.stringify({ a, d, n }));
            const cols = await p.evaluate(() => ({
                head: [...document.querySelectorAll('.gridHeadContainer col')].map((c) => c.style.width),
                body: [...document.querySelectorAll('.gridContainer col')].map((c) => c.style.width),
                ths: [...document.querySelectorAll('.gridHeadContainer th')].map((th) => Math.round(th.getBoundingClientRect().width)),
                tds: [...document.querySelectorAll('.gridContainer tbody tr:first-child td')].map((td) => Math.round(td.getBoundingClientRect().width)),
            }));
            check('колонки: ширины колонок заголовка — как у тела', cols.head.length > 0 && cols.head.join() === cols.body.join()
                && cols.head.every((w) => /^\d+px$/.test(w)) && cols.ths.every((w, i) => Math.abs(w - cols.tds[i]) <= 1), JSON.stringify(cols));
            const height = () => p.evaluate(() => parseInt(document.querySelector('.gridContainer').style.height, 10));
            const h720 = await height();
            await p.setViewportSize({ width: 1280, height: 480 });
            await p.waitForTimeout(600);
            const h480 = await height();
            check('размер окна: высота грида в окне следует за окном', h720 > 0 && h720 - h480 === 240, JSON.stringify({ h720, h480 }));
            check('сортировка, колонки, размер окна: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }
        {
            // a full page: the pane follows the window
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.setViewportSize({ width: 1280, height: 720 });
            await p.goto(BASE + 'admin/translations/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(600);
            const size = () => p.evaluate(() => {
                const g = document.querySelector('.gridContainer');
                return { pane: parseInt(g.closest('.e-pane').style.height, 10), grid: parseInt(g.style.height, 10) };
            });
            const s720 = await size();
            await p.setViewportSize({ width: 1280, height: 480 });
            await p.waitForTimeout(600);
            const s480 = await size();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.waitForTimeout(600);
            const s900 = await size();
            check('размер окна: панель грида на странице следует за окном', s480.pane < s720.pane && s720.pane < s900.pane
                && s900.grid > s720.grid, JSON.stringify({ s480, s720, s900 }));
            check('размер окна, страница: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 4. «Вверх», «Вниз» (languages window; the requests are answered here — the order of the languages stays)
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const moves = [];
            await p.route(/\/(up|down)\/$/, (route) => {
                moves.push(route.request().url());
                route.fulfill({ status: 200, contentType: 'application/json', body: '{"result":true}' });
            });
            await p.goto(BASE + 'admin/translations/languages/single/langEditor/', { waitUntil: 'networkidle' });
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const key = (await gridState(p)).keys;
            const [down] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.down_btn'),
            ]);
            await p.waitForTimeout(500);
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const [up] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.up_btn'),
            ]);
            check('«Вниз» и «Вверх»: запросы …/<id>/down/ и …/<id>/up/, грид перезагружает ту же страницу', moves.length === 2
                && moves[0].endsWith(`/${key}/down/`) && moves[1].endsWith(`/${key}/up/`)
                && /get-data\/page-1$/.test(down.url()) && /get-data\/page-1$/.test(up.url()), JSON.stringify({ moves, down: down.url(), up: up.url() }));
            check('«Вниз» и «Вверх»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 5. «Править предыдущий» (mail templates): the window closes, the grid opens the previous template; the
        //    template saved without edits is unchanged
        {
            const mailAll = () => execFileSync('php8.5', [path.join(__dirname, 'editors-db.php'), 'mail-all'], { encoding: 'utf8' });
            const was = mailAll();
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/mail-templates/', { waitUntil: 'networkidle' });
            await p.waitForSelector('tbody tr td', { timeout: 10000 });
            const rows = p.locator('.gridContainer tbody tr');
            await rows.nth(1).click();
            const keys = (await gridState(p)).rows.map((r) => r.key);
            await p.click('ul.toolbar li.edit_btn');
            const frameEl = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const first = await frameEl.evaluate((f) => f.src);
            const frame = await frameEl.contentFrame();
            await frame.waitForSelector('li.save_btn', { timeout: 10000 });
            await frame.selectOption('li.select select', 'editPrev');
            await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                frame.click('li.save_btn'),
            ]);
            await p.waitForFunction((url) => [...document.querySelectorAll('.e-modalbox iframe')]
                .some((f) => f.src !== url && /\/edit\/?$/.test(f.src)), first, { timeout: 15000 }).catch(() => null);
            const next = await p.evaluate(() => [...document.querySelectorAll('.e-modalbox iframe')].map((f) => f.src));
            check('«Править предыдущий»: окно закрыто, открыта правка предыдущей записи', first.endsWith(`/${keys[1]}/edit`)
                && next.length === 1 && next[0].endsWith(`/${keys[0]}/edit`), JSON.stringify({ keys, first, next }));
            check('«Править предыдущий»: шаблон без правки не изменился', mailAll() === was);
            check('«Править предыдущий»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
            await ctx.clearCookies({ name: 'after_add_default_action' });
        }

        // 6. the file repository: a double click opens the repository and the folder; the crumbs lead back; the
        //    folder is remembered in a cookie and opened after a reload; file sizes (also of a file under 1 KiB);
        //    hovering a preview shows a bigger picture, leaving it removes it
        {
            await ctx.clearCookies({ name: 'NRGNFRPID' });
            const p = await ctx.newPage();
            const errors = watch(p);
            const loads = [];
            p.on('request', (r) => { if (r.url().includes('/get-data/')) loads.push(r.url()); });
            const lib = BASE + 'admin/users/single/adminPanel/file-library/';
            await p.goto(lib, { waitUntil: 'networkidle' });
            const openRow = async (title) => {
                const row = p.locator('.gridContainer tbody tr', { hasText: title }).first();
                await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), row.dblclick()]);
                await p.waitForTimeout(800);
            };
            const titles = async () => (await gridState(p)).rows.map((r) => r.text);
            await openRow((await titles())[0]);
            await openRow('claude-grid-dir');
            const inside = await titles();
            const crumbs = await p.evaluate(() => [...document.querySelectorAll('#breadcrumbs a')].map((a) => a.textContent));
            const cookie = (await ctx.cookies(BASE)).find((c) => c.name === 'NRGNFRPID');
            check('репозиторий: двойной щелчок открывает хранилище и папку, крошки — путь', inside.some((t) => t.includes('claude-grid-big'))
                && inside.some((t) => t.includes('claude-grid-tiny')) && crumbs.length >= 2 && crumbs[crumbs.length - 1].includes('claude-grid-dir'),
                JSON.stringify({ inside, crumbs }));
            check('репозиторий: папка запомнена в cookie на сутки с путём сайта', !!cookie && cookie.value === String(ids.dir)
                && cookie.path === SITE_PATH, JSON.stringify(cookie));
            await p.waitForTimeout(1500);
            const sizes = await p.evaluate(() => [...document.querySelectorAll('.gridContainer tbody tr')].map((tr) => ({
                text: tr.textContent, size: [...tr.querySelectorAll('td.properties tr')].map((r) => r.textContent).find((t) => /\d (B|KiB|MiB)$/.test(t)) || '',
            })).filter((r) => r.text.includes('claude-grid-')));
            const big = sizes.find((r) => r.text.includes('claude-grid-big')) || {}, tiny = sizes.find((r) => r.text.includes('claude-grid-tiny')) || {};
            check('репозиторий: размер файла в свойствах', /9\.0\d KiB$/.test(big.size || ''), JSON.stringify(sizes));
            check('репозиторий: размер файла меньше 1 КиБ — в байтах, без ошибки JS', /\d+(\.\d+)? B$/.test(tiny.size || '')
                && !errors.list().some((e) => /toPrecision/.test(e)), JSON.stringify({ sizes, errors: errors.list() }));

            const thumb = p.locator('.gridContainer tbody tr', { hasText: 'claude-grid-big' }).locator('.thumb_container').first();
            await thumb.hover();
            await p.waitForTimeout(1200);
            const popup = await p.evaluate(() => {
                const img = [...document.querySelectorAll('body > img')].find((i) => i.src.includes('w298-h224/'));
                return img ? { src: img.src, w: Math.round(img.getBoundingClientRect().width) } : null;
            });
            await p.mouse.move(5, 5);
            await p.waitForTimeout(500);
            const after = await p.evaluate(() => [...document.querySelectorAll('body > img')].filter((i) => i.src.includes('w298-h224/')).length);
            check('репозиторий: наведение на превью — увеличенная картинка, уход мыши — убрана', !!popup
                && popup.src.endsWith('w298-h224/uploads/public/claude-grid-dir/claude-grid-big.png') && popup.w > 200 && after === 0,
                JSON.stringify({ popup, after }));

            loads.length = 0;
            await p.goto(lib, { waitUntil: 'networkidle' });
            check('репозиторий: после перезагрузки открыта запомненная папка', loads.length > 0 && loads[0].includes(`/${ids.dir}/get-data/`),
                JSON.stringify(loads));
            await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), p.click('#breadcrumbs a')]);
            await p.waitForTimeout(800);
            check('репозиторий: крошка ведёт назад — в папке видна папка теста', (await titles()).some((t) => t.includes('claude-grid-dir')),
                JSON.stringify(await titles()));
            check('репозиторий: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 7. the library in a form window: «…» → the remembered folder → a file → «Выбрать» — the path in the form
        {
            await ctx.addCookies([{ name: 'NRGNFRPID', value: String(ids.dir), url: BASE }]);
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/users/single/userEditor/${ids.user}/edit/`, { waitUntil: 'networkidle' });
            await showTab(p, 'button[onclick*="openFileLib"]');
            await p.click('button[onclick*="openFileLib"]');
            const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const f = await el.contentFrame();
            await f.waitForSelector('tbody tr td', { timeout: 10000 });
            await f.waitForTimeout(800);
            await f.locator('.gridContainer tbody tr', { hasText: 'claude-grid-big' }).first().click();
            await f.click('ul.toolbar li.open_btn');
            await p.waitForTimeout(800);
            const value = await p.evaluate(() => {
                const btn = document.querySelector('button[onclick*="openFileLib"]');
                return { path: document.getElementById(btn.getAttribute('link')).value, windows: document.querySelectorAll('.e-modalbox').length };
            });
            check('библиотека в окне формы: файл из папки — путь в поле формы, окно закрыто',
                value.path === 'uploads/public/claude-grid-dir/claude-grid-big.png' && value.windows === 0, JSON.stringify(value));
            check('библиотека в окне формы: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();   // the form is not saved
            await ctx.clearCookies({ name: 'NRGNFRPID' });
        }

        // 8. «Активировать» (users window, the inactive test user)
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            await filterGrid(p, 'claude-grid-off');
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const before = db('user-active', String(ids.off)).trim();
            const [act] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/activate/'), { timeout: 10000 }),
                p.click('ul.toolbar li.activate_btn'),
            ]);
            await p.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 10000 }).catch(() => null);
            check('«Активировать»: запрос …/<id>/activate/, пользователь активен, грид перезагружен', before === '0'
                && act.url().endsWith(`/${ids.off}/activate/`) && db('user-active', String(ids.off)).trim() === '1', act.url());
            check('«Активировать»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 9. «Очистить» the action log (the request is answered here — the log stays): a refusal sends nothing,
        //    the consent sends clear and reloads the grid
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            let consent = false;
            p.on('dialog', (d) => (consent ? d.accept() : d.dismiss()));
            const clears = [];
            await p.route(/\/clear\/$/, (route) => {
                clears.push(route.request().url());
                route.fulfill({ status: 200, contentType: 'application/json', body: '{"result":true}' });
            });
            await p.goto(BASE + 'admin/action-log/single/actionsList/', { waitUntil: 'networkidle' });
            await p.click('ul.toolbar li.clear_btn');
            await p.waitForTimeout(600);
            const refused = clears.length;
            consent = true;
            const [reload] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.clear_btn'),
            ]);
            check('«Очистить» журнал: отказ — запроса нет, согласие — запрос clear и перезагрузка', refused === 0 && clears.length === 1
                && /\/clear\/$/.test(clears[0]) && !!reload, JSON.stringify({ refused, clears }));
            check('«Очистить» журнал: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

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
        // the link of a node; its folders are opened first, as a person would do
        const nodeAnchor = (target, key, id) => target.evaluateHandle(([k, nodeId]) => {
            window[k].tree.expandToNode(nodeId);
            return window[k].tree.getNodeById(nodeId).element.querySelector('a');
        }, [key, id]);

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
            check('структура: дерево построено, выбран текущий раздел', !!key && !!start.selected && /(^|\/)structure\/?$/.test(start.selected.segment),
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
            // the server answers get-node-data with the name, the parent and the order only (DivisionEditor::getNodeData)
            await p.route(/get-node-data$/, (route) => route.fulfill({ status: 200, contentType: 'application/json',
                body: JSON.stringify({ result: true, data: { smap_name: 'Claude renamed', smap_pid: data.smap_pid,
                    smap_order_num: data.smap_order_num } }) }));
            await p.click('ul.toolbar li.edit_btn');
            const win = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const src = win ? await win.evaluate((f) => f.src) : '';
            await Promise.all([p.waitForRequest((r) => /get-node-data$/.test(r.url()), { timeout: 10000 }), p.evaluate(() => ModalBox.close())]);
            await p.waitForTimeout(400);
            const renamed = await p.evaluate(([k, id]) => window[k].tree.getNodeById(id).element.querySelector('a').textContent, [key, pick.x]);
            check('структура: «Править» — окно правки раздела, после него имя узла обновлено', src.endsWith(`/${pick.x}/edit`)
                && renamed === 'Claude renamed', JSON.stringify({ src, renamed }));
            const kept = await p.evaluate(([k, id]) => window[k].tree.getNodeById(id).getData().smap_segment, [key, pick.x]);
            check('структура: после «Править» данные узла на месте (сегмент — для перехода)', kept === pick.segment, String(kept));

            await Promise.all([p.waitForNavigation({ timeout: 15000 }).catch(() => null), (await nodeAnchor(p, key, pick.x)).dblclick()]);
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
            // a double click in the window chooses nothing and does not take the page away from the unsaved form
            const formUrl = p.url();
            await p.click('#sitemap_selector');
            const el2 = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const f2 = await el2.contentFrame();
            await f2.waitForSelector('#divTree li', { timeout: 10000 });
            await f2.waitForTimeout(500);
            const fk2 = await manager(f2);
            await (await nodeAnchor(f2, fk2, other.id)).dblclick();
            await p.waitForTimeout(1500);
            check('окно выбора родителя: двойной щелчок не уводит со страницы с формой', p.url() === formUrl, p.url());
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
    } finally {
        db('remove');
    }

    await browser.close();
    console.log(`== grids failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); try { db('remove'); } catch (x) { } process.exit(1); });
