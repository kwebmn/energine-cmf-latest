// Browser test: escaping of HTML in the admin grids (stage 5a). Markup that a visitor could send
// (feedback, registration) or an editor could write (a file title, a page name) is shown as text in the
// grids — feedback, users, file repository — and in the page tree, and nothing of it is parsed or run.
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
// known and documented (as in crawl.js): the missing icon sprites of the old theme
const IGNORE = [/images\/main\/icons\.png/, /images\/webworks\/icons\.png/];
function watch(page) {
    const raw = [];
    page.on('console', (m) => { if (m.type() === 'error') raw.push('console: ' + m.text()); });
    page.on('pageerror', (e) => raw.push('pageerror: ' + e.message));
    page.on('response', (r) => { if (r.status() >= 400) raw.push(`http ${r.status()}: ${r.url()}`); });
    return {
        list() {
            let e = [...new Set(raw)].filter((x) => !IGNORE.some((re) => re.test(x)));
            if (!e.some((x) => /^http 404: /.test(x))) e = e.filter((x) => x !== 'console: Failed to load resource: the server responded with a status of 404 ()');
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
            { label: 'обратная связь', url: 'admin/feedback-editor/' },
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

        // the view form of a feedback message (the grid's «Просмотр»): the visitor's fields are read-only there,
        // their values — text too
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/feedback-editor/single/feedbackList/' + ids.feed + '/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(500);
            const r = await p.evaluate(() => {
                const shown = [...document.querySelectorAll('.control, .read')].map((x) => {
                    const input = x.matches('input') ? x : x.querySelector('input[type="text"]');
                    return (input ? input.value : '') + x.textContent;
                });
                return {
                    fields: document.querySelectorAll('.field').length,
                    literal: shown.filter((s) => s.includes('<img src="x"')).length,
                    parsedImg: !!document.querySelector('img[src="x"]'),
                    parsedB: [...document.querySelectorAll('b')].some((b) => b.textContent === 'claude-grid'),
                    ran: window.claudeXss || 0,
                };
            });
            check('обратная связь, просмотр: поля обращения — текстом (автор, тема, сообщение)', r.fields > 0 && r.literal >= 3, JSON.stringify(r));
            check('обратная связь, просмотр: разметка не разобрана и не исполнена', !r.parsedImg && !r.parsedB && !r.ran, JSON.stringify(r));
            check('обратная связь, просмотр: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
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
    } finally {
        db('remove');
    }

    await browser.close();
    console.log(`== grids failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); try { db('remove'); } catch (x) { } process.exit(1); });
