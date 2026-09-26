// Headless Chrome crawl of the site from env.php: JS errors, failed requests, uncaught exceptions per page.
// Run after: eval "$(php8.5 ../env.php --shell)"  (BASE, ADMIN_EMAIL, ADMIN_PASSWORD; PLAYWRIGHT = path to the module)
// Only GET navigation and the read-only grid data requests the pages make themselves; no form is submitted except the login.
// Usage: node crawl.js <guest-paths> <admin-paths> <grid-singles> <out.json>
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) { console.error('run eval "$(php8.5 ../env.php --shell)" first'); process.exit(2); }
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const [, , guestFile, adminFile, singlesFile, outFile] = process.argv;
const lines = (f) => fs.readFileSync(f, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
// known and documented: missing icon sprite, placeholder images of an external service
const IGNORE = [/images\/main\/icons\.png/, /images\/webworks\/icons\.png/, /placehold\.it/];
// гриды без состояния add: журнал действий, обратная связь и комментарии только читают,
// а разделы новостей создаёт редактор структуры
const NO_ADD = [/actionsList\/$/, /feedbackList\/$/, /commentsEdit\/$/, /newsCategoriesEditor\/$/];
// гриды без обычной формы правки: у комментариев она открывается с номером вкладки
const NO_EDIT = [/actionsList\/$/, /feedbackList\/$/, /commentsEdit\/$/];

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
        let status = 0;
        try {
            const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
            status = resp ? resp.status() : 0;
            await page.waitForTimeout(waitMs);
        } catch (e) {
            errors.push('goto: ' + e.message.split('\n')[0]);
        }
        let unique = [...new Set(errors)].filter((e) => !IGNORE.some((re) => re.test(e)));
        // Chrome logs a 404 without its URL; drop it when the only 404 responses are the ignored ones
        if (!unique.some((e) => /^http 404: /.test(e))) unique = unique.filter((e) => e !== 'console: Failed to load resource: the server responded with a status of 404 ()');
        results.push({ label, url: url.replace(BASE, '/'), status, errors: unique });
        await page.close();
        process.stdout.write(unique.length ? 'E' : '.');
    }

    // ---- guest
    const guest = await browser.newContext({ locale: 'ru-RU' });
    for (const p of lines(guestFile)) {
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

    for (const p of lines(adminFile)) await visit(admin, 'admin', BASE + p, 1500);

    // forms of every grid: add and edit of the first record (the modal content pages)
    for (const path of lines(singlesFile)) {
        const single = path.startsWith('http') ? path : BASE + path;
        const isDiv = /[dD]ivEditor\/$/.test(single);
        if (isDiv) continue;   // structure editors need a parent id, covered by the smoke tests
        if (!NO_ADD.some((re) => re.test(single))) await visit(admin, 'admin-form-add', single + 'add/', 1500);
        if (NO_EDIT.some((re) => re.test(single))) continue;
        try {
            const r = await admin.request.post(single + 'get-data/page-1', { headers: { 'X-Request': 'JSON' } });
            const j = await r.json();
            const pk = j.meta ? Object.keys(j.meta).find((k) => j.meta[k].key) : null;
            const row = (j.data || [])[0];
            if (pk && row && row[pk] !== undefined) await visit(admin, 'admin-form-edit', single + row[pk] + '/edit/', 1500);
        } catch (e) {
            results.push({ label: 'admin-form-edit', url: single.replace(BASE, '/'), status: 0, errors: ['get-data: ' + e.message.split('\n')[0]] });
        }
    }

    await browser.close();
    fs.writeFileSync(outFile, JSON.stringify(results, null, 1));
    console.log(`\npages: ${results.length}, with errors: ${results.filter((r) => r.errors.length).length}`);
})();
