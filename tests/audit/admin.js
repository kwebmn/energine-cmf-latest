// Аудит вида админки (UI-подпроект 3): стили админки — admin.css (Tailwind, утилиты с префиксом a:), значки — спрайт
// images/icons.svg; старые файлы стилей и картинок не запрашиваются. Снимки экранов — в SHOTS.
// BASELINE=1 — только снимки (опора «до» для сравнения), без проверок.
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node admin.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');
const os = require('os');
const path = require('path');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const SHOTS = process.env.SHOTS || fs.mkdtempSync(path.join(os.tmpdir(), 'admin-'));
const BASELINE = process.env.BASELINE === '1';
const ICONS = ['add', 'edit', 'delete', 'up', 'down', 'save', 'close', 'list', 'search', 'filter', 'sort-asc', 'sort-desc',
    'prev', 'next', 'folder', 'file', 'image', 'upload', 'eye', 'gear', 'check'];
let fail = 0;
function check(label, cond, detail = '') {
    console.log((cond ? 'OK   ' : 'FAIL ') + label + (cond ? '' : ': ' + String(detail).replace(/\s+/g, ' ').slice(0, 300)));
    if (!cond) fail++;
    return cond;
}
// запросы страницы к стилям и картинкам ядра (имена файлов) и ошибки JS/404
function watch(page) {
    const log = { css: [], images: [], errors: [] };
    page.on('request', (r) => {
        const u = r.url();
        if (/\.css(\?|$)/.test(u)) log.css.push(u.replace(/\?.*$/, '').split('/').pop());
        if (/\/images\/|templates\/icons\//.test(u)) log.images.push(u.replace(/\?.*$/, '').replace(/^.*?\/(images|templates)\//, '$1/'));
    });
    page.on('pageerror', (e) => log.errors.push('pageerror: ' + e.message));
    page.on('response', (r) => { if (r.status() >= 400) log.errors.push(`http ${r.status()}: ${r.url()}`); });
    return log;
}
const shot = (page, name) => page.screenshot({ path: path.join(SHOTS, name + '.png'), fullPage: true });

// экраны админки: адрес, что сделать после загрузки (необязательно)
const SCREENS = [
    ['страница', 'info/quick-start/'],
    ['режим-правки', 'info/quick-start/', async (p) => {
        await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
    }],
    ['пользователи', 'admin/users/'],
    ['переводы', 'admin/translations/'],
    ['шаблоны-писем', 'admin/mail-templates/'],
    ['журнал', 'admin/action-log/'],
    ['структура', 'admin/structure/'],
    ['настройки', 'admin/settings/'],
    ['форма-пользователя', 'admin/users/single/userEditor/add/'],
    ['форма-письма', 'admin/mail-templates/single/mailTemplateEditor/1/edit/'],
    ['файлы', 'admin/users/single/adminPanel/file-library/'],
    ['форма-файла', 'admin/users/single/adminPanel/file-library/1/add/'],
];

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    const ctx = await browser.newContext({ locale: 'ru-RU' });
    const lp = await ctx.newPage();
    await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
    await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
    await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
    await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
    await lp.close();

    // снимки всех экранов на 1280 и 800; в обычном режиме — ещё и общие проверки экрана
    const seen = {};
    for (const [name, url, act] of SCREENS) {
        for (const w of [1280, 800]) {
            const p = await ctx.newPage();
            await p.setViewportSize({ width: w, height: 900 });
            const log = watch(p);
            await p.goto(BASE + url, { waitUntil: 'networkidle' });
            if (act) await act(p);
            await p.waitForTimeout(700);
            await shot(p, `${name}-${w}`);
            seen[`${name}-${w}`] = log;
            if (!BASELINE) {
                check(`${name}, ${w}px: admin.css загружен`, log.css.includes('admin.css'), log.css.join(' '));
                check(`${name}, ${w}px: без ошибок JS и 404`, !log.errors.length, log.errors.join(' | '));
            }
            await p.close();
        }
    }

    if (!BASELINE) {
        // гостю стили админки не нужны
        const guest = await browser.newContext({ locale: 'ru-RU' });
        const gp = await guest.newPage();
        const glog = watch(gp);
        await gp.goto(BASE + 'info/quick-start/', { waitUntil: 'networkidle' });
        check('гость: admin.css не загружается', !glog.css.includes('admin.css'), glog.css.join(' '));
        await guest.close();

        // значки: спрайт и Energine.icon
        const p = await ctx.newPage();
        await p.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
        const sprite = await p.request.get(BASE + 'images/icons.svg');
        const body = sprite.ok() ? await sprite.text() : '';
        const missing = ICONS.filter((n) => !new RegExp(`<symbol[^>]+id="${n}"`).test(body));
        check('спрайт значков: отвечает 200, все значки на месте', sprite.status() === 200 && !missing.length, `${sprite.status()} нет: ${missing.join(' ')}`);
        check('спрайт значков: без внешних ссылок', !/https?:\/\/(?!www\.w3\.org)/.test(body));
        const icon = await p.evaluate(async () => {
            const { Energine } = await import(document.querySelector('script[type="importmap"]')
                ? JSON.parse(document.querySelector('script[type="importmap"]').textContent).imports.Energine : '');
            const d = document.createElement('div');
            d.innerHTML = Energine.icon('add');
            const use = d.querySelector('svg use');
            return { html: d.innerHTML, href: use && use.getAttribute('href'), hidden: d.firstElementChild && d.firstElementChild.getAttribute('aria-hidden') };
        }).catch((e) => ({ error: e.message }));
        check('Energine.icon: svg > use со ссылкой на значок в спрайте', !!icon.href && /images\/icons\.svg#add$/.test(icon.href) && icon.hidden === 'true',
            JSON.stringify(icon));
        await p.close();
    }

    await browser.close();
    console.log(`screenshots: ${SHOTS}`);
    if (!BASELINE) console.log(`== admin failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); process.exit(1); });
