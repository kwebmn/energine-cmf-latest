// Browser test of the site theme (stage 5c): every page type on a phone (390 px) and a desktop (1280 px).
// Checks what a visitor gets: no horizontal scrolling, content first (main before aside), one h1, a
// skip link to #content, a menu that folds on the phone and is open on the desktop, a visible focus,
// a dark scheme, and nothing loaded from other hosts, no 404 and no JS errors.
// Screenshots go to SHOTS (default: a temporary directory, printed at the end).
// Run in a subshell, like crawl.js:
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node theme.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const HOST = new URL(BASE).host;
const SHOTS = process.env.SHOTS || fs.mkdtempSync(path.join(os.tmpdir(), 'theme-'));
let fail = 0;
function check(label, cond, detail = '') {
    console.log((cond ? 'OK   ' : 'FAIL ') + label + (cond ? '' : ': ' + String(detail).replace(/\s+/g, ' ').slice(0, 300)));
    if (!cond) fail++;
    return cond;
}
const PAGES = [
    ['главная', ''], ['текстовая', 'features/content/'], ['подразделы', 'features/'], ['лента новостей', 'news/'],
    ['новость', null], ['галерея', 'media/'], ['обратная связь', 'contacts/'], ['карта сайта', 'sitemap/'],
    ['вход', 'login/'], ['регистрация', 'register/'], ['восстановление пароля', 'restore-password/'],
    ['профиль', 'profile/', 'user'], ['404', 'claude-no-such-page/', null, 404],
];

async function inspect(page) {
    return page.evaluate(() => {
        const main = document.querySelector('main');
        const aside = document.querySelector('aside');
        const skip = document.querySelector('a.skip-link');
        const menu = document.querySelector('nav.site-nav details.site-menu');
        const menuLink = menu && menu.querySelector('ul a');
        return {
            overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth,
            main: !!main && main.id === 'content',
            mainFirst: !aside || !main || !!(main.compareDocumentPosition(aside) & Node.DOCUMENT_POSITION_FOLLOWING),
            h1: document.querySelectorAll('h1').length,
            skip: !!skip && skip.getAttribute('href') === '#content',
            menu: !!menu,
            // inside a closed <details> the box still has a size: checkVisibility honours content-visibility
            menuLinkVisible: !!menuLink && menuLink.checkVisibility(),
            bg: getComputedStyle(document.body).backgroundColor,
        };
    });
}

(async () => {
    const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--no-sandbox'] });
    // a signed-in visitor for the profile page: a temporary user of the registered group (theme-db.php)
    const db = (...args) => execFileSync('php8.5', [path.join(__dirname, 'theme-db.php'), ...args], { encoding: 'utf8' });
    db('user-remove');
    const visitor = JSON.parse(db('user-add'));
    process.on('exit', () => { try { db('user-remove'); } catch (e) { } });
    const user = await browser.newContext({ locale: 'ru-RU' });
    {
        const lp = await user.newPage();
        await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
        await lp.fill('input[name="user[username]"]', visitor.login);
        await lp.fill('input[name="user[password]"]', visitor.password);
        await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
        await lp.close();
    }
    const guest = await browser.newContext({ locale: 'ru-RU' });
    {
        const p = await guest.newPage();
        await p.goto(BASE + 'news/', { waitUntil: 'networkidle' });
        const href = await p.evaluate(() => {
            const a = [...document.querySelectorAll('a[href]')].find((x) => /\/\d+--[^/]+\/$/.test(x.getAttribute('href')));
            return a ? a.getAttribute('href') : null;
        });
        PAGES.find((x) => x[0] === 'новость')[1] = href ? href.replace(/^\//, '').replace(BASE, '') : 'news/';
        await p.close();
    }

    for (const [label, url, who, status] of PAGES) {
        for (const [w, h, tag] of [[390, 844, 'телефон'], [1280, 900, 'десктоп']]) {
            const ctx = who === 'user' ? user : guest;
            const p = await ctx.newPage();
            await p.setViewportSize({ width: w, height: h });
            const errors = [];
            const foreign = new Set();
            p.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
            p.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
            p.on('request', (r) => { const u = new URL(r.url()); if (/^https?:$/.test(u.protocol) && u.host !== HOST) foreign.add(u.host); });
            // the page's own status is checked separately (the 404 page answers 404 by design)
            p.on('response', (r) => {
                if (r.status() >= 400 && !(r.request().isNavigationRequest() && r.frame() === p.mainFrame())) errors.push(`http ${r.status()}: ${r.url()}`);
            });
            const resp = await p.goto(BASE + url, { waitUntil: 'networkidle' });
            const where = `${label}, ${tag}`;
            if (status === 404 && /ISPConfig/.test(await p.evaluate(() => document.body ? document.body.textContent : ''))) {
                console.log(`SKIP ${where}: страницу 404 подменяет ISPConfig (Own Error-Documents)`);
                await p.close();
                continue;
            }
            check(`${where}: ответ ${status || 200}`, resp && resp.status() === (status || 200), resp && resp.status());
            const r = await inspect(p);
            check(`${where}: нет горизонтальной прокрутки`, r.overflow <= 0, `лишние ${r.overflow} px`);
            check(`${where}: main#content, содержимое раньше боковой колонки`, r.main && r.mainFirst, JSON.stringify(r));
            check(`${where}: один заголовок h1`, r.h1 === 1, `h1: ${r.h1}`);
            check(`${where}: ссылка «к содержимому»`, r.skip);
            if (label === 'главная' || label === 'обратная связь') {
                // Tab: the skip link first, then the site's links; the focused element has a visible ring
                await p.keyboard.press('Tab');
                const first = await p.evaluate(() => document.activeElement && document.activeElement.className);
                check(`${where}: первый Tab — ссылка «к содержимому»`, /skip-link/.test(first || ''), first);
                const ring = await p.evaluate(() => {
                    const s = getComputedStyle(document.activeElement);
                    return (s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0) || s.boxShadow !== 'none';
                });
                check(`${where}: фокус виден`, ring);
            }
            if (w < 600) {
                check(`${where}: меню свёрнуто`, r.menu && !r.menuLinkVisible, JSON.stringify(r));
                if (r.menu) {
                    await p.click('nav.site-nav details.site-menu > summary');
                    check(`${where}: меню раскрывается по кнопке`, await p.isVisible('nav.site-nav details.site-menu ul a'));
                }
            } else {
                check(`${where}: меню видно сразу`, r.menu && r.menuLinkVisible, JSON.stringify(r));
            }
            check(`${where}: ничего со сторонних адресов`, !foreign.size, [...foreign].join(', '));
            check(`${where}: без ошибок JS и 404`, !errors.length, errors.join(' | '));
            await p.screenshot({ path: path.join(SHOTS, `${label.replace(/\s+/g, '-')}-${w}.png`), fullPage: true });
            await p.close();
        }
    }
    // dark scheme: the same page, another background
    {
        const p = await guest.newPage();
        await p.goto(BASE, { waitUntil: 'networkidle' });
        const light = (await inspect(p)).bg;
        await p.emulateMedia({ colorScheme: 'dark' });
        const dark = (await inspect(p)).bg;
        check('тёмная схема меняет фон', light !== dark, `${light} / ${dark}`);
        await p.screenshot({ path: path.join(SHOTS, 'главная-тёмная.png'), fullPage: true });
        await p.close();
    }

    // страницы (задача 4): новость, галерея, форма обратной связи, страницы ошибок
    const admin = await browser.newContext({ locale: 'ru-RU' });
    {
        const lp = await admin.newPage();
        await lp.goto(BASE + 'login/', { waitUntil: 'networkidle' });
        await lp.fill('input[name="user[username]"]', process.env.ADMIN_EMAIL);
        await lp.fill('input[name="user[password]"]', process.env.ADMIN_PASSWORD);
        await Promise.all([lp.waitForNavigation({ waitUntil: 'networkidle' }), lp.click('button[name="user[login]"]')]);
        await lp.close();
    }
    // ссылка на главную в содержимом страницы (не в крошках): видна и с текстом
    const homeLink = (p) => p.evaluate((base) => {
        const main = document.querySelector('main');
        const links = main ? [...main.querySelectorAll('a[href]')].filter((a) => !a.closest('.breadcrumbs')) : [];
        const home = links.find((a) => a.href.replace(/\/$/, '') === base.replace(/\/$/, ''));
        return { text: main ? main.textContent.replace(/\s+/g, ' ') : '', home: !!home && home.textContent.trim() !== '' && home.checkVisibility(),
            title: (document.querySelector('h1') || { textContent: '' }).textContent.trim() };
    }, BASE);
    for (const [w, h, tag] of [[390, 844, 'телефон'], [1280, 900, 'десктоп']]) {
        const open = async (ctx) => {
            const p = await ctx.newPage();
            await p.setViewportSize({ width: w, height: h });
            const errors = [];
            p.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
            p.on('response', (r) => {
                if (r.status() >= 400 && !(r.request().isNavigationRequest() && r.frame() === p.mainFrame())) errors.push(`http ${r.status()}: ${r.url()}`);
            });
            return [p, errors];
        };

        // новость: её название — единственный заголовок h1, картинка видна и помещается
        let [p] = await open(guest);
        await p.goto(BASE + PAGES.find((x) => x[0] === 'новость')[1], { waitUntil: 'networkidle' });
        const n = await p.evaluate(() => {
            const crumb = document.querySelector('.breadcrumbs [aria-current]');
            const img = document.querySelector('main .feed_image img');
            return { h1: [...document.querySelectorAll('h1')].map((x) => x.textContent.trim()), crumb: crumb && crumb.textContent.trim(),
                img: !!img && img.complete && img.naturalWidth > 0, fits: !!img && img.getBoundingClientRect().right <= document.documentElement.clientWidth };
        });
        check(`новость, ${tag}: заголовок h1 — название новости`, n.h1.length === 1 && n.h1[0] === n.crumb, JSON.stringify(n));
        check(`новость, ${tag}: картинка видна и помещается`, n.img && n.fits, JSON.stringify(n));
        await p.close();

        // галерея: превью сеткой, каждое — ссылка на файл; кнопок карусели без скрипта нет
        [p] = await open(guest);
        await p.goto(BASE + 'media/', { waitUntil: 'networkidle' });
        const g = await p.evaluate(() => {
            const list = document.querySelector('main ul.gallery');
            const items = list ? [...list.children] : [];
            const imgs = items.map((li) => li.querySelector('img')).filter(Boolean);
            return { list: !!list, display: list ? getComputedStyle(list).display : null, items: items.length,
                sameRow: items.length > 1 && Math.abs(items[0].getBoundingClientRect().top - items[1].getBoundingClientRect().top) < 2,
                width: imgs.length ? Math.round(imgs[0].getBoundingClientRect().width) : 0,
                loaded: imgs.length > 0 && imgs.every((i) => i.complete && i.naturalWidth > 0),
                links: items.length > 0 && items.every((li) => li.querySelector('a[href]')),
                controls: document.querySelectorAll('.previous_control, .next_control').length };
        });
        check(`галерея, ${tag}: превью сеткой, каждое — ссылка`, g.list && g.display === 'grid' && g.items >= 2 && g.loaded && g.links, JSON.stringify(g));
        if (w > 600) check('галерея, десктоп: несколько превью в ряд, превью не меньше 120 px', g.sameRow && g.width >= 120, JSON.stringify(g));
        check(`галерея, ${tag}: нет кнопок карусели`, g.controls === 0, JSON.stringify(g));
        await p.close();

        // обратная связь: поля видны, ловушка для ботов скрыта, подписи над полями
        [p] = await open(guest);
        await p.goto(BASE + 'contacts/', { waitUntil: 'networkidle' });
        const f = await p.evaluate(() => {
            const form = document.querySelector('main form');
            const visible = form ? [...form.querySelectorAll('input:not([type=hidden]), textarea, select')].filter((x) => x.checkVisibility()) : [];
            const trap = form && form.querySelector('[name*="hp_url"]');
            // ловушка спрятана за краем экрана (checkVisibility такие элементы считает видимыми), без таба и читалок
            const box = trap && trap.getBoundingClientRect();
            const offscreen = !!box && (box.right <= 0 || box.bottom <= 0 || box.left >= innerWidth || box.width <= 1 || !trap.checkVisibility());
            const label = form && form.querySelector('label[for]');
            const input = label && document.getElementById(label.htmlFor);
            return { fields: visible.length, trap: !!trap, trapHidden: offscreen && trap.tabIndex === -1 && !!trap.closest('[aria-hidden="true"]'),
                labelAbove: !!(label && input) && label.getBoundingClientRect().bottom <= input.getBoundingClientRect().top + 1 };
        });
        check(`обратная связь, ${tag}: поля видны, ловушка для ботов скрыта`, f.fields >= 3 && f.trap && f.trapHidden, JSON.stringify(f));
        check(`обратная связь, ${tag}: подписи над полями`, f.labelAbove, JSON.stringify(f));

        // страница ошибки сайта: форма без токена (422 — эту страницу, в отличие от 404, ISPConfig не подменяет)
        const [resp] = await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.evaluate((b) => {
            const form = document.createElement('form');
            form.method = 'post';
            form.action = b + 'contacts/send/';
            document.body.append(form);
            form.submit();
        }, BASE)]);
        let r = await inspect(p);
        let e = await homeLink(p);
        check(`страница ошибки сайта, ${tag}: ответ 422`, resp && resp.status() === 422, resp && resp.status());
        check(`страница ошибки сайта, ${tag}: каркас темы, один h1, без прокрутки`, r.main && r.mainFirst && r.h1 === 1 && r.skip && r.menu
            && r.overflow <= 0, JSON.stringify(r));
        check(`страница ошибки сайта, ${tag}: понятный текст и видимая ссылка на главную`, /Форма устарела/.test(e.text) && e.home, JSON.stringify(e));
        check(`страница ошибки сайта, ${tag}: в заголовке нет кода ответа`, !/\d{3}/.test(e.title), e.title);
        await p.close();

        // страница ErrorDocument (ошибка вне раскладки сайта): администратор открыл ссылку на удаление GET-ом
        let errors;
        [p, errors] = await open(admin);
        const resp2 = await p.goto(BASE + 'admin/feedback-editor/single/feedbackList/999999/delete/', { waitUntil: 'networkidle' });
        r = await inspect(p);
        e = await homeLink(p);
        check(`страница ErrorDocument, ${tag}: ответ 422`, resp2 && resp2.status() === 422, resp2 && resp2.status());
        check(`страница ErrorDocument, ${tag}: main#content, один h1, ссылка «к содержимому», без прокрутки`, r.main && r.h1 === 1 && r.skip
            && r.overflow <= 0, JSON.stringify(r));
        check(`страница ErrorDocument, ${tag}: понятный текст и видимая ссылка на главную`, /Форма устарела/.test(e.text) && e.home, JSON.stringify(e));
        check(`страница ErrorDocument, ${tag}: без ошибок JS и 404`, !errors.length, errors.join(' | '));
        await p.screenshot({ path: path.join(SHOTS, `ошибка-errordocument-${w}.png`), fullPage: true });
        await p.close();
    }

    await browser.close();
    console.log(`screenshots: ${SHOTS}`);
    console.log(`== theme failures: ${fail}`);
    process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('FAIL ' + e.message); process.exit(1); });
