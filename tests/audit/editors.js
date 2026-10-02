// Browser test of the rich editors and the upload (stage 4): Jodit in the page (division) form and in
// page edit mode, the «image from the repository» button, the file upload in the repository form via fetch.
// The form's Validator: an error on a tab that is not open opens that tab.
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

    // 1. page (division) form: Jodit on the description field, what is typed (a link too) is saved; the
    //    fields nobody touched (name, titles, other language) are saved exactly as they were
    const pageId = db('page-id').trim();
    const pageSnap = db('page-snap', pageId);
    const descr = '#smap_description_rtf_1';
    try {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
        if (check('форма раздела: у поля описания редактор Jodit', await isJodit(p, descr))) {
            await appendHtml(p, descr, ' <a href="https://example.org/claude-test">claude-test-editor</a>');
            const [resp] = await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                p.click('li.save_btn'),
            ]);
            const saved = String(JSON.parse(db('page-get', pageId)));
            check('раздел сохранён с описанием и ссылкой из редактора', resp.ok() && saved.includes('claude-test-editor')
                && saved.includes('href="https://example.org/claude-test"'), saved.slice(-200));
            const was = JSON.parse(pageSnap), now = JSON.parse(db('page-snap', pageId));
            const changed = was.flatMap((r, i) => Object.keys(r)
                .filter((f) => !(r.lang_id == 1 && f === 'smap_description_rtf') && r[f] !== now[i][f]).map((f) => `lang ${r.lang_id} ${f}`));
            check('поля, которых не касались, сохранены как были', !changed.length, changed.join(', '));
        }
        check('форма раздела: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    } finally {
        db('page-restore', pageId, pageSnap);
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
            await p.goto(BASE + 'features/content/', { waitUntil: 'networkidle' });
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
        await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
        // the description editor sits on the language tab: open it first, as a person would, and mark the editor
        const tab = await p.evaluate(() => {
            const ed = window.Jodit && Object.values(window.Jodit.instances).find((e) => e.element.id === 'smap_description_rtf_1');
            if (!ed) return null;
            ed.container.setAttribute('data-test-editor', 'page-description');
            for (let el = ed.container; el; el = el.parentElement) {
                if (el.id && document.querySelector('a[href="#' + el.id + '"]')) return '#' + el.id;
            }
            return '';
        });
        if (tab) await p.click(`a[href="${tab}"]`);
        const btn = p.locator('[data-test-editor="page-description"] .jodit-toolbar-button_energineImage button').first();
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
            await p.goto(BASE + 'features/content/', { waitUntil: 'networkidle' });
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
        const snap = db('page-snap', pageId);
        try {
            db('page-rtf', pageId, JSON.stringify(FIXTURE));
            const p = await ctx.newPage();
            await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
            await p.waitForTimeout(1500);
            const name = 'input[name="share_sitemap_translation[1][smap_name]"]';
            await showTabOf(p, name);
            await p.fill(name, (await p.inputValue(name)) + ' claude');
            await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                p.click('li.save_btn'),
            ]);
            const now = JSON.parse(db('page-snap', pageId));
            const changed = now.filter((r) => r.smap_description_rtf !== FIXTURE).map((r) => `lang ${r.lang_id}: ${r.smap_description_rtf}`);
            check('форма: правка названия не переписывает разметку описания', !changed.length, changed.join(' | '));
            await p.close();
        } finally {
            db('page-restore', pageId, snap);
        }
    }

    // 9. what the repository buttons insert: the dialogs (ModalBox) are replaced by fixed answers, the
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
        await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
        await showTabOf(p, descr);
        await appendHtml(p, descr, ' claude-sel');
        await insertions(p, descr, 'форма');
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

    // 10. a block the server did not save is not taken for saved: the administrator is told, the block is
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
            await p.goto(BASE + 'features/content/', { waitUntil: 'networkidle' });
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

    // 11. the code field of a mail template is a plain monospace textarea (no code editor): it is visible on its
    //     tab, and the form saved without edits keeps the template exactly as it was
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        const was = db('mail-snap', '1');
        await p.goto(BASE + 'admin/mail-templates/single/mailTemplateEditor/1/edit/', { waitUntil: 'networkidle' });
        const code = '#template_body_rtf_1';
        await showTabOf(p, code);
        // редактор кода прятал бы само поле и показывал свою разметку: видимое textarea — значит, его нет
        const f = await p.evaluate((sel) => {
            const t = document.querySelector(sel);
            return { tag: t && t.tagName, cls: t && t.className, visible: !!t && t.checkVisibility(),
                font: t && getComputedStyle(t).fontFamily };
        }, code);
        check('шаблон письма: поле кода — обычное видимое textarea моноширинным шрифтом',
            f.tag === 'TEXTAREA' && /\bcode\b/.test(f.cls) && f.visible && /mono/i.test(f.font), JSON.stringify(f));
        const [resp] = await Promise.all([
            p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
            p.click('li.save_btn'),
        ]);
        check('шаблон письма сохранён без правки — как был', resp.ok() && db('mail-snap', '1') === was);
        check('шаблон письма: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
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
        // the second tab (the small picture) is closed until an image is uploaded (TabPane.disableTab, enableTab)
        const tabs = () => p.evaluate(() => [...document.querySelectorAll('ul.e-tabs li')].map((li) => {
            const href = li.querySelector('a').getAttribute('href');
            const pane = document.getElementById(href.slice(href.lastIndexOf('#') + 1));
            return { current: li.classList.contains('current'), disabled: li.classList.contains('disabled'), shown: !!pane && pane.checkVisibility() };
        }));
        await p.click('ul.e-tabs li:nth-child(2)');
        await p.waitForTimeout(200);
        let t = await tabs();
        check('форма файла: вкладка «Маленькое изображение» до загрузки выключена и не открывается',
            t.length === 2 && t[1].disabled && !t[1].current && !t[1].shown && t[0].current && t[0].shown, JSON.stringify(t));
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
            t = await tabs();
            check('форма файла: после загрузки картинки вкладка «Маленькое изображение» включена', !t[1].disabled, JSON.stringify(t));
            await p.click('ul.e-tabs li:nth-child(2)');
            await p.waitForTimeout(200);
            t = await tabs();
            check('форма файла: включённая вкладка открывается, прежняя прячется', t[1].current && t[1].shown && !t[0].current && !t[0].shown,
                JSON.stringify(t));
            await p.click('ul.e-tabs li:nth-child(1)');
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
            // a refusal whose reason holds "<" and "&": shown as it is, nothing of it parsed
            await p.unroute('**/upload-temp/**');
            await p.route('**/upload-temp/**', (route) => route.fulfill({ status: 200, contentType: 'application/json',
                body: JSON.stringify({ result: false, error: true, error_message: 'claude <b>1</b> & 2' }) }));
            const third = path.join(dir, 'claude-test-3.png');
            fs.copyFileSync(path.join(__dirname, '..', 'claude-test.png'), third);
            await Promise.all([
                p.waitForResponse((r) => r.url().includes('upload-temp'), { timeout: 20000 }),
                p.setInputFiles('#uploader', third),
            ]);
            await p.waitForTimeout(500);
            st = await state();
            check('причина отказа с «<» и «&» — как есть, текстом', st.error === 'claude <b>1</b> & 2' && st.markup === 0,
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

    // 13. a required field left empty on a tab that is not open: the form is not sent, its tab opens, the field shows
    //     the error (Validator with the form's tabs); the template stays as it was
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        const was = db('mail-snap', '1');
        const saves = [];
        p.on('request', (r) => { if (/\/save\/?(\?|$)/.test(r.url()) && r.method() === 'POST') saves.push(r.url()); });
        await p.goto(BASE + 'admin/mail-templates/single/mailTemplateEditor/1/edit/', { waitUntil: 'networkidle' });
        await showTabOf(p, '#template_name_1');
        await p.evaluate(() => { document.getElementById('template_name_2').value = ''; });
        const hidden = await p.evaluate(() => !document.getElementById('template_name_2').checkVisibility());
        await p.click('li.save_btn');
        await p.waitForTimeout(1000);
        const f = await p.evaluate(() => {
            const field = document.getElementById('template_name_2');
            const box = field.closest('.field');
            return { invalid: field.classList.contains('invalid'), visible: field.checkVisibility(),
                error: !!(box && box.querySelector('div.error')) };
        });
        check('форма с вкладками: пустое обязательное поле на другой вкладке — форма не ушла, вкладка открыта, ошибка у поля',
            hidden && !saves.length && f.invalid && f.visible && f.error, JSON.stringify({ hidden, ...f, saves }));
        check('форма с вкладками: шаблон не изменился', db('mail-snap', '1') === was);
        check('форма с вкладками: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    }


    // 14. tabs of a form (TabPane): a click on a tab shows its pane, hides the previous one, marks the tab current and
    //     puts the focus into the pane's first text field
    {
        const p = await ctx.newPage();
        const errors = watch(p);
        await p.goto(BASE + 'admin/mail-templates/single/mailTemplateEditor/1/edit/', { waitUntil: 'networkidle' });
        const tabsState = () => p.evaluate(() => [...document.querySelectorAll('ul.e-tabs li')].map((li) => {
            const href = li.querySelector('a').getAttribute('href');
            const pane = document.getElementById(href.slice(href.lastIndexOf('#') + 1));
            return { current: li.classList.contains('current'), shown: !!pane && pane.checkVisibility(),
                focus: !!pane && pane.contains(document.activeElement) };
        }));
        // the tab of the second language's name field
        const idx = await p.evaluate(() => {
            const pane = document.getElementById('template_name_2').closest('.e-pane-item');
            return [...document.querySelectorAll('ul.e-tabs li')].findIndex((li) => li.querySelector('a').getAttribute('href').endsWith('#' + pane.id));
        });
        const before = await tabsState();
        const was = before.findIndex((t) => t.current);
        await p.click(`ul.e-tabs li:nth-child(${idx + 1})`);
        await p.waitForTimeout(300);
        const after = await tabsState();
        check('вкладки формы: щелчок показывает панель вкладки, прячет прежнюю, отмечает вкладку и ставит фокус в первое поле',
            idx > 0 && idx !== was && after[idx].current && after[idx].shown && after[idx].focus && !after[was].current && !after[was].shown,
            JSON.stringify({ idx, was, before, after }));
        check('вкладки формы: без ошибок JS и 404', !errors.length, errors.join(' | '));
        await p.close();
    }

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

    // 17–24. forms and the editor without MooTools (stage 8, step 5): the form windows and the edit mode load no
    //        MooTools; what the forms do stays as it was
    const ids = JSON.parse(db('ids'));
    const formData = JSON.parse(db('form-add'));
    const PAYLOAD = '<img src="data:," onerror="window.claudeXss=(window.claudeXss||0)+1"><b>claude-form</b>';
    const SITE_PATH = new URL(BASE).pathname;
    const waitFrame = async (page, re) => {
        for (let i = 0; i < 50; i++) {
            const f = page.frames().find((fr) => re.test(fr.url()));
            if (f) {
                await f.waitForLoadState('networkidle').catch(() => null);
                return f;
            }
            await page.waitForTimeout(200);
        }
        return null;
    };
    const openImageWindow = async (page) => {
        await page.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
        await page.evaluate(() => ModalBox.open({
            url: document.querySelector('[single_template]').getAttribute('single_template') + 'imagemanager',
            extraData: { upl_path: 'uploads/public/13662314846.png', upl_width: 90, upl_height: 68, upl_title: 'claude' },
        }));
        return waitFrame(page, /imagemanager/);
    };
    try {
        // 17. no MooTools: the forms (user, page, role, file), the image window, the edit mode; Jodit styles — once
        const mooFree = async (label, open) => {
            const p = await ctx.newPage();
            const errors = watch(p);
            // requests of the checked document only: the sidebar of the edit mode (DivSidebar) keeps MooTools till step 7
            const requests = [];
            p.on('request', (r) => { if (/mootools/i.test(r.url())) requests.push(r); });
            const target = await open(p);
            const frame = target && (target.mainFrame ? target.mainFrame() : target);
            const asked = requests.filter((r) => r.frame() === frame).map((r) => r.url());
            const state = target ? await target.evaluate(() => ({
                moo: typeof window.MooTools, jodit: document.querySelectorAll('link[href*="jodit.min.css"]').length,
            })) : { moo: 'no window' };
            check(`без MooTools: ${label}`, state.moo === 'undefined' && !asked.length, JSON.stringify({ state, asked }));
            check(`без MooTools: ${label} — без ошибок JS и 404`, !errors.length, errors.join(' | '));
            await p.close();
            return state;
        };
        await mooFree('форма пользователя', async (p) => {
            await p.goto(BASE + `admin/users/single/userEditor/${formData.user}/edit/`, { waitUntil: 'networkidle' });
            return p;
        });
        const divState = await mooFree('форма раздела', async (p) => {
            await p.goto(BASE + `admin/structure/single/divEditor/${pageId}/edit/`, { waitUntil: 'networkidle' });
            return p;
        });
        check('форма раздела: стили Jodit подключены один раз', divState.jodit === 1, JSON.stringify(divState));
        await mooFree('форма роли', async (p) => {
            await p.goto(BASE + `admin/users/roles/single/roleEditor/${ids.role}/edit/`, { waitUntil: 'networkidle' });
            return p;
        });
        await mooFree('форма файла', async (p) => {
            await p.goto(BASE + 'admin/users/single/adminPanel/file-library/1/add/', { waitUntil: 'networkidle' });
            return p;
        });
        await mooFree('окно картинки', openImageWindow);
        await mooFree('режим правки', async (p) => {
            await p.goto(BASE, { waitUntil: 'networkidle' });
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            return p;
        });

        // 18. the user form (Form): Enter in a text field does not send the form; the avatar field — a file chosen in
        //     the library fills the path, the preview and «очистить», «очистить» clears them; the quick upload finds
        //     the uploaded file by its id and fills the field the same way. The windows answer at once.
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const posts = [];
            p.on('request', (r) => { if (r.method() === 'POST') posts.push(r.url()); });
            await p.goto(BASE + `admin/users/single/userEditor/${formData.user}/edit/`, { waitUntil: 'networkidle' });
            const url = p.url();
            await showTabOf(p, '#u_fullname');
            await p.focus('#u_fullname');
            await p.keyboard.press('Enter');
            await p.waitForTimeout(700);
            check('форма пользователя: Enter в текстовом поле форму не отправляет', p.url() === url && !posts.length, posts.join(' '));

            const MEDIA = await p.evaluate(() => Energine.media);
            await p.evaluate(() => {
                window.claudeOpened = [];
                ModalBox.open = function (o) {
                    window.claudeOpened.push({ url: o.url, extra: o.extraData });
                    setTimeout(() => o.onClose(window.claudeAnswer), 0);
                };
            });
            const fileState = () => p.evaluate(() => {
                const btn = document.querySelector('button[onclick*="openFileLib"]');
                const input = document.getElementById(btn.getAttribute('link'));
                const preview = document.getElementById(btn.getAttribute('preview'));
                const clear = input.closest('.with_append').querySelector('.lnk_clear');
                return { value: input.value, href: preview.getAttribute('href'), src: preview.querySelector('img').getAttribute('src'),
                    shown: getComputedStyle(preview).display !== 'none', clear: !!clear && getComputedStyle(clear).display !== 'none' };
            });
            await showTabOf(p, 'button[onclick*="openFileLib"]');
            await p.evaluate((path) => { window.claudeAnswer = { upl_path: path, upl_internal_type: 'image' }; }, formData.path);
            await p.click('button[onclick*="openFileLib"]');
            await p.waitForTimeout(300);
            let st = await fileState();
            const opened = await p.evaluate(() => window.claudeOpened.slice());
            check('поле файла: «…» открывает библиотеку файлов', opened.length === 1 && /\/file-library\/$/.test(opened[0].url),
                JSON.stringify(opened));
            check('поле файла: выбранный файл — путь, превью и ссылка на файл', st.value === formData.path
                && st.src === MEDIA + formData.path && st.href === MEDIA + formData.path && st.shown, JSON.stringify(st));
            check('поле файла: после выбора видна ссылка «очистить»', st.clear, JSON.stringify(st));
            await p.evaluate(() => document.querySelector('button[onclick*="openFileLib"]').closest('.with_append')
                .querySelector('.lnk_clear').click());
            st = await fileState();
            check('поле файла: «очистить» убирает путь, превью и саму ссылку', st.value === '' && st.href === null && !st.shown
                && !st.clear, JSON.stringify(st));

            await p.evaluate((id) => { window.claudeOpened = []; window.claudeAnswer = { result: true, data: id }; }, formData.upload);
            const [resp] = await Promise.all([
                p.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 15000 }),
                p.click('button[onclick*="openQuickUpload"]'),
            ]);
            await p.waitForTimeout(1200);
            st = await fileState();
            const quick = await p.evaluate(() => window.claudeOpened.slice());
            const overlays = await p.evaluate(() => document.querySelectorAll('.e-overlay').length);
            check('быстрая загрузка: окно добавления файла в папку быстрой загрузки', quick.length === 1
                && quick[0].url.endsWith(`/file-library/${formData.pid}/add`), JSON.stringify(quick));
            check('быстрая загрузка: файл найден по id и подставлен — путь и превью, затемнение снято', resp.ok()
                && st.value === formData.path && st.src === MEDIA + formData.path && st.shown && !overlays,
                JSON.stringify({ st, overlays, body: resp.request().postData() }));
            check('форма пользователя: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();   // the form is not saved: the temporary user is removed at the end
        }

        // 19. saving from a grid (Form.processServerResponse): «after saving» — «edit next»: the window closes, the
        //     choice is remembered in a cookie for a day with the site path, the grid opens the next template; the
        //     template saved without edits is unchanged
        {
            const was = db('mail-all');
            await ctx.clearCookies({ name: 'after_add_default_action' });
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/mail-templates/', { waitUntil: 'networkidle' });
            await p.waitForSelector('tbody tr td', { timeout: 10000 });
            await p.locator('tbody tr').filter({ has: p.locator('td') }).first().click();
            await p.click('ul.toolbar li.edit_btn');
            const frameEl = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const first = await frameEl.evaluate((f) => f.src);
            const frame = await frameEl.contentFrame();
            await frame.waitForSelector('li.save_btn', { timeout: 10000 });
            await frame.selectOption('li.select select', 'editNext');
            await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                frame.click('li.save_btn'),
            ]);
            await p.waitForFunction((url) => [...document.querySelectorAll('.e-modalbox iframe')]
                .some((f) => f.src !== url && /\/edit\/?$/.test(f.src)), first, { timeout: 15000 }).catch(() => null);
            const next = await p.evaluate(() => [...document.querySelectorAll('.e-modalbox iframe')].map((f) => f.src));
            const cookie = (await ctx.cookies(BASE)).find((c) => c.name === 'after_add_default_action');
            const days = cookie ? (cookie.expires - Date.now() / 1000) / 86400 : 0;
            check('сохранение из грида: «Править следующий» — окно закрыто, открыт следующий шаблон', next.length === 1
                && next[0] !== first && /\/edit\/?$/.test(next[0]), JSON.stringify({ first, next }));
            check('сохранение из грида: выбор запомнен в cookie на сутки с путём сайта', !!cookie && cookie.value === 'editNext'
                && cookie.path === SITE_PATH && days > 0.9 && days < 1.1, JSON.stringify(cookie));
            check('сохранение из грида: шаблон без правки не изменился', db('mail-all') === was);
            check('сохранение из грида: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();
            await ctx.clearCookies({ name: 'after_add_default_action' });
        }

        // 20. the page (division) form (DivForm): a text field folds and unfolds; a content template with its own
        //     segment and layout sets them and clears the page XML; the parent chosen in the tree window goes to the
        //     field, its name — as text; an empty name on a language tab stops the saving; a changed template resets
        {
            const xmlSnap = db('page-xml-snap', pageId);
            db('page-xml-set', pageId);
            try {
                const p = await ctx.newPage();
                const errors = watch(p);
                const posts = [];
                p.on('request', (r) => { if (r.method() === 'POST') posts.push(r.url()); });
                const formUrl = BASE + `admin/structure/single/divEditor/${pageId}/edit/`;
                await p.goto(formUrl, { waitUntil: 'networkidle' });

                const field = '#smap_meta_keywords_1';
                await showTabOf(p, field);
                const fold = () => p.evaluate((s) => document.querySelector(s).closest('.field').className, field);
                const clickIcon = () => p.evaluate((s) => document.querySelector(s).closest('.field').querySelector('.icon_min_max').click(), field);
                if (/\bmax\b/.test(await fold())) await clickIcon();
                const f0 = await fold();
                await p.click(field);
                const f1 = await fold();
                await clickIcon();
                const f2 = await fold();
                check('текстовое поле формы: свёрнуто, щелчок по нему разворачивает, значок — сворачивает',
                    /\bmin\b/.test(f0) && /\bmax\b/.test(f1) && /\bmin\b/.test(f2), [f0, f1, f2].join(' | '));

                await showTabOf(p, '#smap_content');
                const tpl = await p.evaluate(() => {
                    const select = document.getElementById('smap_content');
                    const option = [...select.options].find((o) => o.value && !o.disabled && !o.selected);
                    const layout = [...document.getElementById('smap_layout').options].find((o) => !o.selected).value;
                    option.setAttribute('data-segment', 'claude-seg');
                    option.setAttribute('data-layout', layout);
                    select.value = option.value;
                    select.dispatchEvent(new Event('change'));
                    const seg = document.getElementById('smap_segment'), code = document.querySelector('textarea.code');
                    return { ro: seg.readOnly, seg: seg.value, layout: document.getElementById('smap_layout').value === layout,
                        code: code ? code.value : null, hidden: code ? code.closest('div.field').classList.contains('hidden') : null };
                });
                check('шаблон раздела со своим сегментом и макетом: сегмент закреплён, макет выбран, XML раздела очищен и скрыт',
                    tpl.ro && tpl.seg === 'claude-seg' && tpl.layout && tpl.code === '' && tpl.hidden === true, JSON.stringify(tpl));
                const free = await p.evaluate(() => {
                    const select = document.getElementById('smap_content');
                    const option = [...select.options].find((o) => o.value && !o.disabled && !o.selected && !o.dataset.segment);
                    select.value = option.value;
                    select.dispatchEvent(new Event('change'));
                    return document.getElementById('smap_segment').readOnly;
                });
                check('шаблон без своего сегмента: сегмент снова свободен', free === false, String(free));

                const parent = await p.evaluate((payload) => {
                    const opened = [];
                    const open = ModalBox.open;
                    ModalBox.open = function (o) {
                        opened.push(o.url);
                        setTimeout(() => o.onClose({ smap_id: 4242, smap_name: payload, smap_segment: 'claude-parent' }), 0);
                    };
                    document.getElementById('sitemap_selector').click();
                    return new Promise((resolve) => setTimeout(() => {
                        ModalBox.open = open;
                        const b = document.getElementById('sitemap_selector');
                        const span = document.getElementById(b.getAttribute('span_field'));
                        resolve({ opened, id: document.getElementById(b.getAttribute('hidden_field')).value, text: span.textContent,
                            img: !!span.querySelector('img'), segment: (document.getElementById('smap_pid_segment') || {}).textContent,
                            ran: window.claudeXss || 0 });
                    }, 300));
                }, PAYLOAD);
                check('родитель раздела: «…» открывает окно дерева', parent.opened.length === 1 && /\/list\/$/.test(parent.opened[0]),
                    JSON.stringify(parent.opened));
                check('родитель раздела: выбранный раздел — в поле, его сегмент — в адресе', parent.id === '4242'
                    && parent.segment === 'claude-parent', JSON.stringify(parent));
                check('родитель раздела: имя с разметкой — текстом', parent.text === PAYLOAD && !parent.img && !parent.ran,
                    JSON.stringify(parent));

                const dialogs = [];
                p.on('dialog', (d) => { dialogs.push(d.message()); d.accept(); });
                await p.evaluate(() => { document.querySelector('input[name="share_sitemap_translation[1][smap_name]"]').value = ''; });
                const before = posts.length;
                await p.click('li.save_btn');
                await p.waitForTimeout(800);
                const noName = await p.evaluate(() => Energine.translations.get('ERR_NO_DIV_NAME'));
                check('форма раздела: пустое имя на вкладке языка — предупреждение, без сохранения', dialogs.length === 1
                    && dialogs[0] === noName && !posts.slice(before).length, JSON.stringify({ dialogs, noName, posts: posts.slice(before) }));

                await p.goto(formUrl, { waitUntil: 'networkidle' });
                await showTabOf(p, '#smap_content');
                const marked = await p.evaluate(() => { const s = document.getElementById('smap_content'); return s.options[s.selectedIndex].text; });
                const [rr] = await Promise.all([
                    p.waitForResponse((r) => r.url().includes('reset-templates'), { timeout: 15000 }),
                    p.click('button[onclick*="resetPageContentTemplate"]'),
                ]);
                await p.waitForTimeout(300);
                const reset = await p.evaluate(() => {
                    const s = document.getElementById('smap_content'), code = document.querySelector('textarea.code');
                    return { text: s.options[s.selectedIndex].text, code: code ? code.value : null,
                        hidden: code ? code.closest('div.field').classList.contains('hidden') : null };
                });
                const xml = JSON.parse(db('page-xml-snap', pageId));
                check('сброс изменённого шаблона: пометка снята, XML раздела очищен и скрыт, на сервере пусто', rr.ok()
                    && marked.includes(' - ') && !reset.text.includes(' - ') && reset.text.trim().length > 0 && reset.code === ''
                    && reset.hidden === true && !xml.smap_content_xml, JSON.stringify({ marked, reset, xml }));
                check('форма раздела (DivForm): без ошибок JS и 404', !errors.length, errors.join(' | '));
                await p.close();
            } finally {
                db('page-xml-restore', pageId, xmlSnap);
            }
        }

        // 21. the role form (GroupForm): the switch in the «all pages» row checks its whole column of rights
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/users/roles/single/roleEditor/${ids.role}/edit/`, { waitUntil: 'networkidle' });
            await showTabOf(p, '.groupRadio');
            await p.locator('.groupRadio').nth(1).click();
            const col = await p.evaluate(() => {
                const group = document.querySelectorAll('.groupRadio')[1];
                const cls = group.closest('td').className, body = group.closest('tbody');
                const radios = [...body.querySelectorAll('td.' + cls + ' input[type=radio]')].filter((r) => !r.classList.contains('groupRadio'));
                const others = [...body.querySelectorAll('input[type=radio][name^="div_right"]')].filter((r) => r.closest('td').className !== cls);
                return { cls, n: radios.length, all: radios.every((r) => r.checked), otherChecked: others.filter((r) => r.checked).length };
            });
            check('форма роли: «Все разделы» отмечает весь свой столбец', col.n > 0 && col.all && col.otherChecked === 0, JSON.stringify(col));
            check('форма роли: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();   // not saved
        }

        // 22. the image window (ImageManager): the width changes the height in proportion, the path goes through the
        //     resizer and the preview follows
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const frame = await openImageWindow(p);
            if (check('окно картинки открыто', !!frame)) {
                await frame.fill('#width', '45');
                await frame.dispatchEvent('#width', 'change');
                const im = await frame.evaluate(() => ({ w: document.getElementById('width').value, h: document.getElementById('height').value,
                    file: document.getElementById('filename').value, thumb: document.getElementById('thumbnail').getAttribute('src'),
                    resizer: Energine.resizer }));
                check('окно картинки: ширина меняет высоту по пропорции, путь — через resizer, превью следом', im.w === '45'
                    && im.h === '34' && im.file === im.resizer + 'w45-h34/uploads/public/13662314846.png' && im.thumb === im.file,
                    JSON.stringify(im));
            }
            check('окно картинки: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();
        }

        // 23. a form tab with its own page (site settings → additional parameters): an iframe on the first show, once
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/settings/single/settings/${ids.site}/edit/`, { waitUntil: 'networkidle' });
            const tab = p.locator('li[data-src] a').first();
            await tab.click();
            await p.waitForTimeout(800);
            await p.locator('li:not([data-src]) > a[href^="#"]').first().click();
            await tab.click();
            await p.waitForTimeout(500);
            const fr = await p.evaluate(() => {
                const li = document.querySelector('li[data-src]'), frames = li.pane ? li.pane.querySelectorAll('iframe') : [];
                return { n: frames.length, src: frames.length ? frames[0].getAttribute('src') : null, ds: li.getAttribute('data-src') };
            });
            check('вкладка формы со своей страницей: iframe при первом показе, один', fr.n === 1 && !!fr.src && fr.src.endsWith(fr.ds),
                JSON.stringify(fr));
            check('вкладка формы со своей страницей: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();
        }

        // 24. the form fields as a query string (Form.toQueryString; before — the toQueryString of MooTools): named
        //     fields, not the disabled, submit, reset, file, image ones; checked boxes only; every selected option;
        //     a new line stays \n
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/users/single/userEditor/${formData.user}/edit/`, { waitUntil: 'networkidle' });
            const qs = await p.evaluate(() => {
                const fx = document.createElement('form');
                fx.innerHTML = '<input name="a[b]" value="x &amp; y+z %"><textarea name="t">1\n2</textarea>'
                    + '<input type="checkbox" name="c1" value="on1" checked><input type="checkbox" name="c2" value="on2">'
                    + '<input type="radio" name="r" value="r1"><input type="radio" name="r" value="r2" checked>'
                    + '<select name="m" multiple><option value="m1" selected>1</option><option value="m2">2</option><option selected>m3</option></select>'
                    + '<select name="s"><option value="">-</option><option value="s2" selected>2</option></select>'
                    + '<input name="d" value="no" disabled><input type="submit" name="sb" value="no"><input type="reset" name="rs" value="no">'
                    + '<input type="file" name="f"><input type="image" name="im"><input type="button" name="bt" value="btn">'
                    + '<input value="noname"><input type="hidden" name="h" value="Привет">';
                document.body.appendChild(fx);
                const result = (window.Form && Form.toQueryString) ? Form.toQueryString(fx) : fx.toQueryString();
                fx.remove();
                return result;
            });
            const expected = 'a%5Bb%5D=x%20%26%20y%2Bz%20%25&t=1%0A2&c1=on1&r=r2&m=m1&m=m3&s=s2&bt=btn'
                + '&h=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82';
            check('поля формы строкой запроса — как прежде', qs === expected, qs);
            check('строка запроса формы: без ошибок JS и 404', !errors.length, errors.join(' | '));
            await p.close();
        }
    } finally {
        db('form-remove');
    }

    // 25. the folders for moving a file (FileRepository::getDirs) — a JSON list with the repositories, also without
    //     any folder (here: the editors test makes none)
    {
        const p = await ctx.newPage();
        await p.goto(BASE + 'admin/users/single/adminPanel/file-library/', { waitUntil: 'networkidle' });
        const r = await p.evaluate(() => Energine.send(
            document.querySelector('[single_template]').getAttribute('single_template') + '/getDirs/', 'languageID=1'));
        check('папки для переноса: getDirs отвечает списком хранилищ', r.status === 200 && !!r.json && Array.isArray(r.json.data)
            && r.json.data.some((d) => d.upl_internal_type === 'repo'), JSON.stringify({ status: r.status, text: (r.text || '').slice(0, 200) }));
        await p.close();
    }

    await browser.close();
    console.log(`== editors failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); process.exit(1); });
