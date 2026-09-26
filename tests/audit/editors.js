// Browser test of the rich editors and the upload (stage 4): Jodit in the news form and in page edit
// mode, the «image from the repository» button, the file upload in the repository form via fetch.
// Everything the test changes is restored (texts through editors-db.php, the temporary upload file).
// Run in a subshell, like crawl.js:
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node editors.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
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
// JS errors and 400+ responses of a page; the list is filtered when read (errors())
function watch(page) {
    const raw = [];
    page.on('console', (m) => { if (m.type() === 'error') raw.push('console: ' + m.text()); });
    page.on('pageerror', (e) => raw.push('pageerror: ' + e.message));
    page.on('response', (r) => { if (r.status() >= 400) raw.push(`http ${r.status()}: ${r.url()}`); });
    return {
        get length() { return this.list().length; },
        join(sep) { return this.list().join(sep); },
        list() {
            // исключений нет (этап 5в): спрайт старой темы убран, любая 404 — ошибка
            const e = [...new Set(raw)];
            return e;
        },
    };
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

// open the form tab (language or properties pane) that holds the element, as a person would
const showTabOf = (page, selector) => page.evaluate((sel) => {
    for (let el = document.querySelector(sel); el; el = el.parentElement) {
        const a = el.id && document.querySelector('a[href="#' + el.id + '"]');
        if (a) { a.click(); return true; }
    }
    return false;
}, selector);

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    const ctx = await browser.newContext({ locale: 'ru-RU' });
    const lp = await ctx.newPage();
    await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
    await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
    await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
    await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
    await lp.close();

    // 1. news form: Jodit on the text field, what is typed (a link too) is saved; the fields nobody
    //    touched (announce, other language) are saved exactly as they were
    const newsId = db('news-id').trim();
    const newsSnap = db('news-snap', newsId);
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
            const was = JSON.parse(newsSnap), now = JSON.parse(db('news-snap', newsId));
            const changed = was.flatMap((r, i) => ['news_title', 'news_announce_rtf', 'news_text_rtf']
                .filter((f) => !(r.lang_id == 1 && f === 'news_text_rtf') && r[f] !== now[i][f]).map((f) => `lang ${r.lang_id} ${f}`));
            check('поля, которых не касались, сохранены как были', !changed.length, changed.join(', '));
        }
        check('форма новости: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    } finally {
        db('news-restore', newsId, newsSnap);
    }

    // 2. page edit mode: the home text block is an inline Jodit, saved on leaving the block and the page
    const tbId = db('tb-home').trim();
    const tbSnap = db('tb-snap', tbId);
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
        db('tb-restore', tbId, tbSnap);
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

    // 5. a file the server refuses (.php) is reported in the form, not swallowed
    {
        const p = await ctx.newPage();
        await p.goto(BASE + 'admin/users/single/adminPanel/file-library/1/add/', { waitUntil: 'networkidle' });
        const probe = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'editors-')), 'claude-probe.php');
        fs.writeFileSync(probe, "<?php echo 'executed';");
        const [resp] = await Promise.all([
            p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 20000 }),
            p.setInputFiles('#uploader', probe),
        ]);
        fs.rmSync(path.dirname(probe), { recursive: true, force: true });
        const j = await resp.json().catch(() => null);
        check('сервер отверг .php', j && j.error, JSON.stringify(j));
        await p.waitForTimeout(500);
        const shown = await p.evaluate(() => {
            const f = document.getElementById('uploader'), err = document.querySelector('div.error');
            return !!(f && f.classList.contains('invalid') && err && err.textContent.trim());
        });
        check('отказ сервера показан в форме', shown);
        await p.close();
    }

    // 6-8. existing markup is not rewritten by the editors: an embedded map (iframe), a script, an empty
    //      icon element, <b>, a target=_blank link and text outside a paragraph. Nothing is saved without
    //      an edit, and an edit keeps the rest of the markup as it was.
    const FIXTURE = 'Текст без абзаца claude-fixture<iframe src="/robots.txt" width="40" height="30"></iframe>'
        + '<p><i class="fa fa-phone"></i> <b>жирный</b> <a href="https://example.org/" target="_blank">ссылка</a></p>'
        + '<script>window.claudeFixture = 1;</script>';
    const keeps = (html) => ['Текст без абзаца claude-fixture<iframe', '<iframe src="/robots.txt"', '<i class="fa fa-phone"></i>',
        '<b>жирный</b>', '<a href="https://example.org/" target="_blank">ссылка</a>', '<script>window.claudeFixture = 1;</script>']
        .filter((part) => !String(html).includes(part));
    {
        const snap = db('tb-snap', tbId);
        try {
            db('tb-set', tbId, JSON.stringify(FIXTURE));
            const p = await ctx.newPage();
            const saves = [];
            p.on('request', (r) => { if (r.url().includes('save-text')) saves.push(r.method() + ' ' + r.url()); });
            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            await p.waitForTimeout(1500);
            await p.click(block);
            await p.mouse.click(2, 2);
            await p.waitForTimeout(500);
            await p.goto(BASE + 'news/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(1000);
            check('режим правки: без правки блок не сохраняется', !saves.length, saves.join(' '));
            const now = JSON.parse(db('tb-get', tbId));
            check('режим правки: разметка блока без правки не тронута', now === FIXTURE, now);

            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            await p.waitForTimeout(1500);
            await appendHtml(p, block, ' claude-test-keep');
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('save-text'), { timeout: 15000 }),
                p.mouse.click(2, 2),
            ]);
            const edited = JSON.parse(db('tb-get', tbId));
            const lost = keeps(edited);
            check('режим правки: после правки остальная разметка на месте', edited.includes('claude-test-keep') && !lost.length,
                'нет: ' + lost.join(' | ') + ' — ' + edited);
            await p.close();
        } finally {
            db('tb-restore', tbId, snap);
        }
    }
    {
        const snap = db('news-snap', newsId);
        try {
            db('news-rtf', newsId, JSON.stringify(FIXTURE));
            const p = await ctx.newPage();
            await p.goto(BASE + `admin/news-editor/single/newsRepo/${newsId}/edit/`, { waitUntil: 'networkidle' });
            await p.waitForTimeout(1500);
            const title = 'input[name="apps_news_translation[1][news_title]"]';
            await showTabOf(p, title);
            await p.fill(title, (await p.inputValue(title)) + ' claude');
            await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                p.click('li.save_btn'),
            ]);
            const now = JSON.parse(db('news-snap', newsId));
            const changed = now.flatMap((r) => ['news_announce_rtf', 'news_text_rtf'].filter((f) => r[f] !== FIXTURE)
                .map((f) => `lang ${r.lang_id} ${f}: ${r[f]}`));
            check('форма: правка заголовка не переписывает разметку текста и анонса', !changed.length, changed.join(' | '));
            await p.close();
        } finally {
            db('news-restore', newsId, snap);
        }
    }

    // 9. the news title on its page is plain text: edited without the rich editor, saved without markup,
    //    shown as typed (a "<" or "&" in a title is text, not markup)
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'news/', { waitUntil: 'networkidle' });
        const href = await p.evaluate(() => {
            const a = [...document.querySelectorAll('a[href]')].find((x) => /\/\d+--[^/]+\/$/.test(x.getAttribute('href')));
            return a ? a.href : null;
        });
        const id = href && href.match(/\/(\d+)--/)[1];
        if (check('в ленте есть ссылка на новость', !!id, href)) {
            const snap = db('news-snap', id);
            const title = 'h1.feed_name';
            try {
                await p.goto(href, { waitUntil: 'networkidle' });
                await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
                const mode = await p.evaluate((sel) => {
                    const el = document.querySelector(sel);
                    return el ? el.getAttribute('contenteditable') : null;
                }, title);
                check('заголовок новости правится как простой текст', !(await isJodit(p, title)) && mode === 'plaintext-only', mode);
                const before = await p.evaluate((sel) => document.querySelector(sel).textContent.trim(), title);
                await p.click(title);
                await p.keyboard.press('End');
                await p.keyboard.type(' claude <тест> & co');
                await Promise.all([
                    p.waitForResponse((r) => r.url().includes('save-text'), { timeout: 15000 }),
                    p.mouse.click(2, 2),
                ]);
                const saved = JSON.parse(db('news-snap', id)).find((r) => r.lang_id == 1).news_title;
                check('заголовок сохранён простым текстом', saved === before + ' claude <тест> & co', saved);
                await p.goto(href, { waitUntil: 'networkidle' });
                const shown = await p.evaluate((sel) => document.querySelector(sel).textContent.trim(), title);
                check('заголовок показан как введён', shown === before + ' claude <тест> & co', shown);
                check('правка заголовка: без ошибок JS и 404', !errors.length, errors.join(' | '));
            } finally {
                db('news-restore', id, snap);
            }
        }
        await p.close();
    }

    // 10. what the repository buttons insert: the dialogs (ModalBox) are replaced by fixed answers, the
    //     inserted markup is read from the editor — image with escaped alt and margins, file link with and
    //     without a selection, nothing after a cancelled dialog; in a form and in a page block
    const stubDialogs = (page) => page.evaluate(() => {
        window.claudeAnswers = {};
        ModalBox.open = function (o) {
            const key = /imagemanager/.test(o.url) ? 'image' : 'library';
            setTimeout(() => o.onClose(window.claudeAnswers[key]), 0);
        };
    });
    const answer = (page, library, image) => page.evaluate(([l, i]) => { window.claudeAnswers = { library: l, image: i }; }, [library, image]);
    const editorValue = (page, sel) => page.evaluate((s) => Object.values(Jodit.instances).find((e) => e.element === document.querySelector(s)).value, sel);
    // caret at the end of the editor, or a selection of the given text
    const place = (page, sel, text) => page.evaluate(([s, t]) => {
        const ed = Object.values(Jodit.instances).find((e) => e.element === document.querySelector(s));
        ed.s.focus();
        if (!t) { ed.s.setCursorIn(ed.editor, false); return; }
        const walker = document.createTreeWalker(ed.editor, NodeFilter.SHOW_TEXT);
        for (let n = walker.nextNode(); n; n = walker.nextNode()) {
            const at = n.nodeValue.indexOf(t);
            if (at >= 0) { const r = document.createRange(); r.setStart(n, at); r.setEnd(n, at + t.length); ed.s.selectRange(r); return; }
        }
    }, [sel, text]);
    const pressButton = (page, sel, name) => page.evaluate(([s, n]) => {
        const ed = Object.values(Jodit.instances).find((e) => e.element === document.querySelector(s));
        ed.container.querySelector('.jodit-toolbar-button_' + n + ' button').dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }, [sel, name]);
    const LIB_IMAGE = { upl_path: 'uploads/public/13662314846.png', upl_title: '13662314846.png' };
    const IMAGE = { filename: 'uploads/public/13662314846.png', width: 40, height: 30, align: 'left', alt: 'claude "alt" <x>',
        'margin-left': 5, 'margin-top': '0' };
    const IMG = `<img src="${BASE}uploads/public/13662314846.png" width="40" height="30" align="left" alt="claude &quot;alt&quot; &lt;x&gt;" style="margin-left:5px;">`;
    const LIB_FILE = { upl_path: 'uploads/public/claude.pdf', upl_title: 'Прайс & условия' };
    const insertions = async (p, sel, where) => {
        await stubDialogs(p);
        await answer(p, LIB_IMAGE, IMAGE);
        await place(p, sel);
        await pressButton(p, sel, 'energineImage');
        await p.waitForTimeout(300);
        let v = await editorValue(p, sel);
        check(`${where}: картинка из репозитория вставлена с размерами, alt и отступами`, v.includes(IMG), v.slice(-400));

        await answer(p, LIB_FILE, null);
        await place(p, sel);
        await pressButton(p, sel, 'energineFile');
        await p.waitForTimeout(300);
        v = await editorValue(p, sel);
        check(`${where}: файл без выделения — ссылка с названием файла`,
            v.includes(`<a href="${BASE}uploads/public/claude.pdf">Прайс &amp; условия</a>`), v.slice(-400));

        await place(p, sel, 'claude-sel');
        await pressButton(p, sel, 'energineFile');
        await p.waitForTimeout(300);
        v = await editorValue(p, sel);
        check(`${where}: файл с выделением — ссылкой становится выделенный текст`,
            v.includes(`<a href="${BASE}uploads/public/claude.pdf">claude-sel</a>`), v.slice(-400));

        await answer(p, null, null);
        const before = await editorValue(p, sel);
        await place(p, sel);
        await pressButton(p, sel, 'energineImage');
        await pressButton(p, sel, 'energineFile');
        await p.waitForTimeout(300);
        check(`${where}: отменённый диалог ничего не вставляет`, (await editorValue(p, sel)) === before);
    };
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + `admin/news-editor/single/newsRepo/${newsId}/edit/`, { waitUntil: 'networkidle' });
        await showTabOf(p, '#news_text_rtf_1');
        await appendHtml(p, '#news_text_rtf_1', ' claude-sel');
        await insertions(p, '#news_text_rtf_1', 'форма');
        check('вставка в форме: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();   // the form is not saved: nothing to restore
    }
    {
        const snap = db('tb-snap', tbId);
        try {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            await appendHtml(p, block, ' claude-sel');
            await insertions(p, block, 'блок на странице');
            check('вставка в блок: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();
        } finally {
            db('tb-restore', tbId, snap);
        }
    }

    // 11. a block the server did not save is not taken for saved: the administrator is told, the block is
    //     marked and stays unsaved (the beacon brings it when the page is left); a refusal changes nothing
    {
        const snap = db('tb-snap', tbId);
        try {
            const p = await ctx.newPage();
            const dialogs = [];
            p.on('dialog', (d) => { dialogs.push(d.message()); d.accept(); });
            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            // an answer that is not a saved text: a page (so the server answers when rights or the session are gone)
            await p.route('**/save-text*', (route) => route.fulfill({ status: 200, contentType: 'text/html; charset=utf-8',
                body: '<!DOCTYPE html><html><body>page</body></html>' }));
            await appendHtml(p, block, ' claude-test-unsaved');
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('save-text'), { timeout: 15000 }),
                p.mouse.click(2, 2),
            ]);
            await p.waitForTimeout(300);
            const marked = await p.evaluate((sel) => document.querySelector(sel).classList.contains('nrgnEditorError'), block);
            check('несохранённый блок: администратор предупреждён', dialogs.length === 1, JSON.stringify(dialogs));
            check('несохранённый блок помечен', marked);
            check('несохранённое не записано', !JSON.parse(db('tb-get', tbId)).includes('claude-test-unsaved'));
            await p.unroute('**/save-text*');
            await p.goto(BASE + 'news/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(1500);
            check('несохранённое уходит маяком при уходе со страницы', JSON.parse(db('tb-get', tbId)).includes('claude-test-unsaved'));

            // a real refusal: a token that is not the visitor's
            dialogs.length = 0;
            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            await p.evaluate(() => { Energine.csrf = '0'.repeat(64); });
            const was = JSON.parse(db('tb-get', tbId));
            await appendHtml(p, block, ' claude-test-refused');
            const [resp] = await Promise.all([
                p.waitForResponse((r) => r.url().includes('save-text'), { timeout: 15000 }),
                p.mouse.click(2, 2),
            ]);
            await p.waitForTimeout(300);
            check(`отказ сервера (HTTP ${resp.status()}) показан текстом отказа`, dialogs.length === 1 && dialogs[0].includes('Форма устарела'),
                JSON.stringify(dialogs));
            check('отказ сервера ничего не записал', JSON.parse(db('tb-get', tbId)) === was);
            await p.close();
        } finally {
            db('tb-restore', tbId, snap);
        }
    }

    // 12. an upload that did not happen is reported as text with its reason, and the form forgets the file:
    //     a file over the server limit, an answer that is not JSON (a proxy's 413 page), a failure after a success
    {
        const p = await ctx.newPage();
        await p.goto(BASE + 'admin/users/single/adminPanel/file-library/1/add/', { waitUntil: 'networkidle' });
        const state = () => p.evaluate(() => {
            const err = document.querySelector('div.error');
            return { error: err ? err.textContent.trim() : '', markup: err ? err.children.length : 0,
                preview: document.getElementById('preview').getAttribute('src') || '', data: document.getElementById('data').value };
        });
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'editors-'));
        try {
            const big = path.join(dir, 'claude-big.bin');
            fs.writeFileSync(big, '');
            fs.truncateSync(big, 101 * 1024 * 1024);
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 120000 }),
                p.setInputFiles('#uploader', big),
            ]);
            await p.waitForTimeout(500);
            let st = await state();
            check('файл больше допустимого — понятная причина', /100/.test(st.error) && /МБ/.test(st.error), JSON.stringify(st));
            check('после отказа превью не «загружается», путь пуст', !/loading\.gif/.test(st.preview) && st.data === '', JSON.stringify(st));

            // a successful upload, then an answer that is not JSON
            const [ok] = await Promise.all([
                p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 20000 }),
                p.setInputFiles('#uploader', path.join(__dirname, '..', 'claude-test.png')),
            ]);
            const j = await ok.json().catch(() => null);
            await p.waitForTimeout(500);
            await p.route('**/upload-temp/**', (route) => route.fulfill({ status: 413, contentType: 'text/html',
                body: '<html><body><h1>413 Request Entity Too Large</h1></body></html>' }));
            // another file: the same one again would not change the input, and the browser sends nothing
            const other = path.join(dir, 'claude-test-2.png');
            fs.copyFileSync(path.join(__dirname, '..', 'claude-test.png'), other);
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 20000 }),
                p.setInputFiles('#uploader', other),
            ]);
            await p.waitForTimeout(500);
            st = await state();
            check('ответ не JSON — сообщение с кодом ответа, текстом', /413/.test(st.error) && st.markup === 0 && !/<h1>/.test(st.error),
                JSON.stringify(st));
            check('неудачная загрузка после удачной не оставляет прежний файл', st.data === '' && !/loading\.gif/.test(st.preview),
                JSON.stringify(st));
            if (j && j.tmp_name) {
                const tmp = path.join(process.env.WEB, j.tmp_name);
                if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
            }
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
        await p.close();
    }

    await browser.close();
    console.log(`== editors failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); process.exit(1); });
