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
            }
            check('журнал действий, фильтр по дате: без ошибок JS и 404', !lErrors.list().length, lErrors.list().join(' | '));
            await lp.close();
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
    } finally {
        db('remove');
    }

    await browser.close();
    console.log(`== grids failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); try { db('remove'); } catch (x) { } process.exit(1); });
