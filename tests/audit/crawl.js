// Headless Chrome crawl of the site from env.php: JS errors, failed requests, uncaught exceptions per page.
// Run in a subshell after: envsh=$(php8.5 ../env.php --shell) && eval "$envsh"  (BASE, ADMIN_EMAIL, ADMIN_PASSWORD; PLAYWRIGHT = path to the module)
// Only GET navigation and the read-only grid data requests the pages make themselves; no form is submitted except the login.
// Usage: node crawl.js <guest-paths> <admin-paths> <grid-singles> <out.json>
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) { console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first'); process.exit(2); }
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const [, , guestFile, adminFile, singlesFile, outFile] = process.argv;
const lines = (f) => fs.readFileSync(f, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
// главная обходится всегда: в списках путей её нет (пустые строки отбрасываются)
const withHome = (list) => ['', ...list];
// гриды без состояния add: журнал действий только читает, а «Настройки сайта» правят единственную запись сайта
const NO_ADD = [/actionsList\/$/, /single\/settings\/$/];
// гриды без обычной формы правки
const NO_EDIT = [/actionsList\/$/];

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    const results = [];

    async function visit(context, label, url, waitMs = 700) {
        const page = await context.newPage();
        const errors = [];
        page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
        page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
        page.on('response', (r) => { if (r.status() >= 400) errors.push(`http ${r.status()}: ${r.url()}`); });
        page.on('requestfailed', (r) => errors.push(`failed: ${r.url()} ${r.failure() ? r.failure().errorText : ''}`));
        // этап 8: MooTools не запрашивается ни одним окном страницы и нигде не определена
        page.on('request', (r) => { if (/mootools|moocompat/i.test(r.url())) errors.push('mootools: ' + r.url()); });
        let status = 0;
        try {
            const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
            status = resp ? resp.status() : 0;
            await page.waitForTimeout(waitMs);
            for (const frame of page.frames()) {
                if (await frame.evaluate(() => typeof window.MooTools !== 'undefined').catch(() => false)) {
                    errors.push('mootools: defined in ' + frame.url());
                }
            }
        } catch (e) {
            errors.push('goto: ' + e.message.split('\n')[0]);
        }
        // исключений нет (этап 5в): спрайт старой темы и внешние заглушки картинок убраны, любая 404 — ошибка
        const unique = [...new Set(errors)];
        results.push({ label, url: url.replace(BASE, '/'), status, errors: unique });
        await page.close();
        process.stdout.write(unique.length ? 'E' : '.');
    }

    // ---- guest
    const guest = await browser.newContext({ locale: 'ru-RU' });
    for (const p of withHome(lines(guestFile))) {
        await visit(guest, 'guest', BASE + p);
        if (!p.startsWith('http')) await visit(guest, 'guest-ua', BASE + 'ua/' + p);
    }

    // ---- admin
    const admin = await browser.newContext({ locale: 'ru-RU' });
    const lp = await admin.newPage();
    await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
    await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
    await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
    await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
    const cookies = await admin.cookies();
    if (!cookies.some((c) => c.name === 'NRGNSID')) { console.error('login failed'); }
    await lp.close();

    for (const p of withHome(lines(adminFile))) await visit(admin, 'admin', BASE + p, 1500);

    // forms of every grid: add and edit of the first record (the modal content pages);
    // the grid data is a POST, it carries the page token (Csrf) like the admin's own requests
    const home = await (await admin.request.get(BASE)).text();
    const token = (home.match(/<meta name="csrf-token" content="([0-9a-f]*)"/) || [])[1] || '';
    for (const path of lines(singlesFile)) {
        const single = path.startsWith('http') ? path : BASE + path;
        const isDiv = /[dD]ivEditor\/$/.test(single);
        if (isDiv) continue;   // structure editors need a parent id, covered by the smoke tests
        if (!NO_ADD.some((re) => re.test(single))) await visit(admin, 'admin-form-add', single + 'add/', 1500);
        if (NO_EDIT.some((re) => re.test(single))) continue;
        try {
            const r = await admin.request.post(single + 'get-data/page-1', { headers: { 'X-Request': 'JSON', 'X-CSRF-Token': token } });
            const j = await r.json();
            const pk = j.meta ? Object.keys(j.meta).find((k) => j.meta[k].key) : null;
            const row = (j.data || [])[0];
            if (pk && row && row[pk] !== undefined) await visit(admin, 'admin-form-edit', single + row[pk] + '/edit/', 1500);
            // a grid that answers without data would silently drop its edit form from the crawl
            else results.push({ label: 'admin-form-edit', url: single.replace(BASE, '/'), status: r.status(),
                errors: ['get-data: no record (' + JSON.stringify(j).slice(0, 200) + ')'] });
        } catch (e) {
            results.push({ label: 'admin-form-edit', url: single.replace(BASE, '/'), status: 0, errors: ['get-data: ' + e.message.split('\n')[0]] });
        }
    }

    await browser.close();
    fs.writeFileSync(outFile, JSON.stringify(results, null, 1));
    console.log(`\npages: ${results.length}, with errors: ${results.filter((r) => r.errors.length).length}`);
})();
