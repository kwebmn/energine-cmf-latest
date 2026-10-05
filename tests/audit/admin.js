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
// старые файлы стилей и картинок админки, удалённые подпроектом: страница их не запрашивает
const GONE_CSS = ['modalbox.css', 'form.css', 'controls.css', 'tabpane.css'];
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
                const old = log.css.filter((f) => GONE_CSS.includes(f));
                check(`${name}, ${w}px: удалённые стили не запрашиваются`, !old.length, old.join(' '));
                const over = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth).catch(() => 0);
                check(`${name}, ${w}px: без горизонтальной прокрутки страницы`, over <= 0, `лишние ${over} px`);
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

        // окна и формы: окно формы поверх грида, вкладки, поле с ошибкой проверки, окно в окне
        for (const w of [1280, 800]) {
            const p = await ctx.newPage();
            await p.setViewportSize({ width: w, height: 900 });
            await p.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            const open = (url) => p.evaluate((u) => window.top.ModalBox.open({ url: u }), url);
            await open(BASE + 'admin/users/single/userEditor/add/');
            await p.waitForTimeout(2500);
            const box = await p.evaluate(() => {
                const b = document.querySelector('.e-modalbox'); const cs = b && getComputedStyle(b);
                const r = b && b.getBoundingClientRect();
                return b && { position: cs.position, z: +cs.zIndex, shadow: cs.boxShadow !== 'none', radius: parseFloat(cs.borderTopLeftRadius),
                    inView: r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight, frame: getComputedStyle(b.querySelector('iframe')).borderTopWidth };
            });
            check(`окно формы, ${w}px: поверх страницы, в пределах окна, рамка и тень`, !!box && box.position === 'fixed' && box.z > 1000 && box.shadow
                && box.radius > 0 && box.inView && box.frame === '0px', JSON.stringify(box));
            const f = p.frameLocator('.e-modalbox iframe').first();
            const tabs = await f.locator('ul.e-tabs').evaluate((ul) => {
                const cur = ul.querySelector('li.current'); const other = ul.querySelector('li:not(.current)');
                const cs = (e) => e && getComputedStyle(e);
                return { cur: !!cur, curBorder: cur && cs(cur).borderBottomWidth, curWeight: cur && cs(cur).fontWeight,
                    otherBorder: other ? cs(other).borderBottomColor : 'нет', curColor: cur && cs(cur).borderBottomColor, link: cur && cs(cur.querySelector('a')).color };
            }).catch((e) => ({ error: e.message }));
            check(`окно формы, ${w}px: текущая вкладка выделена линией снизу`, tabs.cur && parseFloat(tabs.curBorder) >= 2
                && (tabs.otherBorder === 'нет' || tabs.otherBorder !== tabs.curColor), JSON.stringify(tabs));
            // Tab доходит до вкладки, фокус виден
            const tabFocus = await f.locator('ul.e-tabs li a').first().evaluate((a) => {
                a.focus(); const cs = getComputedStyle(a); return { focused: document.activeElement === a, outline: cs.outlineStyle !== 'none' || cs.boxShadow !== 'none' };
            }).catch((e) => ({ error: e.message }));
            check(`окно формы, ${w}px: вкладка получает фокус, фокус виден`, tabFocus.focused && tabFocus.outline, JSON.stringify(tabFocus));
            // поле: подпись над/слева, рамка поля, ошибка проверки — цвет --danger
            const field = await f.locator('form').evaluate((form) => {
                const input = form.querySelector('.field input[type=text], .field input[type=email], .field input:not([type])');
                const cs = getComputedStyle(input);
                input.classList.add('invalid');
                const inv = getComputedStyle(input).borderBottomColor;
                input.classList.remove('invalid');
                return { border: cs.borderBottomWidth, radius: parseFloat(cs.borderTopLeftRadius), font: cs.fontFamily, invalid: inv };
            }).catch((e) => ({ error: e.message }));
            check(`окно формы, ${w}px: поле в рамке со скруглением, шрифт системный, ошибка — красная рамка`,
                parseFloat(field.border) >= 1 && field.radius > 0 && /system-ui/.test(field.font) && field.invalid === 'rgb(179, 38, 30)', JSON.stringify(field));
            // окно в окне: второе окно поверх первого, закрытие верхнего оставляет нижнее
            await open(BASE + 'admin/users/single/adminPanel/file-library/');
            await p.waitForTimeout(2500);
            const stack = await p.evaluate(() => {
                const boxes = [...document.querySelectorAll('.e-modalbox')];
                const r = boxes[1] && boxes[1].getBoundingClientRect();
                const top = r && document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
                return { n: boxes.length, topIsSecond: !!top && boxes[1].contains(top) };
            });
            await p.evaluate(() => window.top.ModalBox.close());
            await p.waitForTimeout(500);
            const left = await p.evaluate(() => document.querySelectorAll('.e-modalbox').length);
            check(`окно в окне, ${w}px: верхнее окно выше нижнего, закрытие верхнего оставляет нижнее`, stack.n === 2 && stack.topIsSecond && left === 1,
                JSON.stringify({ ...stack, left }));
            await shot(p, `окно-формы-${w}`);
            await p.close();
        }

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
