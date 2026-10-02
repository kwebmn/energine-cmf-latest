# Этап 8, шаг 5 — формы админки и визуальный редактор без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Form`, `DivForm`, `GroupForm`, `FileRepoForm`, `ImageManager`, `EnergineEditor`, `PageEditor` — на чистом
JavaScript; окна форм и режим правки работают без MooTools.

**Architecture:** классы JavaScript с прежним интерфейсом (`var Form = class Form …`, наследники `extends Form`,
`Form.Label` подмешивается в `DivForm` через `Object.assign`). Cookie — помощники `Energine.readCookie/writeCookie`
(на них переходит и `PageToolbar`). Поля формы сериализуются `Form.toQueryString(form)` — точная копия
`toQueryString` MooTools. Мёртвый блок MooTools во встроенном скрипте панели (`toolbar.xslt`) уходит.

**Tech Stack:** PHP 8.5 / XSLT, браузерный JavaScript (ES2020, классические скрипты, `ScriptLoader.load`), Jodit,
Playwright-аудиты (`tests/audit/*.js`), `tests/no-traces.sh`.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step5-forms-editor-design.md`

## Global Constraints

- Клон `/var/www/clients/client1/web97/private/stage8/energine`, ветка `main`; стенд —
  `STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start`, команды — `bash tests/tools/stand.sh run …`.
- Коммиты — `bash tests/tools/stand.sh run git commit -q -m "…" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`;
  после git-операций от root — `chown -R web97:client1 /var/www/clients/client1/web97/private/stage8/energine`.
- В файлах из `VANILLA_JS` нет кода MooTools и по шаблону `MOOTOOLS_CODE` (`tests/no-traces.sh`) — и в комментариях:
  `$(`, `.each(`, `.getElement(`, `.addEvent(`, `.addClass(`, `.pass(`, `Request.JSON`, `new Element(`, `typeOf(` и т. п.
- В комментариях не писать вызов загрузчика скриптов с именем в кавычках: `setup scriptMap` берёт первый такой вызов
  в файле.
- Классы — `var Имя = class Имя …` (классические скрипты делят одну глобальную область: никаких `const`/`let` на
  верхнем уровне файла).
- База не меняется; адрес new.energine.org нигде не упоминается; пароли и содержимое `configs/system.config.*.php` не
  выводятся.
- Выкладка — без отдельного согласования (владелец: «продолжай без остановки»), с точкой отката; при провале
  проверки на площадке — откат и отчёт.

## Review Focus

1. Строка запроса формы — поля с `[]` в имени, юникод, `&`, `+`, `%`, перевод строки в `textarea`, невыбранные
   флажки, список с несколькими вариантами, выключенные поля: сервер должен получить ровно то же, что от MooTools
   (иначе сохранение исказит данные). Проверка — блок 24 (`Form.toQueryString` против прежнего результата).
2. Сайт не в корне домена (`Energine.base` с путём): cookie «после сохранения» должна получать путь сайта, а не `/`.
   Проверка на стенде невозможна (сайт в корне) — ревью `Energine.sitePath()`.
3. Ответ окна гриду на MooTools: `ModalBox.setReturnValue(ответ)` из формы без MooTools, грид читает `afterClose` —
   блок 19.
4. Быстрая загрузка при ответе не из двух строк (файл не найден, отказ, сеть): затемнение должно сниматься.
5. Окна форм в окнах (форма → библиотека файлов → форма файла): стили Jodit и форм подключаются один раз в каждом
   документе, Esc окно не закрывает (шаг 2).

---

## Task 1: Проверки

**Files:**
- Modify: `tests/audit/editors-db.php` (команды `form-add`, `form-remove`, `page-xml-snap`, `page-xml-set`,
  `page-xml-restore`, `mail-all`, `ids`)
- Modify: `tests/audit/editors.js` (блоки 17–24 перед `await browser.close();`)

**Interfaces:**
- Produces: проверки, по которым идут задачи 2–3; красные до переделки — шесть «без MooTools: …», «поле файла: после
  выбора видна ссылка «очистить»», «родитель раздела: имя с разметкой — текстом».

- [ ] **Step 1: Помощник базы.** В `tests/audit/editors-db.php` в шапку (после строки `mail-snap`) добавить:

```php
//   php8.5 editors-db.php mail-all              — все шаблоны писем с переводами, JSON
//   php8.5 editors-db.php ids                   — id первой роли и первого сайта, JSON
//   php8.5 editors-db.php form-add              — временный пользователь и файл в папке быстрой загрузки, JSON
//   php8.5 editors-db.php form-remove           — убрать записи и файл проверок форм
//   php8.5 editors-db.php page-xml-snap ID      — XML раздела (содержимое и макет), JSON
//   php8.5 editors-db.php page-xml-set ID       — XML содержимого раздела — копия его шаблона (раздел «изменён»)
//   php8.5 editors-db.php page-xml-restore ID JSON — вернуть XML раздела из page-xml-snap
```

после `require …testlib.php';` — константу:

```php
const FORM_FILE = 'uploads/public/claude-form-file.png';
```

и перед `default:` — команды:

```php
    case 'mail-all':
        echo json_encode(['templates' => q('SELECT * FROM mail_templates ORDER BY template_id')->fetchAll(),
            'translations' => q('SELECT * FROM mail_templates_translation ORDER BY template_id, lang_id')->fetchAll()],
            JSON_UNESCAPED_UNICODE);
        break;
    case 'ids':
        echo json_encode(['role' => (int)scalar('SELECT MIN(group_id) FROM user_groups'),
            'site' => (int)scalar('SELECT MIN(site_id) FROM share_sites')]);
        break;
    case 'form-add':
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            ['claude-form-' . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), 'Claude Form']);
        $user = pdo()->lastInsertId();
        // файл в папке быстрой загрузки: копия картинки демо-загрузок
        $pid = scalar("SELECT upl_id FROM share_uploads WHERE upl_path = 'uploads/public' LIMIT 1");
        copy(WEB . '/uploads/public/13662314846.png', WEB . '/' . FORM_FILE);
        chown(WEB . '/' . FORM_FILE, SITE_USER);
        q("INSERT INTO share_uploads (upl_pid, upl_path, upl_filename, upl_name, upl_title, upl_publication_date, upl_internal_type,
                upl_mime_type, upl_width, upl_height, upl_is_active)
           VALUES (?, ?, 'claude-form-file.png', 'claude-form-file.png', 'claude-form-file', NOW(), 'image', 'image/png', 90, 68, 1)",
            [$pid, FORM_FILE]);
        echo json_encode(['user' => (int)$user, 'upload' => (int)pdo()->lastInsertId(), 'path' => FORM_FILE, 'pid' => (int)$pid]);
        break;
    case 'form-remove':
        q("DELETE FROM user_users WHERE u_name LIKE 'claude-form-%'");
        q("DELETE FROM share_uploads WHERE upl_filename = 'claude-form-file.png'");
        @unlink(WEB . '/' . FORM_FILE);
        break;
    case 'page-xml-snap':
        echo json_encode(q('SELECT smap_content_xml, smap_layout_xml FROM share_sitemap WHERE smap_id = ?', [(int)$argv[2]])->fetch(),
            JSON_UNESCAPED_UNICODE);
        break;
    case 'page-xml-set':
        $content = scalar('SELECT smap_content FROM share_sitemap WHERE smap_id = ?', [(int)$argv[2]]);
        q('UPDATE share_sitemap SET smap_content_xml = ? WHERE smap_id = ?',
            [file_get_contents(WEB . '/templates/content/' . $content), (int)$argv[2]]);
        break;
    case 'page-xml-restore':
        $r = json_decode($argv[3], true);
        q('UPDATE share_sitemap SET smap_content_xml = ?, smap_layout_xml = ? WHERE smap_id = ?',
            [$r['smap_content_xml'], $r['smap_layout_xml'], (int)$argv[2]]);
        break;
```

- [ ] **Step 2: Проверки.** В `tests/audit/editors.js` перед строкой `    await browser.close();` вставить:

Full file `tests/audit/editors-step5-block.js`:
```js
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
            const asked = [];
            p.on('request', (r) => { if (/mootools/i.test(r.url())) asked.push(r.url()); });
            const target = await open(p);
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

```

(Файла `tests/audit/editors-step5-block.js` нет: блок вставляется в `editors.js` как есть.)

- [ ] **Step 3: Прогон до переделки.**

Run: `cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node editors.js' > $W/t1-editors.log 2>&1; grep -E '^FAIL' $W/t1-editors.log`
Expected: ровно восемь FAIL — шесть «без MooTools: …» (форма пользователя, форма раздела, форма роли, форма файла,
окно картинки, режим правки), «поле файла: после выбора видна ссылка «очистить»», «родитель раздела: имя с разметкой
— текстом»; остальные проверки блоков 17–24 — OK; `== editors failures: 8`.

- [ ] **Step 4: Commit**

```bash
git add tests/audit/editors.js tests/audit/editors-db.php
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 5: проверки — формы и окна без MooTools, поле файла, форма раздела, роли, окно картинки" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 2: Cookie в `Energine`, `EnergineEditor`, `PageEditor`

**Files:**
- Modify: `core/modules/share/scripts/Energine.js` (помощники cookie и пути сайта после `Energine.loadCSS`)
- Modify: `core/modules/share/scripts/PageToolbar.js` (`readCookie`/`writeCookie` → `Energine`)
- Modify: `core/modules/share/scripts/EnergineEditor.js`
- Modify: `core/modules/share/scripts/PageEditor.js` (весь файл)
- Modify: `tests/no-traces.sh` (`VANILLA_JS` + `EnergineEditor.js`, `PageEditor.js`)

**Interfaces:**
- Produces: `Energine.readCookie(name) → string|null`, `Energine.writeCookie(name, value, {path, domain, days})`,
  `Energine.sitePath() → string`; `EnergineEditor.make(element, {singlePath, jodit})` — без MooTools.

- [ ] **Step 1: Energine.** В `core/modules/share/scripts/Energine.js` сразу после определения `Energine.loadCSS`:

```js

/**
 * Cookie по имени (значение — через decodeURIComponent, как у Cookie MooTools) или null.
 * @param {string} name
 * @returns {string|null}
 */
Energine.readCookie = function (name) {
    var pair = document.cookie.split(/;\s*/).find(function (item) {
        return item.indexOf(name + '=') === 0;
    });
    return pair ? decodeURIComponent(pair.slice(name.length + 1)) : null;
};

/**
 * Записать cookie (значение — через encodeURIComponent, как у Cookie MooTools).
 * @param {string} name
 * @param {*} value
 * @param {{path: string, domain: string, days: number}} [options] путь (по умолчанию «/»), домен, срок в днях
 */
Energine.writeCookie = function (name, value, options) {
    options = options || {};
    var cookie = name + '=' + encodeURIComponent(value) + '; path=' + (options.path || '/');
    if (options.domain) {
        cookie += '; domain=' + options.domain;
    }
    if (options.days) {
        cookie += '; expires=' + new Date(Date.now() + options.days * 24 * 60 * 60 * 1000).toUTCString();
    }
    document.cookie = cookie;
};

/**
 * Путь сайта — каталог адреса Energine.base («/» или «/папка/»): путь cookie админки.
 * @returns {string}
 */
Energine.sitePath = function () {
    return new URL(Energine.base, document.baseURI).pathname.replace(/[^/]*$/, '');
};
```

- [ ] **Step 2: PageToolbar.** В `core/modules/share/scripts/PageToolbar.js`: `PageToolbar.readCookie('sidebar')` →
  `Energine.readCookie('sidebar')`; вызов записи —

```js
        Energine.writeCookie('sidebar', html.classList.contains('e-has-sideframe') ? 1 : 0,
            {domain: '.' + url.hostname, path: url.pathname.replace(/[^/]*$/, ''), days: 30});
```

  статические `readCookie` и `writeCookie` удалить.

- [ ] **Step 3: EnergineEditor.** В `core/modules/share/scripts/EnergineEditor.js`:
  - в шапке после абзаца описания — строка ` * Чистый JavaScript, без MooTools.`;
  - `ScriptLoader.load('MooCompat', 'jodit/jodit.min', 'ModalBox');` → `ScriptLoader.load('jodit/jodit.min', 'ModalBox');`;
  - удалить свойство `cssLoaded` с его комментарием; в `make` вместо блока `if (!EnergineEditor.cssLoaded) {…}` —
    `Energine.loadCSS('../scripts/jodit/jodit.min.css');` (повторно ссылку не добавляет);
  - `var config = Object.merge({` → `var config = Object.assign({` (настройки `jodit` дополняют верхние ключи);
  - в `insertImage`: `['margin-left', 'margin-right', 'margin-top', 'margin-bottom'].each(function (prop) {` → `.forEach(`.

- [ ] **Step 4: PageEditor.** Заменить `core/modules/share/scripts/PageEditor.js` целиком:

Full file `core/modules/share/scripts/PageEditor.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[PageEditor]{@link PageEditor}</li>
 *     <li>[PageEditor.BlockEditor]{@link PageEditor.BlockEditor}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires EnergineEditor
 * @requires ModalBox
 * @requires Overlay
 *
 * @author Pavel Dubenko
 * @author Andy Karpov
 * @author Valerii Zinchenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('EnergineEditor', 'ModalBox', 'Overlay');

/**
 * Правка текстовых блоков прямо на странице: каждый элемент .nrgnEditor —
 * встроенный (inline) редактор Jodit. Блок сохраняется, когда из него уходят; несохранённое при
 * уходе со страницы отправляется маяком — синхронный запрос при закрытии страницы браузеры не шлют.
 *
 * @constructor
 */
var PageEditor = class PageEditor {
    constructor() {
        /**
         * Class name of the editable blocks.
         * @type {string}
         */
        this.editorClassName = 'nrgnEditor';
        /**
         * Block editors.
         * @type {PageEditor.BlockEditor[]}
         */
        this.editors = [];
        document.querySelectorAll('.' + this.editorClassName).forEach((element) => {
            this.editors.push(new PageEditor.BlockEditor(element));
        });

        window.addEventListener('pagehide', () => {
            this.editors.forEach((editor) => editor.beacon());
        });
    }
};

/**
 * Редактор одного блока.
 *
 * @constructor
 * @param {Element} area Элемент .nrgnEditor с атрибутами single_template, eID, num.
 */
PageEditor.BlockEditor = class PageEditorBlock {
    constructor(area) {
        this.area = area;
        this.singlePath = area.getAttribute('single_template');
        this.ID = area.getAttribute('eID') || '';
        this.num = area.getAttribute('num') || '';

        this.editor = EnergineEditor.make(this.area, {
            singlePath: this.singlePath,
            jodit: {inline: true, toolbarInline: true, toolbarInlineForSelection: false, showPlaceholder: false}
        });
        /**
         * Текст, который уже на сервере.
         * @type {string}
         */
        this.saved = this.editor.value;
        this.editor.events.on('blur', () => this.save());
    }

    /**
     * Есть ли несохранённые изменения.
     * @returns {boolean}
     */
    isDirty() {
        return this.editor.value !== this.saved;
    }

    /**
     * Тело запроса save-text.
     * @returns {URLSearchParams}
     */
    body(value) {
        const data = new URLSearchParams();
        // токен в теле: маяк заголовков не передаёт
        data.append('csrf_token', Energine.csrf || '');
        data.append('data', value);
        if (this.ID) {
            data.append('ID', this.ID);
        }
        if (this.num) {
            data.append('num', this.num);
        }
        return data;
    }

    /**
     * Адрес сохранения: ответ JSON, в том числе при отказе (?json — маяк заголовков не передаёт).
     * @returns {string}
     */
    url() {
        return this.singlePath + 'save-text?json';
    }

    /**
     * Сохранить блок, если он изменился. Сохранённым считается только ответ {result: true}:
     * страница вместо ответа (нет прав, сессия закончилась) и отказ сервера оставляют блок несохранённым.
     */
    save() {
        if (!this.isDirty()) {
            return;
        }
        const value = this.editor.value;
        fetch(this.url(), {method: 'POST', body: this.body(value), credentials: 'same-origin'})
            .then((response) => response.text().then((text) => {
                let result = null;
                try {
                    result = JSON.parse(text);
                } catch (e) {
                }
                if (response.ok && result && result.result) {
                    this.saved = value;
                    this.area.classList.remove('nrgnEditorError');
                } else {
                    this.fail(result, response.status);
                }
            }))
            .catch(() => this.fail(null, 0));
    }

    /**
     * Блок не сохранён: он помечается и остаётся несохранённым (следующий уход из блока или со страницы
     * отправит его снова), администратор узнаёт причину.
     *
     * @param {Object} result ответ сервера, если это JSON
     * @param {number} status код ответа
     */
    fail(result, status) {
        this.area.classList.add('nrgnEditorError');
        alert((result && result.errors && result.errors[0] && result.errors[0].message)
            || ((Energine.translations.get('ERR_TEXT_NOT_SAVED') || 'Error') + (status ? ' (HTTP ' + status + ')' : '')));
    }

    /**
     * При уходе со страницы: несохранённое отправляется маяком.
     */
    beacon() {
        if (this.isDirty()) {
            const value = this.editor.value;
            if (navigator.sendBeacon(this.url(), this.body(value))) {
                this.saved = value;
            }
        }
    }
};
```

- [ ] **Step 5: no-traces.** В `tests/no-traces.sh` в `VANILLA_JS` добавить
  `core/modules/share/scripts/EnergineEditor.js core/modules/share/scripts/PageEditor.js`.

- [ ] **Step 6: Прогон.**

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh mootools; cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node editors.js' > $W/t2-editors.log 2>&1; grep -E '^FAIL|failures' $W/t2-editors.log; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js' > $W/t2-grids.log 2>&1; tail -1 $W/t2-grids.log`
Expected: no-traces — 0; editors — FAIL только у пяти «без MooTools» (форма пользователя, раздела, роли, файла, окно
картинки) и двух исправлений задачи 3 («очистить», «имя с разметкой»); «без MooTools: режим правки» — OK; правка на
странице и вставки (блоки 2, 9) — OK; grids — `== grids failures: 0` (боковая панель и cookie).

- [ ] **Step 7: Commit**

```bash
git add core/modules/share/scripts/Energine.js core/modules/share/scripts/PageToolbar.js core/modules/share/scripts/EnergineEditor.js core/modules/share/scripts/PageEditor.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 5: визуальный редактор и правка на странице на чистом JavaScript, cookie — в Energine" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 3: `Form` с наследниками и встроенный скрипт панели

**Files:**
- Modify (весь файл): `core/modules/share/scripts/Form.js`, `DivForm.js`, `FileRepoForm.js`, `ImageManager.js`,
  `core/modules/user/scripts/GroupForm.js`
- Modify: `core/modules/share/transformers/toolbar.xslt` (встроенный скрипт панели грида и формы)
- Modify: `tests/no-traces.sh` (`VANILLA_JS` + пять файлов)

**Interfaces:**
- Consumes: `Energine.readCookie`, `Energine.writeCookie`, `Energine.sitePath` (задача 2); `TabPane` (`currentTab`,
  `getTabs()`, `enableTab(i)`, `disableTab(i)`, у вкладки — `pane`, `data`), `Validator` (`validate()`,
  `showError(field, text)`, `removeError(field)`), `Overlay` (`show()`, `hide()`), `ModalBox` (`open`, `close`,
  `setReturnValue`, `getExtraData`), `Toolbar` (`getControlById`, `getElement`, `bindTo`).
- Produces: `Form` (интерфейс спецификации 2.1), `Form.toQueryString(form)`, `Form.element(el)`, `Form.Label`,
  `Form.RichEditor`; наследники с прежними методами.

- [ ] **Step 1: Form.** Заменить `core/modules/share/scripts/Form.js` целиком:

Full file `core/modules/share/scripts/Form.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Form]{@link Form}</li>
 *     <li>[Form.Label]{@link Form.Label}</li>
 *     <li>[Form.RichEditor]{@link Form.RichEditor}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires EnergineEditor
 * @requires TabPane
 * @requires Toolbar
 * @requires Validator
 * @requires ModalBox
 * @requires Overlay
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('EnergineEditor', 'TabPane', 'Toolbar', 'Validator', 'ModalBox', 'Overlay');

/**
 * Форма админки: вкладки, проверка полей, визуальные поля, поля файлов. «Сохранить» отправляет поля формы и
 * отдаёт ответ окну, из которого форму открыли.
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id) внутри формы.
 */
var Form = class Form {
    constructor(element) {
        Energine.loadCSS('form.css');

        /**
         * The overlay.
         * @type {Overlay}
         */
        this.overlay = new Overlay();
        /**
         * Attached toolbar.
         * @type {Toolbar}
         */
        this.toolbar = null;
        /**
         * Визуальные поля.
         * @type {Form.RichEditor[]}
         */
        this.richEditors = [];
        this.element = Form.element(element);
        this.singlePath = this.element.getAttribute('single_template');
        this.form = this.element.closest('form');
        this.form.classList.add('form');

        // Enter в текстовом поле не отправляет форму
        if (this.form.querySelector('input[type=text], select, textarea')) {
            this.form.addEventListener('keypress', (event) => {
                if (event.key === 'Enter' && event.target.tagName === 'INPUT' && event.target.type === 'text') {
                    event.preventDefault();
                }
            });
        }

        const action = this.form.querySelector('#componentAction');
        /**
         * State of the form.
         * @type {string}
         */
        this.state = action ? action.value : null;
        this.tabPane = new TabPane(this.element, {onTabChange: () => this.onTabChange()});
        this.validator = new Validator(this.form, this.tabPane);
        this.form.querySelectorAll('textarea.richEditor').forEach((textarea) => {
            this.richEditors.push(new Form.RichEditor(textarea, this));
        });

        // пустое текстовое поле свёрнуто (min): щелчок по полю разворачивает его, щелчок по значку — сворачивает
        const showHide = (event) => {
            event.preventDefault();
            event.stopPropagation();
            const el = event.target,
                field = el.closest('.field');
            if (field) {
                if (field.classList.contains('min')) {
                    field.classList.replace('min', 'max');
                } else if (el.classList.contains('icon_min_max') && field.classList.contains('max')) {
                    field.classList.replace('max', 'min');
                }
            }
        };
        this.form.querySelectorAll('.field .control.toggle, .icon_min_max').forEach((el) => el.addEventListener('click', showHide));

        // поля даты — встроенные поля браузера; обязательное пустое поле сразу получает сегодняшнюю дату (поле
        // даты и времени — и текущее время), как раньше при открытии формы
        this.element.querySelectorAll('input.inp_date, input.inp_datetime').forEach((dateControl) => {
            const field = dateControl.closest('.field');
            if (dateControl.value === '' && field && field.classList.contains('required')) {
                const now = new Date(),
                    pad = (n) => (n < 10 ? '0' : '') + n,
                    day = now.getFullYear() + '-' + pad(now.getMonth() + 1) + '-' + pad(now.getDate());
                dateControl.value = dateControl.classList.contains('inp_datetime')
                    ? day + 'T' + pad(now.getHours()) + ':' + pad(now.getMinutes()) : day;
            }
        });

        this.element.querySelectorAll('.pane').forEach((pane) => {
            pane.style.border = '1px dotted #777';
            pane.style.overflow = 'auto';
        });
    }

    /**
     * Вкладка со своей страницей (data-src): при первом показе — iframe с этой страницей.
     */
    onTabChange() {
        const currentTab = this.tabPane.currentTab;
        if (currentTab.getAttribute('data-src') && !currentTab.loaded) {
            const iframe = document.createElement('iframe');
            iframe.src = Energine['base'] + currentTab.getAttribute('data-src');
            iframe.frameBorder = 0;
            iframe.scrolling = 'no';
            iframe.style.width = '99%';
            iframe.style.height = '99%';
            currentTab.pane.replaceChildren(iframe);
            currentTab.loaded = true;
        }
    }

    /**
     * Привязать панель: она встаёт в нижнюю панель окна (или в конец формы); список «после сохранения» показывает
     * выбор, запомненный в cookie.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        this.toolbar = toolbar;
        const toolbarContainer = this.element.querySelector('.e-pane-b-toolbar'),
            afterSaveActionSelect = this.toolbar.getControlById('after_save_action');
        (toolbarContainer || this.element).appendChild(this.toolbar.getElement());
        if (afterSaveActionSelect) {
            const savedActionState = Energine.readCookie('after_add_default_action');
            if (savedActionState) {
                afterSaveActionSelect.setSelected(savedActionState);
            }
        }
        toolbar.bindTo(this);
    }

    /**
     * Build the URL for saving.
     * @returns {string}
     */
    buildSaveURL() {
        return this.singlePath + 'save';
    }

    /**
     * Сохранить: визуальные поля — в textarea, проверка полей, затемнение, запрос с полями формы.
     */
    save() {
        this.richEditors.forEach((editor) => editor.onSaveForm());
        if (!this.validator.validate()) {
            return;
        }
        this.overlay.show();
        Energine.request(
            this.buildSaveURL(),
            Form.toQueryString(this.form),
            (response) => this.processServerResponse(response),
            (response) => this.processServerError(response),
            (response) => this.processServerError(response)
        );
    }

    /**
     * Ответ на сохранение: выбор «после сохранения» запоминается в cookie на сутки и уходит в ответе (afterClose);
     * ответ получает окно, из которого форму открыли; окно закрывается.
     *
     * @param {Object} response
     */
    processServerResponse(response) {
        const nextActionSelector = response && this.toolbar.getControlById('after_save_action');
        if (nextActionSelector) {
            Energine.writeCookie('after_add_default_action', nextActionSelector.getValue(),
                {path: Energine.sitePath(), days: 1});
            response.afterClose = nextActionSelector.getValue();
        }
        ModalBox.setReturnValue(response);
        this.overlay.hide();
        this.close();
    }

    /**
     * Отказ сервера: затемнение снимается, форма остаётся открытой.
     *
     * @param {Object} response
     */
    processServerError(response) {
        this.overlay.hide();
    }

    /**
     * Close the form.
     */
    close() {
        ModalBox.close();
    }

    /**
     * «Очистить» у поля файла: путь пуст, превью и сама ссылка скрыты.
     *
     * @param {string} fieldId id поля пути
     * @param {Element} lnk ссылка «очистить»
     */
    clearFileField(fieldId, lnk) {
        this.form.querySelector('#' + CSS.escape(fieldId)).value = '';
        const preview = this.form.querySelector('#' + CSS.escape(fieldId + '_preview'));
        if (preview) {
            preview.removeAttribute('href');
            preview.style.display = 'none';
        }
        lnk.style.display = 'none';
    }

    /**
     * Выбранный файл — в поле: путь, превью (картинка или значок файла), ссылка «очистить».
     *
     * @param {Object} result файл репозитория (upl_path, upl_internal_type)
     * @param {Element|string} button кнопка поля (атрибуты link и preview — id поля пути и превью)
     */
    processFileResult(result, button) {
        if (!result) {
            return;
        }
        button = Form.element(button);
        document.getElementById(button.getAttribute('link')).value = result['upl_path'];
        const preview = document.getElementById(button.getAttribute('preview')),
            image = (preview.tagName === 'IMG') ? preview : preview.querySelector('img');
        if (image) {
            image.setAttribute('src', (result['upl_internal_type'] === 'image')
                ? Energine.media + result['upl_path']
                : Energine['static'] + 'images/icons/icon_undefined.gif');
            preview.setAttribute('href', Energine.media + result['upl_path']);
            preview.style.display = 'block';
        }
        // ссылка «очистить» — рядом с полем, уровнем выше кнопки
        const append = button.closest('.with_append'),
            clear = append && append.querySelector('.lnk_clear');
        if (clear) {
            clear.style.display = 'inline';
        }
    }

    /**
     * «…» у поля файла: библиотека файлов; выбранный файл — в поле.
     *
     * @param {Element|string} button Button element.
     */
    openFileLib(button) {
        button = Form.element(button);
        let path = document.getElementById(button.getAttribute('link')).value;
        if (path === '') {
            path = null;
        }
        ModalBox.open({
            url: this.singlePath + 'file-library/',
            extraData: path,
            onClose: (result) => this.processFileResult(result, button)
        });
    }

    /**
     * «Быстрая загрузка»: окно добавления файла в папку быстрой загрузки; загруженный файл находится по id и
     * подставляется в поле, как выбранный в библиотеке.
     *
     * @param {Element|string} button Button element.
     */
    openQuickUpload(button) {
        button = Form.element(button);
        let path = document.getElementById(button.getAttribute('link')).value;
        if (path === '') {
            path = null;
        }
        const pid = button.getAttribute('quick_upload_pid');
        if (!button.getAttribute('quick_upload_enabled')) {
            return;
        }
        ModalBox.open({
            url: this.singlePath + 'file-library/' + pid + '/add',
            extraData: path,
            onClose: (result) => {
                if (!(result && result.data)) {
                    return;
                }
                this.overlay.show();
                const filter = {children: [{field: '[share_uploads][upl_id]', type: 'string', condition: '=', value: result.data}]};
                Energine.send(this.singlePath + 'file-library/' + pid + '/get-data/',
                    'json=1&filter=' + encodeURIComponent(JSON.stringify(filter)))
                    .then((response) => {
                        // затемнение снимается при любом ответе
                        this.overlay.hide();
                        const data = response.json && response.json.data;
                        if (data && data.length == 2) {
                            this.processFileResult(data[1], button);
                        }
                    });
            }
        });
    }

    /**
     * Поля формы строкой запроса — как прежде (toQueryString MooTools): input, select, textarea с именем, кроме
     * выключенных и submit, reset, file, image; флажки и переключатели — только отмеченные; у списка — выбранные
     * варианты. FormData не годится: textarea в нём отдаёт переводы строк \r\n.
     *
     * @param {Element} form
     * @returns {string}
     */
    static toQueryString(form) {
        const query = [];
        form.querySelectorAll('input, select, textarea').forEach((el) => {
            const type = el.type;
            if (!el.name || el.disabled || ['submit', 'reset', 'file', 'image'].includes(type)) {
                return;
            }
            let values = [el.value];
            if (el.tagName === 'SELECT') {
                values = Array.from(el.options).filter((option) => option.selected).map((option) => option.value);
            } else if ((type === 'radio' || type === 'checkbox') && !el.checked) {
                values = [];
            }
            values.forEach((value) => query.push(encodeURIComponent(el.name) + '=' + encodeURIComponent(value)));
        });
        return query.join('&');
    }

    /**
     * Элемент по id или сам элемент.
     *
     * @param {Element|string} element
     * @returns {Element}
     */
    static element(element) {
        return (typeof element === 'string') ? document.getElementById(element) : element;
    }
};

/**
 * Выбор раздела-родителя (подмешивается в DivForm): кнопка #sitemap_selector открывает окно дерева разделов;
 * выбранный раздел — в скрытом поле (атрибут hidden_field кнопки), его имя — текстом в подписи (span_field),
 * сегмент — в адресе раздела (#smap_pid_segment).
 *
 * @namespace
 */
Form.Label = {
    /**
     * Подключить кнопку выбора.
     *
     * @param {string} treeURL адрес окна дерева от адреса компонента
     */
    prepareLabel(treeURL) {
        this.obj = document.getElementById('sitemap_selector');
        if (this.obj) {
            this.obj.addEventListener('click', () => this.showTree(treeURL));
        }
    },

    /**
     * Окно дерева разделов.
     *
     * @param {string} url
     */
    showTree(url) {
        ModalBox.open({
            url: this.singlePath + url,
            onClose: (result) => this.setLabel(result)
        });
    },

    /**
     * Выбранный раздел — в поле. Окно закрыто без выбора (null, undefined) — ничего; false — выбор снят.
     *
     * @param {Object|boolean} result {smap_id, smap_name, smap_segment}
     */
    setLabel(result) {
        if (result === null || result === undefined) {
            return;
        }
        let id = '', name = '', segment = '';
        if (result) {
            id = result.smap_id;
            name = result.smap_name;
            segment = result.smap_segment;
        }
        document.getElementById(this.obj.getAttribute('hidden_field')).value = id;
        document.getElementById(this.obj.getAttribute('span_field')).textContent = name;
        const segmentObject = document.getElementById('smap_pid_segment');
        if (segmentObject) {
            segmentObject.textContent = segment;
        }
    }
};

/**
 * Визуальный редактор поля формы (Jodit, общая настройка — EnergineEditor).
 *
 * @constructor
 * @param {Element} textarea
 * @param {Form} form
 */
Form.RichEditor = class FormRichEditor {
    constructor(textarea, form) {
        /**
         * The text area element.
         * @type {Element}
         */
        this.textarea = textarea;
        /**
         * The main form.
         * @type {Form}
         */
        this.form = form;
        /**
         * Текст поля, как он пришёл с сервера, и значение редактора сразу после открытия:
         * если администратор текст не менял, сохраняется исходный текст, а не его прочтение редактором.
         * @type {string}
         */
        this.original = this.textarea.value;
        this.editor = EnergineEditor.make(this.textarea, {singlePath: this.form.singlePath});
        this.opened = this.editor.value;
    }

    /**
     * Перед отправкой формы текст редактора переносится в textarea — только если его меняли.
     */
    onSaveForm() {
        this.textarea.value = (this.editor.value === this.opened) ? this.original : this.editor.value;
    }
};
```

- [ ] **Step 2: DivForm.** Заменить `core/modules/share/scripts/DivForm.js` целиком:

Full file `core/modules/share/scripts/DivForm.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[DivForm]{@link DivForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 * @requires ModalBox
 *
 * @author Pavel Dubenko, Valerii Zinchenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form', 'ModalBox');

/**
 * Форма раздела: выбор родителя (Form.Label), шаблон содержимого задаёт сегмент и макет, сброс изменённого шаблона,
 * имя раздела на каждом включённом языке обязательно.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var DivForm = class DivForm extends Form {
    constructor(element) {
        super(element);
        this.prepareLabel('list/');

        const contentSelector = this.element.querySelector('#smap_content'),
            layoutSelector = this.element.querySelector('#smap_layout'),
            segmentInput = this.element.querySelector('#smap_segment');

        // шаблон со своим сегментом закрепляет сегмент, со своим макетом — выбирает макет; XML раздела сбрасывается
        contentSelector.addEventListener('change', () => {
            const option = contentSelector.selectedOptions[0];
            let segment, layout;
            if (segmentInput) {
                if ((segment = option.getAttribute('data-segment'))) {
                    segmentInput.readOnly = true;
                    segmentInput.value = segment;
                } else {
                    segmentInput.readOnly = false;
                }
            }
            if ((layout = option.getAttribute('data-layout')) && (layout != '*')) {
                layoutSelector.value = layout;
            }
            this.clearContentXML();
        });
    }

    /**
     * Reset the page content template.
     */
    resetPageContentTemplate() {
        Energine.request(
            this.singlePath + 'reset-templates/' + this.element.querySelector('#smap_id').value + '/',
            null,
            (response) => {
                if (response.result) {
                    const select = this.element.querySelector('#smap_content'),
                        option = select.children[select.selectedIndex],
                        optionText = option.textContent;
                    option.textContent = optionText.substring(0, optionText.lastIndexOf('-'));
                    this.clearContentXML();
                }
            }
        );
    }

    /**
     * Clear XML content.
     */
    clearContentXML() {
        // поле типа «код» на форме раздела одно — XML раздела
        const code = this.form.querySelector('textarea.code');
        if (code) {
            code.value = '';
            code.closest('div.field').classList.add('hidden');
        }
    }

    /**
     * Overridden parent [save]{@link Form#save} action: имя раздела на вкладке языка (раздел на нём не выключен)
     * обязательно.
     */
    save() {
        this.richEditors.forEach((editor) => editor.onSaveForm());
        if (!this.validator.validate()) {
            return false;
        }

        let valid = true;
        this.tabPane.getTabs().forEach((tab) => {
            if (tab.data.lang) {
                const checkbox = tab.pane.querySelector('input[type="checkbox"]');
                if (checkbox) {
                    const disabled = /share_sitemap_translation\[\d+\]\[smap_is_disabled\]/.test(checkbox.name) ? checkbox.checked : false;
                    if (!disabled && tab.pane.querySelector('input[type="text"]').value.trim().length == 0) {
                        valid = false;
                    }
                }
            }
        });

        if (!valid) {
            alert(Energine.translations.get('ERR_NO_DIV_NAME'));
            return false;
        }
        Energine.request(
            this.singlePath + 'save',
            Form.toQueryString(this.form),
            (response) => this.processServerResponse(response)
        );
    }
};
Object.assign(DivForm.prototype, Form.Label);
```

- [ ] **Step 3: GroupForm.** Заменить `core/modules/user/scripts/GroupForm.js` целиком:

Full file `core/modules/user/scripts/GroupForm.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[GroupForm]{@link GroupForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form');

/**
 * Форма роли: переключатель в строке «Все разделы» отмечает весь свой столбец прав.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var GroupForm = class GroupForm extends Form {
    constructor(element) {
        super(element);
        this.element.querySelectorAll('.groupRadio').forEach((radio) => {
            radio.addEventListener('click', (event) => this.checkAllRadioInColumn(event));
        });
    }

    /**
     * Event handler. Check radio button.
     *
     * @param {Object} event Event.
     */
    checkAllRadioInColumn(event) {
        const radio = event.target;
        radio.closest('tbody')
            .querySelectorAll('td.' + radio.closest('td').getAttribute('class') + ' input[type=radio]')
            .forEach((input) => {
                input.checked = true;
            });
    }
};
```

- [ ] **Step 4: ImageManager.** Заменить `core/modules/share/scripts/ImageManager.js` целиком:

Full file `core/modules/share/scripts/ImageManager.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ImageManager]{@link ImageManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 * @requires ModalBox
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form', 'ModalBox');

/**
 * Окно картинки при вставке в текст: данные картинки — из окна-родителя, размеры (по пропорции), выравнивание,
 * отступы, подпись; «Вставить» возвращает картинку.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} element The form element.
 */
var ImageManager = class ImageManager extends Form {
    constructor(element) {
        super(element);
        /**
         * Image data.
         * @type {Object}
         */
        this.image = {};
        /**
         * Defines whether the ratio will be saved.
         * @type {boolean}
         */
        this.saveRatio = false;
        /**
         * Image margins.
         * @type {string[]}
         */
        this.imageMargins = ['margin-left', 'margin-right', 'margin-top', 'margin-bottom'];

        this.field('filename').disabled = true;
        const imageData = ModalBox.getExtraData();
        if (imageData != null) {
            this.image = imageData;
            this.updateForm();
        }

        this.field('width').addEventListener('change', (event) => this.checkRatio(event));
        this.field('height').addEventListener('change', (event) => this.checkRatio(event));
    }

    /**
     * Поле окна по id.
     *
     * @param {string} id
     * @returns {Element}
     */
    field(id) {
        return document.getElementById(id);
    }

    /**
     * Ширина меняет высоту по пропорции (и наоборот); путь — через resizer, превью следом.
     *
     * @param {Object} event
     */
    checkRatio(event) {
        const target = event.target.id,
            oldWidth = this.image.upl_width,
            oldHeight = this.image.upl_height;
        let width = parseInt(this.field('width').value, 10),
            height = parseInt(this.field('height').value, 10),
            src;

        if (oldWidth != width || oldHeight != height) {
            if (target == 'width') {
                height = Math.round((oldHeight * width) / oldWidth);
            } else {
                width = Math.round((oldWidth * height) / oldHeight);
            }
            this.field('width').value = width;
            this.field('height').value = height;
            this.field('filename').value = src = Energine.resizer + 'w' + width + '-h' + height + '/' + this.image['upl_path'];
            this.field('thumbnail').setAttribute('src', src);
        }
    }

    /**
     * Open the image library.
     */
    openImageLib() {
        ModalBox.open({
            url: this.singlePath + 'file-library/',
            'post': JSON.stringify(this.image),
            onClose: (result) => {
                if (result) {
                    this.image = result;
                    this.updateForm();
                }
                window.focus();
            }
        });
    }

    /**
     * Update the form.
     */
    updateForm() {
        this.field('filename').value = this.image['upl_path'];
        this.field('thumbnail').src = Energine.media + this.image['upl_path'];
        this.field('width').value = this.image['upl_width'] || 0;
        this.field('height').value = this.image['upl_height'] || 0;
        this.field('align').value = this.image.align || '';

        this.imageMargins.forEach((propertyName) => {
            this.field(propertyName).value = this.field(propertyName).value || this.image[propertyName] || '0';
        });

        const alt = this.field('alt');
        if (!alt.value) {
            alt.value = this.image['upl_title'] || '';
        }
    }

    /**
     * Insert the image.
     */
    insertImage() {
        if (this.field('filename').value) {
            this.image.filename = this.field('filename').value;
            this.image.width = parseInt(this.field('width').value) || '';
            this.image.height = parseInt(this.field('height').value) || '';
            this.image.align = this.field('align').value || '';
            this.imageMargins.forEach((propertyName) => {
                this.image[propertyName] = parseInt(this.field(propertyName).value) || 0;
            });
            this.image.alt = this.field('alt').value;
            this.image.thumbnail = this.field('thumbnail').src;
            ModalBox.setReturnValue(this.image);
        }
        this.close();
    }
};
```

- [ ] **Step 5: FileRepoForm.** Заменить `core/modules/share/scripts/FileRepoForm.js` целиком (комментарии методов
  — из прежнего файла, где они есть):

Full file `core/modules/share/scripts/FileRepoForm.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FileRepoForm]{@link FileRepoForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Form
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Form');

/**
 * Форма файла репозитория: файл уходит во временный файл (upload-temp) сразу при выборе, превью и маленькие
 * изображения строятся по нему; вкладка «Маленькое изображение» включается после загрузки картинки.
 *
 * @augments Form
 *
 * @constructor
 * @param {Element|string} el The main holder element.
 */
var FileRepoForm = class FileRepoForm extends Form {
    constructor(el) {
        super(el);

        const uploader = this.element.querySelector('#uploader');
        if (uploader) {
            uploader.addEventListener('change', (evt) => this.showPreview(evt));
        }

        /**
         * Thumbnails.
         * @type {Element[]}
         */
        this.thumbs = Array.from(this.element.querySelectorAll('img.thumb'));
        this.element.querySelectorAll('input.thumb').forEach((input) => {
            input.addEventListener('change', (evt) => this.showThumbPreview(evt));
        });
        this.element.querySelectorAll('input.preview').forEach((input) => {
            input.addEventListener('change', (evt) => this.showAltPreview(evt));
        });

        const data = this.element.querySelector('#data');
        if (data && !data.value) {
            this.tabPane.disableTab(1);
        }
    }

    /**
     * Show alternative preview.
     *
     * @param {Object} evt Event.
     */
    showAltPreview(evt) {
        this.showThumbPreview(evt);
    }

    /**
     * Маленькое изображение: картинка уходит во временный файл, превью — по нему.
     *
     * @param {Object} evt Event.
     */
    showThumbPreview(evt) {
        const el = evt.target,
            files = Array.from(el.files || []);

        for (let i = 0; i < files.length; i++) {
            if (files[i].type.match('image.*')) {
                this.xhrFileUpload(el.id, files, (response) => {
                    const previewElement = document.getElementById(el.getAttribute('preview')),
                        dataElement = document.getElementById(el.getAttribute('data'));
                    if (previewElement) {
                        previewElement.classList.remove('hidden');
                        previewElement.setAttribute('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                    }
                    if (dataElement) {
                        dataElement.value = response.tmp_name;
                    }
                });
            }
        }
    }

    /**
     * Generate previews.
     *
     * @param {string} tmpFileName
     */
    generatePreviews(tmpFileName) {
        this.thumbs.forEach((el) => {
            el.classList.remove('hidden');
            el.setAttribute('src', Energine.base + 'resizer/' + 'w' + el.getAttribute('width') + '-h'
                + el.getAttribute('height') + '/' + tmpFileName);
        });
    }

    /**
     * Загрузка файла во временный: fetch с токеном; отказ сервера или чужой ответ — причина у поля.
     *
     * @param {string} field_name id поля файла
     * @param {File[]} files
     * @param {function} response_callback вызывается с ответом сервера, если файл принят
     * @returns {Promise}
     */
    xhrFileUpload(field_name, files, response_callback) {
        const body = new FormData(),
            field = this.element.querySelector('#' + CSS.escape(field_name));
        body.append('csrf_token', Energine.csrf || '');
        body.append('key', field_name);
        body.append('pid', document.getElementById('upl_pid').value);
        body.append(field_name, files[0]);

        this.validator.removeError(field);
        // токен ещё и в заголовке: тело больше post_max_size PHP отбрасывает целиком, и отказ должен
        // объяснить размер, а не «устаревшую форму»
        return fetch(this.singlePath + 'upload-temp/?json', {method: 'POST', body: body, credentials: 'same-origin',
            headers: {'X-CSRF-Token': Energine.csrf || ''}})
            .then((response) => response.text().then((text) => {
                let result = null;
                try {
                    result = JSON.parse(text);
                } catch (e) {
                }
                if (result && !result.error && result.tmp_name) {
                    response_callback(result);
                    return;
                }
                // отказ сервера (запрещённый тип файла, размер, нет прав, устаревшая форма) или ответ
                // не сервера сайта (страница прокси) — причина у поля
                this.uploadFailed(field, (result && (result.error_message
                    || (result.errors && result.errors[0] && result.errors[0].message)))
                    || this.uploadFailedText(response.status));
            }))
            .catch(() => this.uploadFailed(field, this.uploadFailedText(0)));
    }

    /**
     * Текст неудачной загрузки с кодом ответа.
     *
     * @param {number} status
     * @returns {string}
     */
    uploadFailedText(status) {
        return (Energine.translations.get('ERR_UPLOAD_FAILED') || 'Upload failed') + (status ? ' (HTTP ' + status + ')' : '');
    }

    /**
     * Загрузка не удалась: причина у поля, превью и путь временного файла убраны, поле файла пусто.
     *
     * @param {Element} field
     * @param {string} message
     */
    uploadFailed(field, message) {
        this.validator.showError(field, String(message));
        const isMain = (field.id == 'uploader'),
            preview = isMain ? document.getElementById('preview') : document.getElementById(field.getAttribute('preview')),
            data = isMain ? document.getElementById('data') : document.getElementById(field.getAttribute('data'));
        if (preview) {
            preview.removeAttribute('src');
            preview.classList.add('hidden');
        }
        if (data) {
            data.value = '';
        }
        field.value = '';
    }

    /**
     * Show preview.
     *
     * @param {Object} evt Event.
     */
    showPreview(evt) {
        const previewElement = document.getElementById('preview');
        previewElement.removeAttribute('src');
        this.thumbs.forEach((thumb) => {
            thumb.removeAttribute('src');
            thumb.classList.add('hidden');
        });
        previewElement.setAttribute('src', Energine.base + 'images/loading.gif');

        const files = Array.from(evt.target.files || []);
        for (let i = 0; i < files.length; i++) {
            this.xhrFileUpload('uploader', files, (response) => {
                document.getElementById('upl_name').value = response.name;
                document.getElementById('upl_filename').value = response.name;
                document.getElementById('data').value = response.tmp_name;
                document.getElementById('upl_title').value = response.name.split('.')[0];

                if (response.type.match('image.*')) {
                    previewElement.removeAttribute('src');
                    previewElement.classList.add('hidden');
                    previewElement.setAttribute('src', Energine.base + 'resizer/' + 'w0-h0/' + response.tmp_name);
                    this.generatePreviews(response.tmp_name);
                    this.tabPane.enableTab(1);
                } else {
                    previewElement.setAttribute('src', Energine['static'] + 'images/icons/icon_undefined.gif');
                }
                previewElement.classList.remove('hidden');
            });
        }
    }

    /**
     * Overridden parent [buildSaveURL]{@link Form#buildSaveURL} method.
     *
     * @returns {string}
     */
    buildSaveURL() {
        return Energine.base + this.form.getAttribute('action');
    }
};
```

- [ ] **Step 6: toolbar.xslt.** В `core/modules/share/transformers/toolbar.xslt`, шаблон
  `toolbar[parent::component[@exttype='grid']]`, удалить строки от `var holder = document.id(…` до закрывающей `}`
  блока `if (content … <= 680) {…}` включительно (с закомментированным `content.setStyles`): высота считалась, но не
  применялась. Остаётся `componentToolbars[…] = new Toolbar(…)`, кнопки и `attachToolbar`.

- [ ] **Step 7: no-traces.** В `VANILLA_JS` добавить `core/modules/share/scripts/Form.js
  core/modules/share/scripts/DivForm.js core/modules/share/scripts/FileRepoForm.js
  core/modules/share/scripts/ImageManager.js core/modules/user/scripts/GroupForm.js`.

- [ ] **Step 8: Карта скриптов на стенде и прогон.**

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh mootools; cd tests/audit && for t in editors grids; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '$t'.js' > $W/t3-$t.log 2>&1; echo "$t $?"; grep -E '^FAIL' $W/t3-$t.log; done`
Expected: no-traces — 0; editors — `== editors failures: 0` (все восемь прежде красных — OK); grids — 0.

- [ ] **Step 9: Commit**

```bash
git add core/modules/share/scripts/Form.js core/modules/share/scripts/DivForm.js core/modules/share/scripts/FileRepoForm.js core/modules/share/scripts/ImageManager.js core/modules/user/scripts/GroupForm.js core/modules/share/transformers/toolbar.xslt tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 5: формы админки на чистом JavaScript; «очистить» у поля файла видна после выбора, имя родителя — текстом" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 4: Документы и итоговая проверка

**Files:**
- Modify: `README.md` (абзац этапа 8 — шаг 5; список спецификаций)
- Modify: `tests/README.md` (что проверяет `editors.js`: блоки 17–24)

- [ ] **Step 1: README.md.** После предложения о шаге 4 добавить: «Шаг 5
  (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step5-forms-editor-design.md`): формы админки, визуальный
  редактор и правка на странице — на чистом JavaScript; окна форм и режим правки MooTools не получают.»; в список
  спецификаций — строку шага 5.
- [ ] **Step 2: tests/README.md.** В описание `editors.js` добавить: «Без MooTools: формы пользователя, раздела, роли,
  файла, окно картинки, режим правки. Форма пользователя: Enter не отправляет форму, поле файла (библиотека,
  «очистить», быстрая загрузка). Сохранение из грида шаблонов: «Править следующий», cookie выбора. Форма раздела:
  свёртывание текстового поля, шаблон с сегментом и макетом, выбор родителя (имя — текстом), пустое имя языка, сброс
  шаблона. Форма роли: столбец прав. Окно картинки: пропорции. Вкладка со своей страницей. Строка запроса формы.
  Временные записи и файл удаляются, XML раздела возвращается.»
- [ ] **Step 3: Весь набор на стенде.**

Run: `bash tests/tools/stand.sh run bash tests/no-traces.sh all; bash tests/tools/stand.sh run bash tests/regression.sh > $W/t4-regression.log 2>&1; grep -c 'failures: 0' $W/t4-regression.log; cd tests/audit && for t in public grids editors theme crawl; do …; done` (как в задаче 4 шага 4: `crawl` — с `crawl-guest.txt crawl-admin.txt crawl-singles.txt $W/crawl.json`)
Expected: no-traces 0; регрессия 17/17, журнал PHP чист; аудиты — `failures: 0`; crawl — `pages: 72, with errors: 0`.

- [ ] **Step 4: Commit**

```bash
git add README.md tests/README.md
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 5: документы" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 5: Выкладка и проверка на simple.energine.org

Без отдельного согласования (владелец: «продолжай без остановки»). База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step5-<дата>/`.
- [ ] **Step 2: Код** — от имени web97: `git fetch <клон> main && git merge --ff-only FETCH_HEAD` в живом дереве.
- [ ] **Step 3: Статика** — в `web/` от web97: `setup linker && setup scriptMap`; карта: у `Form` — `EnergineEditor`,
  `TabPane`, `Toolbar`, `Validator`, `ModalBox`, `Overlay`; у `EnergineEditor` — `jodit/jodit.min`, `ModalBox`; у
  `DivForm`, `ImageManager` — `Form`, `ModalBox`; у `GroupForm`, `FileRepoForm` — `Form`; у `PageEditor` —
  `EnergineEditor`, `ModalBox`, `Overlay`; `MooCompat` — только у восьми скриптов гридов и структуры.
- [ ] **Step 4: Проверка гостем** — `live-guest.js`.
- [ ] **Step 5: Регрессия и аудиты на площадке** (`regression.sh`, `public`, `grids`, `editors`, `theme`, `crawl`),
  затем `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 6: При провале** — откат: от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`;
  отчёт владельцу.
