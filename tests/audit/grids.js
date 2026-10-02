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
        const t = await p.evaluate((payload) => {
            if (!window.TreeView) return { error: 'no TreeView' };
            // a stand-in for the tree: the node only binds its listeners
            const tree = { nodeToggleListener() {}, nodeSelectListener() {}, options: { dblClick() {} } };
            const node = new TreeView.Node({ id: 'claude', name: payload, data: { segment: 'claude', icon: '' } }, tree);
            const a = node.element.getElement('a');
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
            }
            check('журнал действий, фильтр по дате: без ошибок JS и 404', !lErrors.list().length, lErrors.list().join(' | '));
            await lp.close();
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
        }
        check('панель страницы, «Настройки сайта»: без ошибок JS и 404', !spErrors.list().length, spErrors.list().join(' | '));
        await sp.close();
    } finally {
        db('remove');
    }

    await browser.close();
    console.log(`== grids failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); try { db('remove'); } catch (x) { } process.exit(1); });
