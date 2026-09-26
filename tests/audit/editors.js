// Browser test of the rich editors and the upload (stage 4): Jodit in the news form and in page edit
// mode, the «image from the repository» button, the file upload in the repository form via fetch.
// Everything the test changes is restored (texts through editors-db.php, the temporary upload file).
// Run in a subshell, like crawl.js:
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node editors.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD || !process.env.WEB) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const db = (...args) => execFileSync('php8.5', [path.join(__dirname, 'editors-db.php'), ...args], { encoding: 'utf8' });
let fail = 0;
function check(label, cond, detail = '') {
    console.log((cond ? 'OK   ' : 'FAIL ') + label + (cond ? '' : ': ' + String(detail).replace(/\s+/g, ' ').slice(0, 300)));
    if (!cond) fail++;
    return cond;
}
// JS errors and 400+ responses of a page
function watch(page) {
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
    page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
    page.on('response', (r) => { if (r.status() >= 400) errors.push(`http ${r.status()}: ${r.url()}`); });
    return errors;
}
// is the element (a textarea or an edit block) handled by a Jodit instance
const isJodit = (page, selector) => page.evaluate((sel) => {
    const el = document.querySelector(sel);
    return !!(el && window.Jodit && Object.values(window.Jodit.instances).some((e) => e.element === el));
}, selector);
// append HTML at the end of the editor bound to the element, the way a caret at the end would
const appendHtml = (page, selector, html) => page.evaluate(([sel, h]) => {
    const ed = Object.values(window.Jodit.instances).find((e) => e.element === document.querySelector(sel));
    ed.s.focus();
    ed.s.setCursorIn(ed.editor, false);
    ed.s.insertHTML(h);
}, [selector, html]);

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    const ctx = await browser.newContext({ locale: 'ru-RU' });
    const lp = await ctx.newPage();
    await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
    await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
    await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
    await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
    await lp.close();

    // 1. news form: Jodit on the text field, what is typed (a link too) is saved
    const newsId = db('news-id').trim();
    const newsOrig = db('news-get', newsId);
    try {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + `admin/news-editor/single/newsRepo/${newsId}/edit/`, { waitUntil: 'networkidle' });
        if (check('форма новости: у поля текста редактор Jodit', await isJodit(p, '#news_text_rtf_1'))) {
            await appendHtml(p, '#news_text_rtf_1', ' <a href="https://example.org/claude-test">claude-test-editor</a>');
            const [resp] = await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                p.click('li.save_btn'),
            ]);
            const saved = JSON.parse(db('news-get', newsId));
            check('новость сохранена с текстом и ссылкой из редактора', resp.ok() && saved.includes('claude-test-editor')
                && saved.includes('href="https://example.org/claude-test"'), saved.slice(-200));
        }
        check('форма новости: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    } finally {
        db('news-set', newsId, newsOrig);
    }

    // 2. page edit mode: the home text block is an inline Jodit, saved on leaving the block and the page
    const tbId = db('tb-home').trim();
    const tbOrig = db('tb-get', tbId);
    const block = '.nrgnEditor[num="1"]';
    try {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE, { waitUntil: 'networkidle' });
        await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
        if (check('главная в режиме правки: текстовый блок — редактор Jodit', await isJodit(p, block))) {
            await appendHtml(p, block, ' claude-test-inline');
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('save-text'), { timeout: 15000 }),
                p.mouse.click(2, 2),
            ]);
            check('блок сохранён при уходе из него', JSON.parse(db('tb-get', tbId)).includes('claude-test-inline'));
            await appendHtml(p, block, ' claude-test-leave');
            await p.goto(BASE + 'news/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(1500);
            check('несохранённое уходит на сервер при уходе со страницы', JSON.parse(db('tb-get', tbId)).includes('claude-test-leave'));
        }
        check('режим правки: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    } finally {
        db('tb-set', tbId, tbOrig);
    }

    // 3. «image from the repository» opens the file library
    {
        const p = await ctx.newPage();
        await p.goto(BASE + `admin/news-editor/single/newsRepo/${newsId}/edit/`, { waitUntil: 'networkidle' });
        // the text editor sits on the language tab: open it first, as a person would, and mark the editor
        const tab = await p.evaluate(() => {
            const ed = window.Jodit && Object.values(window.Jodit.instances).find((e) => e.element.id === 'news_text_rtf_1');
            if (!ed) return null;
            ed.container.setAttribute('data-test-editor', 'news-text');
            for (let el = ed.container; el; el = el.parentElement) {
                if (el.id && document.querySelector('a[href="#' + el.id + '"]')) return '#' + el.id;
            }
            return '';
        });
        if (tab) await p.click(`a[href="${tab}"]`);
        const btn = p.locator('[data-test-editor="news-text"] .jodit-toolbar-button_energineImage button').first();
        if (check('кнопка «Картинка из репозитория» есть', await btn.count() > 0)) {
            await btn.click();
            await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const src = await p.evaluate(() => { const f = document.querySelector('.e-modalbox iframe'); return f ? f.src : ''; });
            check('кнопка открывает библиотеку файлов', src.includes('file-library'), src);
        }
        await p.close();
    }

    // 4. repository file form: the file goes to upload-temp through fetch, preview and name are filled
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'admin/users/single/adminPanel/file-library/1/add/', { waitUntil: 'networkidle' });
        const [resp] = await Promise.all([
            p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 20000 }),
            p.setInputFiles('#uploader', path.join(__dirname, '..', 'claude-test.png')),
        ]);
        check('загрузка идёт через fetch', resp.request().resourceType() === 'fetch', resp.request().resourceType());
        const j = await resp.json().catch(() => null);
        if (check('сервер принял файл', j && !j.error && j.tmp_name, JSON.stringify(j))) {
            await p.waitForTimeout(500);
            const preview = await p.getAttribute('#preview', 'src');
            check('превью показывает загруженный файл', preview && preview.includes(j.tmp_name), preview);
            check('имя файла подставлено', (await p.inputValue('#upl_name')) === 'claude-test.png', await p.inputValue('#upl_name'));
            const tmp = path.join(process.env.WEB, j.tmp_name);
            if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
        }
        check('форма файла: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    }

    await browser.close();
    console.log(`== editors failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); process.exit(1); });
