# Energine Simple, этап 8, шаг 1 — публичный сайт без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** посетитель сайта (гость или вошедший без прав администратора) не получает MooTools ни на одной публичной странице, формы ведут себя как раньше, админка работает как раньше.

**Architecture:** шесть общих файлов (`Energine.js`, `Validator.js`, `ValidForm.js`, `LoginForm.js`, `Register.js`, `UserProfile.js`) переписываются на чистый JavaScript с прежним интерфейсом. MooTools становится зависимостью в карте `system.jsmap.php`: каждый скрипт, ещё написанный на MooTools, объявляет первой зависимостью `MooCompat` (мост с заплатками), а `MooCompat` — `mootools.min`. Документ подключает библиотеки по карте, так что MooTools приходит только туда, где нужна. Адрес каждого скрипта несёт версию `?v=`.

**Tech Stack:** PHP 8.5, XSLT 1.0 (`document.xslt`, `toolbar.xslt`, `file.xslt`), JavaScript (классические скрипты, `fetch`, классы), MooTools 1.5.2 (админка, до следующих шагов), Playwright (аудиты), bash.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-public-without-mootools-design.md`

## Global Constraints

- Только современные браузеры: классы, `fetch`, `closest`, `classList`, `scrollIntoView` с параметрами; без сборки, npm и ES-модулей.
- Классические скрипты; классы объявляются как `var Имя = class Имя …` (глобальное свойство окна, как прежние `var Имя = new Class(…)`).
- Интерфейс `Energine` и `Validator` для админки не меняется: те же имена, параметры и обработчики (спецификация, раздел 3.2).
- Сервер, разметка форм, адреса и ответы JSON, база — не меняются.
- Зависимости скрипта — первый вызов `ScriptLoader.load('…', …)` в файле (его читает `setup scriptMap`, `Setup::parseScriptLoader`); в комментариях такой вызов с именами в кавычках не пишется.
- В файлах из списка `VANILLA_JS` (`tests/no-traces.sh`) нет конструкций MooTools — и в комментариях тоже.
- Комментарии — по-русски, как в коде; строки `@author` в шапках файлов остаются.
- Проверки — только на стенде (`tests/tools/stand.sh`); площадка — только в задаче 6 после «да» владельца.
- Коммиты — `bash tests/tools/stand.sh run git commit …` (хук проверки паролей видит учётные данные стенда); последняя строка сообщения — `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Пароли и учётные данные не попадают в файлы, журналы и отчёты.

## Review Focus

- **Порядок запуска в админке.** Встроенный скрипт панели грида (`toolbar.xslt`, `file.xslt`) привязывает панель к гриду, который создаёт запуск поведений (`document.xslt`); с запуском на `DOMContentLoaded`, а панели — на `domready` MooTools, панель запустилась бы раньше грида и осталась бы непривязанной. Ожидание: у каждого грида панель с кнопками. Тест — `grids.js` (задача 1; красная в середине задачи 2, зелёная после правки шаблонов панелей).
- **Логин с «+» при проверке занятости.** Прежний код слал его без кодирования, сервер получал пробел. Ожидание: занятый логин с «+» назван занятым. Тест — `public.js` (задача 1, красная до задачи 3).
- **Отказ сервера на запрос админки** (чужой токен — 422 с `errors`). Ожидание: администратор видит текст отказа, вызывается `onUserError`. Тест — `grids.js` (задача 1, зелёная всё время).
- **Ошибка в поле на неоткрытой вкладке админской формы.** Ожидание: форма не уходит, вкладка с полем открывается, у поля ошибка. Тест — `editors.js`, шаг 13 (задача 1, зелёная всё время).
- **Текст ошибки загрузки с `<` и `&`.** `FileRepoForm` экранирует его для прежнего `Validator` (тот вставлял HTML); новый выводит текст, и экранирование показалось бы как `&lt;`. Ожидание: причина отказа видна как есть, разметка не разобрана. Тест — `editors.js`, шаг 12 (задача 1; красная в середине задачи 3, зелёная после правки `FileRepoForm`).

---

### Task 1: Проверки — публичный сайт, запросы и панели админки, вкладки, текст ошибки, категория `mootools`

**Files:**
- Create: `tests/audit/public.js`, `tests/audit/public-db.php`
- Modify: `tests/audit/grids.js` (блок перед «журнал действий: фильтр по дате»), `tests/audit/editors.js` (шаг 12 — текст ошибки; шаг 13 — вкладки), `tests/no-traces.sh` (категория `mootools`)

**Interfaces:**
- Consumes: стенд (`tests/tools/stand.sh`), `tests/testlib.php` (`q()`, `pdo()`), `tests/audit/editors-db.php mail-snap ID`, помощники `editors.js` (`watch`, `showTabOf`, `db`, `check`) и `grids.js` (`ctx`, `watch`, `check`).
- Produces: `node public.js` (выход 0 — без провалов); `bash tests/no-traces.sh code mootools`; массив `VANILLA_JS` в `tests/no-traces.sh` — список переписанных файлов (растёт с шагами).

- [ ] **Step 1: `tests/audit/public-db.php`**

```php
<?php
// Помощник public.js: временный посетитель (группа пользователя по умолчанию — как после регистрации) и его
// удаление. В логине — «+»: проверка занятости логина при регистрации должна передать его без искажений.
//   php8.5 public-db.php user-add       — создать, вывести {"login": …, "password": …}
//   php8.5 public-db.php user-remove    — удалить всех посетителей теста
require dirname(__DIR__) . '/testlib.php';

[, $cmd] = $argv + [null, null];
switch ($cmd) {
    case 'user-add':
        $login = 'claude-public+' . getmypid() . '@example.org';
        $password = bin2hex(random_bytes(8));
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
            [$login, password_hash($password, PASSWORD_DEFAULT), 'Claude Public']);
        $uid = pdo()->lastInsertId();
        q('INSERT INTO user_user_groups (u_id, group_id) SELECT ?, group_id FROM user_groups WHERE group_user_default = 1', [$uid]);
        echo json_encode(['login' => $login, 'password' => $password]);
        break;
    case 'user-remove':
        q("DELETE FROM user_users WHERE u_name LIKE 'claude-public+%'");
        break;
    default:
        fwrite(STDERR, "неизвестная команда\n");
        exit(2);
}
```

- [ ] **Step 2: `tests/audit/public.js`**

```js
// Browser test of the public site without MooTools (stage 8, step 1). A guest and a signed-in visitor on the public
// pages in both languages: MooTools is neither requested nor defined, every script of the site carries a version
// (?v=), no JS errors and no 400+ responses. The forms behave as before: the login form is not sent empty (errors at
// the fields) and signs a visitor in; registration marks a wrong e-mail and checks the login when the field is left
// (a taken one — an error and the button off, a free one — the button on; a "+" in the login reaches the server as
// "+"); the profile refuses different new passwords. The temporary visitor is removed (public-db.php).
// Run in a subshell, like crawl.js:
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node public.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const { execFileSync } = require('child_process');
const path = require('path');

if (!process.env.BASE) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const db = (...args) => execFileSync('php8.5', [path.join(__dirname, 'public-db.php'), ...args], { encoding: 'utf8' });
let fail = 0;
function check(label, cond, detail = '') {
    console.log((cond ? 'OK   ' : 'FAIL ') + label + (cond ? '' : ': ' + String(detail).replace(/\s+/g, ' ').slice(0, 300)));
    if (!cond) fail++;
    return cond;
}
// a page and the log of what a visitor must not get (MooTools, JS errors, 400+ responses) and of the forms it sent
async function open(ctx, url) {
    const p = await ctx.newPage();
    const log = { moo: [], errors: [], posts: [] };
    p.on('request', (r) => {
        if (/mootools/i.test(r.url())) log.moo.push(r.url());
        if (r.method() === 'POST' && r.isNavigationRequest()) log.posts.push(r.url());
    });
    p.on('pageerror', (e) => log.errors.push('pageerror: ' + e.message));
    p.on('console', (m) => { if (m.type() === 'error') log.errors.push('console: ' + m.text()); });
    p.on('response', (r) => { if (r.status() >= 400) log.errors.push(`http ${r.status()}: ${r.url()}`); });
    await p.goto(BASE + url, { waitUntil: 'networkidle' });
    return [p, log];
}
// what the page loaded: is MooTools defined; the scripts of the site (any host of the static files) without a version
const inspect = (p) => p.evaluate(() => {
    const scripts = [...document.querySelectorAll('script[src]')].map((s) => s.src)
        .filter((src) => /\/scripts\/[^?#]+\.js([?#]|$)/.test(src));
    return { moo: typeof window.MooTools !== 'undefined', scripts: scripts.length,
        unversioned: scripts.filter((src) => !/\.js\?v=\d+$/.test(src)) };
});
async function pageChecks(ctx, who, url) {
    const [p, log] = await open(ctx, url);
    const r = await inspect(p);
    check(`${who} /${url}: MooTools не запрашивается и не определена`, !log.moo.length && !r.moo,
        log.moo.join(' ') || 'MooTools определена');
    check(`${who} /${url}: скрипты сайта — с версией ?v=`, r.scripts > 0 && !r.unversioned.length,
        r.unversioned.join(' ') || 'скриптов сайта нет');
    check(`${who} /${url}: без ошибок JS и 404`, !log.errors.length, log.errors.join(' | '));
    await p.close();
}
// the error shown at a field (Validator: div.error in the field's box)
const fieldError = (p, selector) => p.evaluate((sel) => {
    const f = document.querySelector(sel);
    const box = f && f.closest('.field');
    const err = box && box.querySelector('div.error');
    return { invalid: !!f && f.classList.contains('invalid'), error: err ? err.textContent.trim() : '' };
}, selector);

(async () => {
    db('user-remove');
    const visitor = JSON.parse(db('user-add'));
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    try {
        const guest = await browser.newContext({ locale: 'ru-RU' });

        // 1. the guest's pages in both languages
        for (const url of ['', 'login/', 'register/', 'restore-password/', 'sitemap/',
            'ua/', 'ua/login/', 'ua/register/', 'ua/restore-password/', 'ua/sitemap/']) {
            await pageChecks(guest, 'гость', url);
        }

        // 2. login: the empty form is not sent, both fields show errors; with the visitor's data — signed in
        const member = await browser.newContext({ locale: 'ru-RU' });
        {
            const [p, log] = await open(member, 'login/');
            await p.click('button[name="user[login]"]');
            await p.waitForTimeout(500);
            const e = await p.evaluate(() => {
                const form = document.getElementById('username').form;
                return { errors: form.querySelectorAll('div.error').length, invalid: form.querySelectorAll('.invalid').length };
            });
            check('вход: пустая форма не уходит, у обоих полей ошибки', !log.posts.length && e.errors === 2 && e.invalid === 2,
                JSON.stringify({ ...e, posts: log.posts }));
            await p.fill('#username', visitor.login);
            await p.fill('#password', visitor.password);
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('button[name="user[login]"]')]);
            check('вход: без ошибок JS', !log.errors.length, log.errors.join(' | '));
            await p.close();
        }

        // 3. the visitor's pages (the profile is open only to a signed-in visitor)
        for (const url of ['profile/', 'ua/profile/', '', 'sitemap/']) {
            await pageChecks(member, 'посетитель', url);
        }

        // 4. registration: a wrong e-mail, a taken login (with "+"), a free login — checked when the field is left
        {
            const [p, log] = await open(guest, 'register/');
            const sent = [];
            p.on('request', (r) => { if (r.url().includes('/check/')) sent.push(r.url()); });
            const leave = async (value) => {
                await p.fill('#u_name', value);
                const before = sent.length;
                const answer = p.waitForResponse((r) => r.url().includes('/check/'), { timeout: 10000 }).catch(() => null);
                await p.focus('#u_fullname');
                await p.waitForTimeout(300);
                const resp = sent.length > before ? await answer : null;
                await p.waitForTimeout(200);
                const s = await fieldError(p, '#u_name');
                s.disabled = await p.evaluate(() => document.querySelector('button[name=register]').disabled);
                s.status = resp ? resp.status() : 0;
                return s;
            };
            let s = await leave('not-an-email');
            check('регистрация: неверный e-mail — ошибка у поля, кнопка выключена, проверки логина нет',
                s.invalid && s.error !== '' && s.disabled && !s.status, JSON.stringify(s));
            s = await leave(visitor.login);
            check('регистрация: занятый логин с «+» — ошибка у поля, кнопка выключена',
                s.status === 200 && s.invalid && s.error !== '' && s.disabled, JSON.stringify(s));
            s = await leave(`claude-public-free-${process.pid}@example.org`);
            check('регистрация: свободный логин — ошибки нет, кнопка включена', s.status === 200 && !s.invalid && !s.disabled,
                JSON.stringify(s));
            check('регистрация: форма не отправлялась, без ошибок JS', !log.posts.length && !log.errors.length,
                JSON.stringify({ posts: log.posts, errors: log.errors }));
            await p.close();
        }

        // 5. profile: a different new password and repeat — an error at the field, the form is not sent
        {
            const [p, log] = await open(member, 'profile/');
            if (check('профиль: форма открыта посетителю', await p.$('#u_password') !== null && await p.$('#u_password2') !== null)) {
                await p.fill('#u_password', 'claude-new-1');
                await p.fill('#u_password2', 'claude-new-2');
                await p.evaluate(() => document.getElementById('u_password').form.requestSubmit());
                await p.waitForTimeout(500);
                const s = await fieldError(p, '#u_password');
                s.want = await p.evaluate(() => document.getElementById('u_password').getAttribute('nrgn:message2'));
                check('профиль: разные пароли — ошибка у поля, форма не ушла', !log.posts.length && s.invalid && !!s.want
                    && s.error === s.want, JSON.stringify({ ...s, posts: log.posts }));
            }
            check('профиль: без ошибок JS', !log.errors.length, log.errors.join(' | '));
            await p.close();
        }
    } finally {
        await browser.close();
        db('user-remove');
    }
    console.log(`== public failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); try { db('user-remove'); } catch (x) { } process.exit(1); });
```

- [ ] **Step 3: `tests/audit/grids.js` — запросы `Energine.request` и панели гридов**

Перед блоком `// журнал действий: фильтр по дате — встроенное поле даты браузера` (внутри `try`, отступ 8 пробелов) вставить:

```js
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
            await rp.close();
        }

```

- [ ] **Step 4: `tests/audit/editors.js` — текст ошибки загрузки (шаг 12) и вкладки (шаг 13)**

В шаге 12 после проверки `'неудачная загрузка после удачной не оставляет прежний файл'` (перед `if (j && j.tmp_name) {`) вставить:

```js
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
```

Перед блоком `// 12. an upload that did not happen` вставить:

```js
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

```

В шапке файла (вторая строка комментария) после `the file upload in the repository form via fetch.` дописать: ` The form's Validator: an error on a tab that is not open opens that tab.`

- [ ] **Step 5: `tests/no-traces.sh` — категория `mootools`**

1. В шапку после строки `#   dead (мёртвый код ядра)` добавить:
```bash
# Этап 8 — без MooTools: mootools (в файлах, переписанных на чистый JavaScript, нет конструкций MooTools; первая
#   зависимость каждого скрипта, ещё написанного на MooTools, — MooCompat: по ней документ подключает MooTools)
```
2. В список по умолчанию: `ckeditor fileapi jsonp theme multisite apps gallery editors dead mootools i18n)`.
3. После строки `FILES[dead]=…` добавить:
```bash
# этап 8: MooTools уходит файл за файлом (спецификация этапа 8, §3). VANILLA_JS — файлы, уже переписанные на чистый
# JavaScript: в них нет конструкций MooTools. Остальные скрипты ядра и сайта, кроме сторонних библиотек и самого
# MooCompat.js, объявляют MooCompat первой зависимостью
VANILLA_JS=(core/modules/share/scripts/Energine.js core/modules/share/scripts/Validator.js
            core/modules/share/scripts/ValidForm.js core/modules/user/scripts/LoginForm.js
            core/modules/user/scripts/Register.js core/modules/user/scripts/UserProfile.js)
MOOTOOLS_CODE='new Class\(|\$\$?\(|\.(add|remove)Events?\(|\.fireEvent\(|Request\.JSON|new Request\(|Object\.append|new Element\(|\.getElements?\(|\.getParent\(|\.inject\(|\.grab\(|\.adopt\(|\.pass\(|\.each\(|\.(get|set)Property\(|\.(add|remove|has)Class\(|\.(get|set)\(.(value|html|text|tag|disabled).|Fx\.|\.toInt\(\)|Browser\.|typeOf\(|instanceOf\('
# первая зависимость скрипта — как её читает setup scriptMap (Setup::parseScriptLoader): первый в файле вызов
# ScriptLoader.load с именем в кавычках
first_dep() { grep -o -E "ScriptLoader\.load\([[:space:]]*['\"][^'\"]+['\"]" "$1" | head -1 | sed -E "s/.*['\"]([^'\"]+)['\"]$/\1/"; }
```
4. В цикле, в ветке кода (`if [ "$scope" != db ]; then`), строку `    if [ "$m" = mail-core ]; then` заменить на:
```bash
    if [ "$m" = mootools ]; then
      found=$(G "$MOOTOOLS_CODE" "${VANILLA_JS[@]}" | cut -c1-160)
      # скрипт на MooTools с другой первой зависимостью: на его странице документ не подключил бы MooTools
      n=0
      while read -r f; do
        n=$((n + 1))
        case " ${VANILLA_JS[*]} " in *" $f "*) continue ;; esac
        [ "$(first_dep "$R/$f")" = MooCompat ] || found+=$'\n'"$f: первая зависимость — не MooCompat"
      done < <(cd "$R" && find core site -name '*.js' -not -path '*/scripts/jodit/*' -not -name 'mootools*.js' \
                 -not -name MooCompat.js | sort)
      [ "$n" -gt 0 ] || found+=$'\n'"__GREPERROR__ скрипты ядра не найдены"
    elif [ "$m" = mail-core ]; then
```
5. Условие базы `if [ "$scope" != code ] && [ "$m" != mail-core ]; then` → `if [ "$scope" != code ] && [ "$m" != mail-core ] && [ "$m" != mootools ]; then`.

- [ ] **Step 6: Новые проверки падают там, где должны, проверки поведения на нынешнем коде проходят**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
bash -n tests/no-traces.sh && node --check tests/audit/public.js && node --check tests/audit/grids.js && node --check tests/audit/editors.js && php8.5 -l tests/audit/public-db.php
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools > "$L/t1-no-traces.log" 2>&1; echo "no-traces $?"; head -12 "$L/t1-no-traces.log"
cd tests/audit && for t in public grids editors; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js' > "$L/t1-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t1-$t.log" | head -25; done; cd ../..
```
Expected:
- `no-traces` — выход 1: конструкции MooTools в шести файлах и 23 скрипта с первой зависимостью «не MooCompat».
- `public` — выход 1; провалы — «MooTools не запрашивается и не определена» и «скрипты сайта — с версией ?v=» на каждой странице, «занятый логин с «+»» (логин уходит без кодирования, сервер видит пробел — логин «свободен»); остальные проверки поведения — OK.
- `grids` и `editors` — выход 0: проверки запросов, панели, вкладок и текста ошибки проходят на нынешнем коде.

- [ ] **Step 7: Commit**

```bash
git add tests/audit/public.js tests/audit/public-db.php tests/audit/grids.js tests/audit/editors.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8: проверки — публичный сайт без MooTools, запросы и панели админки, вкладки, категория mootools" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: `Energine.js` на чистом JavaScript, `MooCompat.js`, объявления зависимости, порядок запуска

**Files:**
- Create: `core/modules/share/scripts/MooCompat.js`
- Modify: `core/modules/share/scripts/Energine.js` (переписать целиком); `core/modules/share/transformers/document.xslt` (`Object.assign`, `DOMContentLoaded`); `core/modules/share/transformers/toolbar.xslt`, `core/modules/share/transformers/file.xslt` (запуск панели — `DOMContentLoaded`); 23 админских скрипта и пять публичных (`Validator.js`, `ValidForm.js`, `LoginForm.js`, `Register.js`, `UserProfile.js` — объявление `MooCompat` временное, до задачи 3: им до переписывания нужна заплатка токена в запросах MooTools)

**Interfaces:**
- Consumes: проверки `grids.js` (запросы, отказ 422, панель грида) из задачи 1.
- Produces: `Energine.send(uri, body, method) → Promise<{status: number, text: string, json: Object|null}>` (сетевая ошибка — `status` 0); `Energine.request(uri, data, onSuccess, onUserError, onServerError, method)` — прежний; `Energine.csrfInput() → HTMLInputElement`; `MooCompat` — имя первой зависимости скриптов на MooTools.

- [ ] **Step 1: `core/modules/share/scripts/MooCompat.js`**

```js
/**
 * @file Мост к MooTools для скриптов, которые на ней ещё написаны (админка): каждый объявляет MooCompat первой
 * зависимостью, и документ подключает MooTools и этот файл раньше них. Здесь — то, что нужно только рядом
 * с MooTools.
 */

/**
 * Array.from у MooTools 1.5 не понимает итерируемые объекты — Set, Map, итераторы заворачивает в массив
 * из одного элемента — и не принимает функцию-отображение. Современные библиотеки (Jodit) рассчитывают
 * на стандартное поведение: для них оно такое, для остальных вызовов (код на MooTools) — прежнее.
 */
(function () {
    var mooFrom = Array.from;
    Array.from = function (item, mapFn, thisArg) {
        var result, i, it, step;
        if (item != null && typeof item !== 'string' && typeof item.length !== 'number'
            && typeof item[Symbol.iterator] === 'function') {
            result = [];
            for (it = item[Symbol.iterator](), step = it.next(); !step.done; step = it.next()) {
                result.push(step.value);
            }
        } else if (typeof mapFn === 'function' && item != null && typeof item !== 'function'
            && typeof item.length === 'number') {
            result = [];
            for (i = 0; i < item.length; i++) {
                result.push(item[i]);
            }
        } else {
            result = mooFrom(item);
        }
        return (typeof mapFn === 'function') ? result.map(mapFn, thisArg) : result;
    };
})();

/**
 * Токен против подделки запросов (Csrf на сервере): каждый запрос Request MooTools несёт его в заголовке.
 * Energine.csrf задаёт страница (document.xslt).
 */
(function () {
    var send = Request.prototype.send;
    Request.prototype.send = function () {
        if (Energine.csrf) {
            this.setHeader('X-CSRF-Token', Energine.csrf);
        }
        return send.apply(this, arguments);
    };
})();
```

- [ ] **Step 2: Объявить `MooCompat` первой зависимостью скриптов на MooTools**

```bash
python3 - <<'PY'
import re, subprocess
files = subprocess.run(['git', 'ls-files', 'core/*.js', 'site/*.js'], capture_output=True, text=True, check=True).stdout.split()
skip = re.compile(r'/scripts/jodit/|/mootools[^/]*\.js$|/(Energine|MooCompat)\.js$')
for f in files:
    if skip.search(f):
        continue
    with open(f, encoding='utf8', newline='') as fh:
        s = fh.read()
    nl = '\r\n' if '\r\n' in s else '\n'
    m = re.search(r"^ScriptLoader\.load\(", s, re.M)
    if m:
        s = s[:m.end()] + "'MooCompat', " + s[m.end():]
    else:
        lines = s.split(nl)
        i = next(n for n, l in enumerate(lines) if l.strip() and not re.match(r'\s*(/\*\*|\*|\*/|//)', l))
        lines[i:i] = ["ScriptLoader.load('MooCompat');", '']
        s = nl.join(lines)
    with open(f, 'w', encoding='utf8', newline='') as fh:
        fh.write(s)
    print(f)
PY
git diff --stat | tail -1
for f in Filters Overlay PageList TabPane Toolbar TreeView Validator; do git diff -U1 -- "core/modules/share/scripts/$f.js" | sed -n '5,9p'; done
```
Expected: 28 файлов (23 админских и пять публичных); у семи файлов без строки зависимостей (`Filters`, `Overlay`, `PageList`, `TabPane`, `Toolbar`, `TreeView`, `Validator`) строка `ScriptLoader.load('MooCompat');` стоит перед первой строкой кода, после шапки.

- [ ] **Step 3: `core/modules/share/scripts/Energine.js` — переписать целиком**

```js
/**
 * @file Contain the description of the next objects:
 * <ul>
 *     <li>[Energine]{@link Energine}</li>
 *     <li>[ScriptLoader]{@link ScriptLoader}</li>
 * </ul>
 * Чистый JavaScript, без MooTools: файл нужен и публичным страницам, где MooTools нет.
 *
 * @author Pavel Dubenko
 * @author Valerii Zinchenko
 *
 * @version 1.2.0
 */

/**
 * Объявление зависимостей скрипта: setup scriptMap читает первый вызов в файле и пишет карту system.jsmap.php,
 * по ней документ подключает скрипты в нужном порядке. В браузере вызов ничего не делает.
 */
var ScriptLoader = {
    load: function () {
    }
};

/**
 * @namespace
 */
var Energine = /** @lends Energine */{
    /**
     * Debug flag.
     * @type {boolean}
     */
    debug: false,

    /**
     * Base URL.
     * @type {string}
     */
    base: '',

    /**
     * Static URL.
     * @type {string}
     */
    'static': '',

    /**
     * Resizer URL.
     * @type {string}
     */
    resizer: '',

    /**
     * Media URL.
     * @type {string}
     */
    media: '',

    /**
     * Root URL.
     * @type {string}
     */
    root: '',

    /**
     * Language ID.
     * @type {string}
     */
    lang: '',

    /**
     * Токен против подделки запросов; задаёт страница (document.xslt).
     * @type {string}
     */
    csrf: '',

    /**
     * Окно админки (режим single).
     * @type {boolean}
     */
    singleMode: false,

    /**
     * Translations.
     * @type {Object}
     *
     * @property {Function} [get] Get the translation.
     * @param {string} get.constant Translation ID.
     * @property {Function} [set] Set the translation.
     * @param {string} set.constant Translation ID.
     * @param {Object} set.translation Translations.
     * @property {Function} [extend] Extend the translation.
     * @param {Object} obj New translation.
     */
    translations: {
        'get': function (constant) {
            return (Energine.translations[constant] || null);
        },
        'set': function (constant, translation) {
            Energine.translations[constant] = translation;
        },
        'extend': function (obj) {
            Object.assign(Energine.translations, obj);
        }
    },

    /**
     * Force ths using of JSON.
     * @type {boolean}
     */
    forceJSON: false,

    /**
     * Support content editing.
     * @type {boolean}
     */
    supportContentEdit: true,

    /**
     * Запрос к серверу с теми же заголовками, что у прежнего запроса JSON на MooTools: X-Requested-With,
     * X-Request: JSON (по нему сервер отвечает JSON), Accept, у POST — тип тела, и токен X-CSRF-Token.
     *
     * @function
     * @static
     * @param {string} uri URI
     * @param {string|null} [body] Строка запроса.
     * @param {string} [method = 'post'] 'get' или 'post'.
     * @returns {Promise<{status: number, text: string, json: (Object|null)}>} сетевая ошибка — status 0
     */
    send: function (uri, body, method) {
        method = (method || 'post').toUpperCase();
        body = (body === null || body === undefined) ? '' : String(body);
        var headers = {'X-Requested-With': 'XMLHttpRequest', 'X-Request': 'JSON', 'Accept': 'application/json'};
        if (Energine.csrf) {
            headers['X-CSRF-Token'] = Energine.csrf;
        }
        var init = {method: method, headers: headers, credentials: 'same-origin'};
        if (method === 'GET') {
            if (body) {
                uri += ((uri.indexOf('?') === -1) ? '?' : '&') + body;
            }
        } else {
            headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=utf-8';
            init.body = body;
        }
        return fetch(uri, init).then(function (response) {
            return response.text().then(function (text) {
                var json = null;
                try {
                    json = JSON.parse(text);
                } catch (e) {
                }
                return {status: response.status, text: text, json: json};
            });
        }, function () {
            return {status: 0, text: '', json: null};
        });
    },

    /**
     * Send the request.
     *
     * @function
     * @static
     * @param {string} uri URI
     * @param {string|null} data Request.
     * @param {function} onSuccess Callback function that will be called by successful response.
     * @param {function} [onUserError] Callback function that will be called by user error.
     * @param {function} [onServerError] Callback function that will be called by server error.
     * @param {string} [method = 'post'] Request method: 'get', 'post'.
     */
    request: function (uri, data, onSuccess, onUserError, onServerError, method) {
        onServerError = onServerError || function (responseText) {
        };

        // ошибки из ответа сервера: текст для администратора
        var showErrors = function (response) {
            var msg = (typeof response.title != 'undefined')
                ? response.title
                : 'Произошла ошибка:\n';
            (response.errors || []).forEach(function (error) {
                if (typeof error.field != 'undefined') {
                    msg += error.field + " :\t";
                }
                if (typeof error.message != 'undefined') {
                    msg += error.message + "\n";
                } else {
                    msg += error + "\n";
                }
            });

            alert(msg);

            if (onUserError) {
                onUserError(response);
            }
        };

        Energine.send(uri + ((Energine.forceJSON) ? '?json' : ''), data, method).then(function (r) {
            if (r.status >= 400 || r.status === 0) {
                // отказ с объяснением в JSON (например, устаревшая форма — код 422) показывается как ошибка формы
                if (r.json && r.json.errors) {
                    showErrors(r.json);
                } else {
                    onServerError(r.text);
                    console.error('Energine.request: HTTP ' + r.status + ' ' + uri);
                }
                return;
            }
            if (!r.json) {
                onServerError(r.text);
                return;
            }
            if (r.json.result) {
                onSuccess(r.json);
            } else {
                showErrors(r.json);
            }
        });
    },

    /**
     * Resize an requested image. The attribute <tt>src</tt> of the img-tag will be build as follow:
     * <tt>Energine.resizer + r + 'w' + w + '-h' + h + '/' + src</tt>
     *
     * @function
     * @public
     * @param {HTMLImageElement} img Image, that will be resized.
     * @param {string} src Source of the original image.
     * @param {number} w Width of the new image.
     * @param {number} h Height of the new image.
     * @param {string} [r = ''] Special attribute. For example, if additional shrinking must be applied, in order to not cross requested width and height, <tt>r</tt> must be 'r'.
     *
     * @example
     * Energine.resizer = 'http://www.site.ua/resizer/';
     * Energine.resize(document.querySelector('img'), 'images/img01.png', 100, 50);
     * document.querySelector('img').getAttribute('src') == 'http://www.site.ua/resizer/w100-h50/images/img01.png'
     */
    resize: function (img, src, w, h, r) {
        if (r === undefined)
            r = '';
        img.setAttribute('src', Energine.resizer + r + 'w' + w + '-h' + h + '/' + src);
    }
};

/**
 * Compatibility fix.
 * @type {Function}
 *
 * @deprecated Use Energine.request.
 */
Energine.request.request = Energine.request;

/**
 * Скрытое поле токена для форм, которые создаёт JS (формы из XSLT получают его в шаблоне).
 *
 * @returns {HTMLInputElement}
 */
Energine.csrfInput = function () {
    var input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'csrf_token';
    input.value = Energine.csrf || '';
    return input;
};

/**
 * Local placeholder for an image of the given size: a grey SVG in a data: URL.
 * It replaced an external placeholder service (dead, and a third party saw every address).
 *
 * @param {number|string} width
 * @param {number|string} height
 * @returns {string}
 */
Energine.placeholder = function (width, height) {
    return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='" + width + "' height='" + height
        + "'%3E%3Crect width='100%25' height='100%25' fill='%23e5e5e5'/%3E%3C/svg%3E";
};

// в режиме отладки картинка ресайзера, которой нет, заменяется серой заглушкой того же размера
document.addEventListener('DOMContentLoaded', function () {
    if (!Energine.debug) {
        return;
    }
    document.querySelectorAll('img').forEach(function (image) {
        image.addEventListener('error', function () {
            var matches = /\/resizer\/w(\d*)-h(\d*)/.exec(image.getAttribute('src') || '');
            if (matches) {
                image.setAttribute('src', Energine.placeholder(matches[1], matches[2]));
            }
        });
    });
});
```

- [ ] **Step 4: `document.xslt` — `Object.assign` и `DOMContentLoaded`**

В `core/modules/share/transformers/document.xslt`: `Object.append(Energine, {` → `Object.assign(Energine, {`; `window.addEvent('domready', function () {` → `document.addEventListener('DOMContentLoaded', function () {`.

- [ ] **Step 5: Порядок запуска — увидеть провал**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
for f in $(git ls-files 'core/*.js' 'site/*.js' | grep -v -E '/scripts/(jodit/|mootools)') core/modules/share/scripts/MooCompat.js; do node --check "$f" || echo "BAD $f"; done
php8.5 -r '$d = new DOMDocument(); exit($d->load("core/modules/share/transformers/document.xslt") ? 0 : 1);' && echo xml-ok
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js' > "$L/t2-grids-red.log" 2>&1; echo "grids exit $?"; grep -E '^FAIL' "$L/t2-grids-red.log"; cd ../..
```
Expected: синтаксис без ошибок; `grids` — выход 1, провал «грид пользователей: панель привязана к гриду» (встроенный скрипт панели на `domready` MooTools запустился раньше грида); проверки `Energine.request` (заголовки, тело, отказ 422) — OK.

- [ ] **Step 6: `toolbar.xslt` и `file.xslt` — панель запускается после поведений страницы**

В `core/modules/share/transformers/toolbar.xslt` (шаблон `toolbar[parent::component[@exttype='grid']]`) строку `$(window).addEvent('domready', function(){` и в `core/modules/share/transformers/file.xslt` (шаблон `toolbar[parent::component[@class='ImageManager']]`) строку `window.addEvent('domready', function(){` заменить на:
```
document.addEventListener('DOMContentLoaded', function(){
```
а над `<script type="text/javascript">` каждого из двух шаблонов добавить комментарий:
```xml
        <!-- панель привязывается к гриду, которого нет до запуска поведений страницы (document.xslt): оба запуска
             ждут DOMContentLoaded, и этот, объявленный ниже в документе, идёт вторым -->
```

- [ ] **Step 7: Проверить всё на стенде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
for x in toolbar file; do php8.5 -r '$d = new DOMDocument(); exit($d->load("core/modules/share/transformers/'"$x"'.xslt") ? 0 : 1);' && echo "$x xml-ok"; done
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t2-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t2-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in grids editors crawl theme public; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t2-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t2-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t2-$t.log" | head -25; done; cd ../..
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools > "$L/t2-no-traces.log" 2>&1; echo "no-traces $?"; head -12 "$L/t2-no-traces.log"
```
Expected: регрессия — выход 0, 17 наборов без провалов; `grids`, `editors`, `crawl`, `theme` — выход 0; `public` — те же провалы, что в задаче 1 (MooTools грузится всегда, версий нет, «+» в логине); `no-traces code mootools` — выход 1, только конструкции MooTools в пяти ещё не переписанных публичных файлах (первая зависимость `MooCompat` — у всех остальных).

- [ ] **Step 8: Commit**

```bash
git add core/modules/share/scripts core/modules/user/scripts core/modules/share/transformers/document.xslt core/modules/share/transformers/toolbar.xslt core/modules/share/transformers/file.xslt
bash tests/tools/stand.sh run git commit -q -m "Этап 8: Energine.js на чистом JavaScript, MooCompat.js — мост к MooTools для админки, запуск поведений и панелей на DOMContentLoaded" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Формы сайта на чистом JavaScript

**Files:**
- Modify (переписать целиком): `core/modules/share/scripts/Validator.js`, `core/modules/share/scripts/ValidForm.js`, `core/modules/user/scripts/LoginForm.js`, `core/modules/user/scripts/Register.js`, `core/modules/user/scripts/UserProfile.js`
- Modify: `core/modules/share/scripts/FileRepoForm.js` (`uploadFailed` — причина отказа текстом, без экранирования)

**Interfaces:**
- Consumes: `Energine.send` (задача 2); проверки `public.js` и `editors.js` (задача 1).
- Produces: `Validator(form, tabPane)` с методами `validate()`, `validateElement(field)`, `showError(field, message)` (текст, не разметка), `removeError(field)`, `clearErrors()`, `scrollToElement(field)`, `prepareFloatFields()`; `ValidForm(element)` — поля `element`, `form`, `singlePath`, `validator`, метод `validateForm(event)`.

- [ ] **Step 1: `Validator.js`**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Validator]{@link Validator}</li>
 * </ul>
 * Чистый JavaScript, без MooTools: проверяет и формы сайта, и формы админки.
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

/**
 * Validator: правило поля — атрибуты nrgn:pattern (выражение /…/флаги) и nrgn:message (текст ошибки).
 *
 * @constructor
 * @param {Element|string} form Form element.
 * @param {TabPane} [tabPane] Вкладки формы админки: поле с ошибкой на закрытой вкладке её открывает.
 */
var Validator = class Validator {
    constructor(form, tabPane) {
        this.form = (typeof form === 'string') ? document.getElementById(form) : form;
        this.tabPane = tabPane || null;
        this.prepareFloatFields();
    }

    // поля дробных чисел (класс float): запятая заменяется точкой
    prepareFloatFields() {
        this.form.querySelectorAll('.float').forEach((element) => {
            element.removeEventListener('change', Validator.commaToPoint);
            element.addEventListener('change', Validator.commaToPoint);
        });
    }

    static commaToPoint(event) {
        event.target.value = event.target.value.replace(/,/, '.');
    }

    removeError(field) {
        if (!field.classList.contains('invalid')) {
            return;
        }
        field.classList.remove('invalid');
        const box = field.closest('.field');
        const error = box && box.querySelector('div.error');
        if (error) {
            error.remove();
        }
    }

    clearErrors() {
        this.form.querySelectorAll('.invalid').forEach((field) => this.removeError(field));
    }

    // текст ошибки — текстом, не разметкой: в переводах, которые сюда попадают, разметки нет
    showError(field, message) {
        this.removeError(field);
        field.classList.add('invalid');
        const error = document.createElement('div');
        error.className = 'error';
        error.textContent = (message === null || message === undefined) ? '' : String(message);
        error.addEventListener('click', () => this.removeError(field));
        field.parentNode.after(error);
    }

    scrollToElement(field) {
        field.scrollIntoView({behavior: 'smooth', block: 'center'});
        try {
            field.focus({preventScroll: true});
        } catch (e) {
            console.warn(e);
        }
    }

    validateElement(field) {
        const pattern = field.getAttribute('nrgn:pattern');
        const message = field.getAttribute('nrgn:message');
        if (!pattern || !message || field.disabled || field.classList.contains('novalidation')) {
            return true;
        }
        const parts = pattern.split('/');
        if (new RegExp(parts[1], parts[2]).test(field.value)) {
            this.removeError(field);
            return true;
        }
        this.showError(field, message);
        // после первой ошибки поле проверяется при уходе с него, а ввод убирает ошибку
        if (!field.getAttribute('check')) {
            field.addEventListener('blur', () => this.validateElement(field));
            field.addEventListener('keydown', () => this.removeError(field));
            field.setAttribute('check', 'check');
        }
        return false;
    }

    validate() {
        let first = null;
        for (const field of [...this.form.elements]) {
            if (!this.validateElement(field) && !first) {
                first = field;
            }
        }
        if (first) {
            if (this.tabPane) {
                this.tabPane.show(this.tabPane.whereIs(first));
            }
            this.scrollToElement(first);
        }
        return !first;
    }
};
```

- [ ] **Step 2: Текст с `<` и `&` — увидеть провал**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
node --check core/modules/share/scripts/Validator.js
cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node editors.js' > "$L/t3-editors-red.log" 2>&1; echo "editors exit $?"; grep -E '^FAIL' "$L/t3-editors-red.log"; cd ../..
```
Expected: `editors` — выход 1, единственный провал «причина отказа с «<» и «&» — как есть, текстом» (`FileRepoForm` экранирует, `Validator` выводит текст: видно `&lt;b&gt;`); шаг 13 (вкладки) — OK.

- [ ] **Step 3: `FileRepoForm.js` — причина отказа текстом**

В `core/modules/share/scripts/FileRepoForm.js` комментарий и начало `uploadFailed`:
```js
    /**
     * Загрузка не состоялась: причина у поля (Validator выводит её текстом), а форма забывает файл:
     * превью и путь прошлой загрузки сбрасываются, тот же файл можно выбрать снова.
     *
     * @param {Element} field поле файла
     * @param {string} message
     */
    uploadFailed: function (field, message) {
        this.validator.showError(field, String(message));
```
(строки `this.validator.showError(field, String(message)` и `.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'));` → одна строка выше).

- [ ] **Step 4: `ValidForm.js`**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[ValidForm]{@link ValidForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires Validator
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('Validator');

/**
 * Форма сайта, которая проверяется перед отправкой.
 *
 * @constructor
 * @param {Element|string} element Форма или элемент внутри неё (id).
 */
var ValidForm = class ValidForm {
    constructor(element) {
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        if (!this.element) {
            return;
        }
        this.form = (this.element.tagName === 'FORM') ? this.element : this.element.closest('form');
        if (!this.form) {
            return;
        }
        this.singlePath = this.element.getAttribute('single_template');
        this.form.classList.add('form');
        this.form.addEventListener('submit', (event) => this.validateForm(event));
        this.validator = new Validator(this.form);
    }

    validateForm(event) {
        if (!this.validator.validate()) {
            event.preventDefault();
            return false;
        }
        return true;
    }
};
```

- [ ] **Step 5: `LoginForm.js`**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[LoginForm]{@link LoginForm}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/Energine
 * @requires share/ValidForm
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */
ScriptLoader.load('ValidForm');

/**
 * Форма входа: поля проверяются перед отправкой.
 */
var LoginForm = class LoginForm extends ValidForm {
};
```

- [ ] **Step 6: `Register.js`**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Register]{@link Register}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/ValidForm
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('ValidForm');

/**
 * Регистрация: логин (e-mail) проверяется на занятость, когда посетитель уходит с поля; пока логин неверен или
 * занят, кнопка регистрации выключена.
 *
 * @constructor
 * @param {Element|string} element
 */
var Register = class Register extends ValidForm {
    constructor(element) {
        super(element);
        if (!this.form) {
            return;
        }
        this.registerButton = this.form.querySelector('button[name=register]');
        this.loginField = this.form.querySelector('#u_name');
        if (!this.loginField) {
            return;
        }
        this.loginField.addEventListener('blur', (event) => {
            if (!event.target.value) {
                return;
            }
            if (this.validator.validateElement(event.target)) {
                this.checkLogin(this.loginField.value);
            } else {
                this.disableRegistration();
            }
        });
    }

    disableRegistration() {
        if (this.registerButton) {
            this.registerButton.disabled = true;
        }
    }

    // логин уходит закодированным: «+» и «&» доходят до сервера как есть
    checkLogin(login) {
        Energine.send(this.singlePath + 'check/', 'login=' + encodeURIComponent(login)).then((r) => {
            if (r.status < 200 || r.status >= 300 || !r.json) {
                return;
            }
            if (!r.json.result) {
                this.validator.showError(this.loginField, r.json.message || '');
                this.disableRegistration();
            } else if (this.registerButton) {
                this.registerButton.disabled = false;
            }
        });
    }
};
```

- [ ] **Step 7: `UserProfile.js`**

```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[UserProfile]{@link UserProfile}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/Energine
 * @requires share/ValidForm
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('ValidForm');

/**
 * Профиль посетителя: новый пароль и повтор должны совпадать (текст ошибки — nrgn:message2 поля пароля).
 *
 * @constructor
 * @param {Element|string} element
 */
var UserProfile = class UserProfile extends ValidForm {
    validateForm(event) {
        const field = document.getElementById('u_password');
        const field2 = document.getElementById('u_password2');
        if (field && field2 && field.value !== field2.value) {
            this.validator.showError(field, field.getAttribute('nrgn:message2'));
            event.preventDefault();
            event.stopPropagation();
            return false;
        }
        return super.validateForm(event);
    }
};
```

- [ ] **Step 8: Пересобрать стенд (карта скриптов без временных объявлений) и проверить**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
for f in core/modules/share/scripts/Validator.js core/modules/share/scripts/ValidForm.js core/modules/user/scripts/LoginForm.js core/modules/user/scripts/Register.js core/modules/user/scripts/UserProfile.js core/modules/share/scripts/FileRepoForm.js; do node --check "$f" || echo "BAD $f"; done
bash tests/tools/stand.sh run bash tests/no-traces.sh code mootools; echo "no-traces $?"
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t3-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t3-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in public editors grids crawl theme; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t3-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t3-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t3-$t.log" | head -25; done; cd ../..
```
Expected: `no-traces code mootools` — выход 0; регрессия — выход 0; `public` — остались только провалы «MooTools не запрашивается» и «с версией ?v=» (их закрывает задача 4), вход, регистрация (с «+») и профиль — OK; `editors`, `grids`, `crawl`, `theme` — выход 0.

- [ ] **Step 9: Commit**

```bash
git add core/modules/share/scripts/Validator.js core/modules/share/scripts/ValidForm.js core/modules/user/scripts/LoginForm.js core/modules/user/scripts/Register.js core/modules/user/scripts/UserProfile.js core/modules/share/scripts/FileRepoForm.js
bash tests/tools/stand.sh run git commit -q -m "Этап 8: формы сайта на чистом JavaScript — Validator, ValidForm, вход, регистрация, профиль" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: MooTools — только по зависимости, версии скриптов

**Files:**
- Modify: `core/modules/share/scripts/MooCompat.js` (зависимость `mootools.min`), `core/modules/share/gears/Document.php:330-371` (без атрибута `mootools` и `site.js-lib`; версии), `core/modules/share/transformers/document.xslt` (без `<script>` MooTools; `?v=`), `configs/system.config.default.php` (без примера `js-lib`)

**Interfaces:**
- Consumes: первая зависимость `MooCompat` (задача 2), формы на чистом JavaScript (задача 3).
- Produces: у элемента `/document/javascript` — атрибут `energine-version`; у каждого `library` — атрибут `version` (время изменения файла скрипта; пусто — файла нет).

- [ ] **Step 1: `MooCompat.js`** — после шапки (`*/` первого комментария) вставить пустую строку и `ScriptLoader.load('mootools.min');`.

- [ ] **Step 2: `Document.php`** — блок от `$jsLibs = Primitive::getConfigValue('site.js-lib');` до `$dom_root->appendChild($dom_javascript);` заменить на:

```php
        // MooTools — обычная библиотека в карте зависимостей: её объявляет MooCompat, а его — скрипты на MooTools
        $dom_javascript = $this->doc->createElement('javascript');
        // версия в адресе скрипта — время изменения файла: после обновления браузер не возьмёт из кэша прежний файл
        $scriptVersion = function ($path) {
            $file = HTDOCS_DIR . '/scripts/' . $path . '.js';
            return is_file($file) ? (string)filemtime($file) : '';
        };
        $dom_javascript->setAttribute('energine-version', $scriptVersion('Energine'));
        $dom_root->appendChild($dom_javascript);
```
и в цикле `foreach ($jsIncludes as $js)` после `$dom_js_library->setAttribute('path', $js);` добавить:
```php
            $dom_js_library->setAttribute('version', $scriptVersion($js));
```

- [ ] **Step 3: `document.xslt`** — удалить строку `<script type="text/javascript" src="{/document/javascript/@mootools}"></script>`; строку `Energine.js` заменить на `<script type="text/javascript" src="{$STATIC_URL}scripts/Energine.js?v={/document/javascript/@energine-version}"></script>`; в шаблоне `match="/document/javascript/library" mode="head"` — `<script type="text/javascript" src="{$STATIC_URL}scripts/{@path}.js?v={@version}"/>`.

- [ ] **Step 4: `configs/system.config.default.php`** — удалить закомментированный пример (три строки):
```php
        /*'js-lib' => [
            'mootools' => /*$staticURL*//*'scripts/mootools.min.js'
        ]*/
```

- [ ] **Step 5: Пересобрать стенд и проверить всё**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
php8.5 -l core/modules/share/gears/Document.php && php8.5 -l configs/system.config.default.php && node --check core/modules/share/scripts/MooCompat.js
php8.5 -r '$d = new DOMDocument(); exit($d->load("core/modules/share/transformers/document.xslt") ? 0 : 1);' && echo xml-ok
git grep -n "js-lib\|@mootools" -- core configs setup htdocs docs/INSTALL.md README.md || echo "no js-lib"
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
php8.5 -r '$m = include "/tmp/stand-web97/site/web/system.jsmap.php"; echo json_encode($m["MooCompat"] ?? null), "\n";'
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/t4-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/t4-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in public grids editors theme crawl; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/t4-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/t4-$t.log" 2>&1; echo "$t exit $?"; grep -E '^FAIL' "$L/t4-$t.log" | head -10; done; cd ../..
bash tests/tools/stand.sh run bash tests/no-traces.sh; echo "no-traces $?"
```
Expected: синтаксис без ошибок; `no js-lib`; карта: `MooCompat` → `["mootools.min"]`; регрессия — выход 0; `public` — выход 0 (MooTools у посетителя нет, у скриптов `?v=`); `grids`, `editors`, `theme`, `crawl` — выход 0 (админке MooTools приходит по зависимости); `no-traces` — выход 0.

- [ ] **Step 6: Commit**

```bash
git add core/modules/share/scripts/MooCompat.js core/modules/share/gears/Document.php core/modules/share/transformers/document.xslt configs/system.config.default.php
bash tests/tools/stand.sh run git commit -q -m "Этап 8: MooTools — только по зависимости скриптов админки, версии в адресах скриптов" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Документы и итоговая проверка на стенде

**Files:**
- Modify: `README.md`, `tests/README.md`

- [ ] **Step 1: `README.md`** — после абзаца «Сейчас **этап 7 — чистое ядро**…» добавить абзац:

```markdown
Этап 8 — переход с MooTools 1.5.2 на чистый JavaScript, файл за файлом, без изменений на сервере
(`docs/superpowers/specs/2026-10-02-energine-simple-stage8-public-without-mootools-design.md`). Шаг 1 сделан:
публичные страницы — без MooTools, общий `Energine.js` и формы сайта (`Validator`, вход, регистрация, профиль) —
на чистом JavaScript с прежним интерфейсом. Скрипты админки пока на MooTools: каждый объявляет первой зависимостью
`MooCompat` (заплатки к MooTools), и документ подключает MooTools только страницам с такими скриптами; следующие шаги
переписывают админку и снимают объявления. Адрес каждого скрипта несёт версию (`?v=` — время изменения файла).
```
и в список спецификаций внизу — строку `` `docs/superpowers/specs/2026-10-02-energine-simple-stage8-public-without-mootools-design.md` (этап 8) ``.

- [ ] **Step 2: `tests/README.md`** — после раздела «Тема» добавить раздел «Публичные страницы без MooTools»: команда запуска (как у прочих аудитов, `node public.js`) и абзац:

```markdown
`public.js` (этап 8) открывает гостем и временным посетителем (`public-db.php`, логин с «+») главную, вход,
регистрацию, восстановление пароля, карту сайта и профиль на двух языках: MooTools не запрашивается и не
определена, у скриптов сайта версия `?v=`, ошибок JS и ответов 400+ нет. Формы: пустая форма входа не уходит, у
полей ошибки, с данными посетителя вход выполнен; в регистрации неверный e-mail отмечен, занятый логин (с «+») —
ошибка и выключенная кнопка, свободный — кнопка включена; в профиле разные новый пароль и повтор — ошибка у поля,
форма не уходит. Посетитель удаляется.
```
В раздел «Гриды админки» дописать: «Запросы админки (`Energine.request`): заголовки и тело — как у прежнего запроса MooTools, отказ сервера (чужой токен, 422) — текст отказа и обработчик ошибки формы; панель грида привязана к гриду.» В раздел «Редакторы и загрузка» — пункты «причина отказа загрузки с `<` и `&` — как есть, текстом» и «форма с вкладками: пустое обязательное поле на неоткрытой вкладке — форма не уходит, вкладка открывается, у поля ошибка». В раздел «Инструменты чистки» (о `no-traces.sh`) — категорию `mootools` (этап 8): в файлах из `VANILLA_JS` нет конструкций MooTools, у остальных скриптов первая зависимость — `MooCompat`.

- [ ] **Step 3: Итоговая проверка на чистом стенде**

```bash
L=$PWD/.superpowers/sdd/2026-10-02-energine-simple-stage8-public-without-mootools
bash tests/tools/stand.sh stop && STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start
bash tests/tools/stand.sh run bash tests/no-traces.sh all > "$L/final-no-traces.log" 2>&1; echo "no-traces $?"
bash tests/tools/stand.sh run bash tests/tools/install-check.sh > "$L/final-install.log" 2>&1; echo "install $?"
bash tests/tools/stand.sh run bash tests/regression.sh > "$L/final-regression.log" 2>&1; echo "regression $?"; grep -E '^(FAIL|== )' "$L/final-regression.log" | grep -v ' failures: 0$' | head
cd tests/audit && for t in public grids editors theme crawl; do case $t in crawl) a="crawl-guest.txt crawl-admin.txt crawl-singles.txt $L/final-crawl.json";; *) a='';; esac; bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '"$t"'.js '"$a" > "$L/final-$t.log" 2>&1; echo "$t exit $?"; done; cd ../..
bash tests/tools/stand.sh run bash tests/tools/fresh-check.sh > "$L/final-fresh.log" 2>&1; echo "fresh $?"
```
Expected: всё — выход 0.

- [ ] **Step 4: Вес публичной страницы** — сумма размеров скриптов главной до (`5cd2be2f`) и после — в отчёт:
```bash
for c in 5cd2be2f HEAD; do t=0; for f in core/modules/share/scripts/mootools.min.js core/modules/share/scripts/Energine.js core/modules/share/scripts/Validator.js core/modules/share/scripts/ValidForm.js core/modules/user/scripts/LoginForm.js; do [ $c = HEAD ] && [ "${f##*/}" = mootools.min.js ] && continue; s=$(git cat-file -s "$c:$f"); t=$((t + s)); done; echo "$c $t"; done
```

- [ ] **Step 5: Commit**

```bash
git add README.md tests/README.md
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 1: документы" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Выкладка на simple.energine.org

Требует отдельного «да» владельца. База не меняется.

- [ ] **Step 1: Точка отката** — `git -C /var/www/clients/client1/web97/private/energine rev-parse HEAD` в `private/backup/stage8-<дата>/live-HEAD`; в конфиге площадки нет `js-lib` (`grep -c js-lib` — только число, содержимое не печатается).
- [ ] **Step 2: Код** — от имени web97: `git -C <живое дерево> fetch <клон> main && git -C <живое дерево> merge --ff-only FETCH_HEAD`.
- [ ] **Step 3: Статика** — в `web/` от web97: `php8.5 index.php setup linker && php8.5 index.php setup scriptMap` (новый `MooCompat.js` — ссылкой, карта — с `MooCompat`).
- [ ] **Step 4: Проверка** — главная, вход, регистрация гостем: `mootools.min.js` не запрашивается, скрипты с `?v=`; регрессию и аудиты (`public`, `grids`, `editors`, `theme`, `crawl`) на площадке запускает владелец (`!`).
- [ ] **Step 5: Откат при провале** — от web97 `git reset --hard <live-HEAD>`, `setup linker && setup scriptMap`.
