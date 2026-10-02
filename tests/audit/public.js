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
            check('вход: без ошибок JS', !log.errors.length, log.errors.join(' | '));
            // the page after login is the address the form returns to (built from the host: on the stand without its
            // port) — not checked here; the profile below opens only to a signed-in visitor
            // typed, as a person does: a key in a field with an error removes the error at once (fill() presses no
            // keys, the error would go only when the field is left — and the button would move under the click)
            await p.locator('#username').pressSequentially(visitor.login);
            await p.locator('#password').pressSequentially(visitor.password);
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('button[name="user[login]"]')]);
            await p.close();
        }

        // 3. the visitor's pages in both languages (the profile is open only to a signed-in visitor)
        for (const url of ['', 'login/', 'register/', 'restore-password/', 'sitemap/', 'profile/',
            'ua/', 'ua/login/', 'ua/register/', 'ua/restore-password/', 'ua/sitemap/', 'ua/profile/']) {
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
