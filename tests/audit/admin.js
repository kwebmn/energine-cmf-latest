// Аудит вида админки (UI-подпроект 3): стили админки — admin.css (Tailwind, утилиты с префиксом a:), значки — спрайт
// images/icons.svg; старые файлы стилей и картинок не запрашиваются. Снимки экранов — в SHOTS.
// BASELINE=1 — только снимки (опора «до» для сравнения), без проверок.
//   cd tests/audit && ( envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node admin.js )
const { chromium } = require(process.env.PLAYWRIGHT || '/root/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

if (!process.env.BASE || !process.env.ADMIN_PASSWORD) {
    console.error('run: envsh=$(php8.5 ../env.php --shell) && eval "$envsh" first');
    process.exit(2);
}
const BASE = process.env.BASE.replace(/\/$/, '') + '/';
const SHOTS = process.env.SHOTS || fs.mkdtempSync(path.join(os.tmpdir(), 'admin-'));
const BASELINE = process.env.BASELINE === '1';
// старые файлы стилей и картинок админки, удалённые подпроектом: страница их не запрашивает
const GONE_CSS = ['modalbox.css', 'form.css', 'controls.css', 'tabpane.css', 'grid.css', 'pagelist.css', 'toolbar.css',
    'pagetoolbar.css', 'singlemode.css', 'energine.css', 'treeview.css', 'div.css'];
const GONE_IMAGES = ['images/asc.gif', 'images/desc.gif', 'images/pagelist.gif', 'images/prev_page.gif', 'images/next_page.gif',
    'images/checkbox_on.png', 'images/checkbox_off.png', 'images/toolbar/separator.gif', 'images/toolbar/add.png', 'images/toolbar/edit.png',
    'images/toolbar/delete.png', 'images/toolbar/up.png', 'images/toolbar/down.png', 'images/toolbar/nrgnptb.png',
    'images/toolbar/nrgnptbdbg.png', 'images/overlay_loading.gif', 'templates/icons/empty.icon.gif', 'templates/icons/divisions_list.icon.gif'];
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
    ['битые-ссылки', 'admin/links/'],
    ['поиск', 'admin/search/'],
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
                const old = log.css.filter((f) => GONE_CSS.includes(f) || /awesome/i.test(f));
                check(`${name}, ${w}px: удалённые стили не запрашиваются`, !old.length, old.join(' '));
                const oldImg = log.images.filter((f) => GONE_IMAGES.includes(f) || /awesome|images\/treeview\//i.test(f));
                check(`${name}, ${w}px: удалённые картинки и шрифты не запрашиваются`, !oldImg.length, oldImg.join(' '));
                const over = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth).catch(() => 0);
                check(`${name}, ${w}px: без горизонтальной прокрутки страницы`, over <= 0, `лишние ${over} px`);
                // кнопки панелей: доступное имя и Tab (п. 4–5 Review Focus)
                const bad = await p.evaluate(() => [...document.querySelectorAll('ul.toolbar li:not(.separator):not(.select):not(.custom_select)')]
                    .filter((li) => !(li.getAttribute('aria-label') || li.textContent || li.title).trim() || li.tabIndex !== 0)
                    .map((li) => li.className)).catch(() => []);
                check(`${name}, ${w}px: у кнопок панелей доступное имя и Tab`, !bad.length, bad.join(' | '));
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
            // фокус до окна — на ссылке страницы: после закрытия окон он возвращается туда
            await p.evaluate(() => { const a = document.querySelector('header a[href]'); if (a) { a.focus(); window.claudeFocusBefore = a; } });
            await open(BASE + 'admin/users/single/userEditor/add/');
            await p.waitForTimeout(2500);
            // окно — <dialog> в верхнем слое (надёжность, этап 5): затемнение — ::backdrop, страница под окном недоступна мыши
            const box = await p.evaluate(() => {
                const b = document.querySelector('.e-modalbox'); const cs = b && getComputedStyle(b);
                const r = b && b.getBoundingClientRect();
                const under = document.elementFromPoint(2, innerHeight - 2);
                return b && { tag: b.tagName, modal: b.matches(':modal'), position: cs.position, backdrop: getComputedStyle(b, '::backdrop').backgroundColor,
                    shadow: cs.boxShadow !== 'none', radius: parseFloat(cs.borderTopLeftRadius),
                    inView: r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight, frame: getComputedStyle(b.querySelector('iframe')).borderTopWidth,
                    pageBlocked: !!under && (under === b || b.contains(under)), pageScroll: getComputedStyle(document.documentElement).overflow };
            });
            check(`окно формы, ${w}px: <dialog> в верхнем слое, затемнение, в пределах окна, рамка и тень`, !!box && box.tag === 'DIALOG' && box.modal
                && box.position === 'fixed' && /^rgba\(0, 0, 0, 0\.[4-9]/.test(box.backdrop) && box.shadow && box.radius > 0 && box.inView
                && box.frame === '0px', JSON.stringify(box));
            check(`окно формы, ${w}px: страница под окном недоступна мыши`, !!box && box.pageBlocked, JSON.stringify(box));
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
                return { n: boxes.length, open: boxes.filter((b) => b.open).length, topIsSecond: !!top && boxes[1].contains(top),
                    backdrop2: boxes[1] ? getComputedStyle(boxes[1], '::backdrop').backgroundColor : '' };
            });
            await p.evaluate(() => window.top.ModalBox.close());
            await p.waitForTimeout(500);
            const left = await p.evaluate(() => document.querySelectorAll('.e-modalbox').length);
            check(`окно в окне, ${w}px: верхнее окно выше нижнего, затемнение одно, закрытие верхнего оставляет нижнее`, stack.n === 2
                && stack.open === 2 && stack.topIsSecond && /^rgba\(0, 0, 0, 0\)$|^transparent$/.test(stack.backdrop2) && left === 1,
                JSON.stringify({ ...stack, left }));
            await shot(p, `окно-формы-${w}`);
            // закрытие последнего окна: окон нет, фокус — там, где был до окна
            await p.evaluate(() => window.top.ModalBox.close());
            await p.waitForTimeout(500);
            const after = await p.evaluate(() => ({ boxes: document.querySelectorAll('.e-modalbox').length,
                focusBack: !!window.claudeFocusBefore && document.activeElement === window.claudeFocusBefore }));
            check(`окна закрыты, ${w}px: окон нет, фокус вернулся`, after.boxes === 0 && after.focusBack, JSON.stringify(after));
            await p.close();
        }

        // гриды: сортировка, чередование и выделение строк, кнопки панели (значок + доступное имя, клавиатура), листалка
        {
            const p = await ctx.newPage();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.goto(BASE + 'admin/translations/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(1000);
            // первая колонка, по которой грид сортирует (по щелчку у заголовка появляется класс asc)
            const ths = await p.$$('.gridTable thead th');
            for (const th of ths) {
                await th.click();
                await p.waitForTimeout(900);
                if (await p.$('.gridTable thead th.asc')) break;
            }
            await p.click('.gridContainer tr:nth-child(3) td:nth-child(2)');
            const g = await p.evaluate(() => {
                const cs = (e) => e && getComputedStyle(e);
                const th = document.querySelector('.gridTable thead th.asc, .gridTable thead th.desc');
                const odd = document.querySelector('.gridContainer tr:not(.even):not(.selected) td');
                const even = document.querySelector('.gridContainer tr.even:not(.selected) td');
                const sel = document.querySelector('.gridContainer tr.selected td');
                const primary = 'rgb(31, 95, 174)'; // --a-color-primary (#1f5fae)
                return { sortMark: !!th && cs(th, '::after') && getComputedStyle(th, '::after').content !== 'none',
                    zebra: !!odd && !!even && cs(odd).backgroundColor !== cs(even).backgroundColor,
                    selected: !!sel && cs(sel).backgroundColor === primary, primary,
                    font: cs(document.querySelector('.grid')).fontFamily };
            });
            check('грид: у отсортированной колонки знак направления, строки чередуются, выделенная — основного цвета, шрифт системный',
                g.sortMark && g.zebra && g.selected && /system-ui/.test(g.font), JSON.stringify(g));
            const tb = await p.evaluate(() => [...document.querySelectorAll('ul.toolbar li:not(.separator):not(.select)')].map((li) => ({
                name: (li.getAttribute('aria-label') || li.textContent || li.title).trim(), tab: li.tabIndex, svg: !!li.querySelector('svg use'),
                icon: li.classList.contains('icon') })));
            const noName = tb.filter((b) => !b.name);
            check('панель грида: у каждой кнопки доступное имя, все достижимы с Tab', tb.length > 0 && !noName.length && tb.every((b) => b.tab === 0),
                JSON.stringify(tb.slice(0, 6)));
            const pl = await p.evaluate(() => {
                const items = [...document.querySelectorAll('.e-pagelist > li[index]:not([index="0"])')];
                const next = document.querySelector('.e-pagelist [data-page="next"]');
                return { n: items.length, tab: items.every((li) => li.tabIndex === 0), next: !!next && !!next.querySelector('svg use')
                    && !!next.getAttribute('aria-label') };
            });
            check('листалка: номера и стрелки достижимы с Tab, стрелка — значок с доступным именем', pl.n > 0 && pl.tab && pl.next, JSON.stringify(pl));
            await p.focus('.e-pagelist > li[index="2"]');
            await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), p.keyboard.press('Enter')]);
            await p.waitForTimeout(600);
            const cur = await p.evaluate(() => (document.querySelector('.e-pagelist li.current') || {}).textContent);
            check('листалка: Enter на номере открывает страницу', cur === '2', cur);
            await shot(p, 'грид-переводов-сортировка');
            await p.close();
            const up = await ctx.newPage();
            await up.goto(BASE + 'admin/users/', { waitUntil: 'networkidle' });
            await up.waitForTimeout(800);
            const cb = await up.evaluate(() => ({ on: document.querySelectorAll('td [data-checkbox="on"] svg use').length,
                imgs: document.querySelectorAll('td img[src*="checkbox_"]').length }));
            check('грид пользователей: флажок активности — значок, не картинка', cb.on > 0 && !cb.imgs, JSON.stringify(cb));
            await up.close();
        }

        // панель страницы и режим правки; стили сайта у администратора те же, что у гостя
        {
            const props = ['fontFamily', 'fontSize', 'color', 'backgroundColor', 'lineHeight', 'maxWidth'];
            const look = (page) => page.evaluate((ps) => Object.fromEntries(['header', 'main', 'footer', 'h1', 'nav.site-nav a']
                .map((sel) => { const e = document.querySelector(sel); const cs = e && getComputedStyle(e);
                    return [sel, cs ? ps.map((k) => cs[k]).join('|') : null]; })), props);
            const guest = await browser.newContext({ locale: 'ru-RU' });
            const gp = await guest.newPage();
            await gp.setViewportSize({ width: 1280, height: 900 });
            await gp.goto(BASE + 'info/quick-start/', { waitUntil: 'networkidle' });
            const g = await look(gp);
            await guest.close();
            const p = await ctx.newPage();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.goto(BASE + 'info/quick-start/', { waitUntil: 'networkidle' });
            const a = await look(p);
            const diff = Object.keys(g).filter((k) => g[k] !== a[k]);
            check('страница у администратора: шапка, содержимое, подвал, заголовок и меню выглядят как у гостя', !diff.length,
                diff.map((k) => `${k}: ${g[k]} / ${a[k]}`).join('; '));
            const gear = await p.evaluate(() => {
                const b = document.querySelector('.e-topframe .pagetb_logo');
                return b && { tag: b.tagName, name: b.getAttribute('aria-label'), svg: !!b.querySelector('svg use[href$="#gear"]'),
                    bar: getComputedStyle(document.querySelector('ul.docked_toolbar')).backgroundColor };
            });
            check('панель страницы: шестерёнка — кнопка со значком и доступным именем', !!gear && gear.tag === 'BUTTON' && !!gear.name && gear.svg,
                JSON.stringify(gear));
            const side0 = await p.evaluate(() => document.documentElement.classList.contains('e-has-sideframe'));
            await p.focus('.e-topframe .pagetb_logo');
            await p.keyboard.press('Enter');
            await p.waitForTimeout(500);
            const side1 = await p.evaluate(() => document.documentElement.classList.contains('e-has-sideframe'));
            await p.keyboard.press('Enter');
            await p.waitForTimeout(500);
            const side2 = await p.evaluate(() => document.documentElement.classList.contains('e-has-sideframe'));
            check('панель страницы: шестерёнка с клавиатуры открывает и закрывает боковую панель', side1 !== side0 && side2 === side0,
                JSON.stringify({ side0, side1, side2 }));
            await Promise.all([p.waitForNavigation({ waitUntil: 'networkidle' }), p.click('li.editMode_btn')]);
            const ed = await p.evaluate(() => {
                const e = document.querySelector('.nrgnEditor'); const cs = getComputedStyle(e);
                e.classList.add('nrgnEditorError'); const err = getComputedStyle(e).outlineColor; e.classList.remove('nrgnEditorError');
                return { style: cs.outlineStyle, width: cs.outlineWidth, err };
            });
            check('режим правки: рамка блока видна, у несохранённого блока — цвет ошибки', ed.style !== 'none' && parseFloat(ed.width) >= 1
                && ed.err === 'rgb(179, 38, 30)', JSON.stringify(ed));
            await shot(p, 'режим-правки-после');
            await p.close();
            const sp = await ctx.newPage();
            await sp.goto(BASE + 'admin/users/single/userEditor/add/', { waitUntil: 'networkidle' });
            const single = await sp.evaluate(() => ({ font: getComputedStyle(document.body).fontFamily, bg: getComputedStyle(document.body).backgroundColor }));
            check('окно single: фон и шрифт админки', /system-ui/.test(single.font) && single.bg === 'rgb(255, 255, 255)', JSON.stringify(single));
            await sp.close();
        }

        // дерево структуры: значки узлов, раскрытие щелчком и с клавиатуры, выбранный узел; боковая панель разделов
        {
            const p = await ctx.newPage();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.goto(BASE + 'admin/structure/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(1200);
            const t = await p.evaluate(() => {
                const links = [...document.querySelectorAll('.treeview li > a')];
                const folder = document.querySelector('.treeview li.folder');
                return { nodes: links.length, icons: links.filter((a) => a.querySelector('svg use')).length, folder: !!folder,
                    opened: folder && folder.classList.contains('opened') };
            });
            check('дерево: у каждого узла значок из спрайта', t.nodes > 1 && t.icons === t.nodes, JSON.stringify(t));
            // клавиатура: фокус на ссылке узла с вложенными, стрелка вправо раскрывает, влево — сворачивает
            const kb = await p.evaluate(() => {
                const li = [...document.querySelectorAll('.treeview li.folder')].find((x) => !x.classList.contains('opened'))
                    || document.querySelector('.treeview li.folder');
                li.querySelector('a').focus();
                return li.classList.contains('opened');
            });
            await p.keyboard.press(kb ? 'ArrowLeft' : 'ArrowRight');
            const kb2 = await p.evaluate(() => document.activeElement.closest('li').classList.contains('opened'));
            await p.keyboard.press(kb2 ? 'ArrowLeft' : 'ArrowRight');
            const kb3 = await p.evaluate(() => document.activeElement.closest('li').classList.contains('opened'));
            check('дерево: стрелки вправо/влево раскрывают и сворачивают узел', kb2 !== kb && kb3 === kb, JSON.stringify({ kb, kb2, kb3 }));
            await p.keyboard.press('Enter');
            await p.waitForTimeout(300);
            const sel = await p.evaluate(() => { const a = document.querySelector('.treeview li.selected > a'); const cs = a && getComputedStyle(a);
                const f = document.querySelector('.treeview li.folder'); const b = f && getComputedStyle(f, '::before');
                return { bg: cs && cs.backgroundColor, color: cs && cs.color, toggle: b && b.content }; });
            check('дерево: Enter выбирает узел, выбранный — основного цвета; у узла с вложенными знак раскрытия', sel.bg === 'rgb(31, 95, 174)'
                && sel.color === 'rgb(255, 255, 255)' && !!sel.toggle && sel.toggle !== 'none', JSON.stringify(sel));
            await shot(p, 'структура-после');
            await p.close();
        }
        {
            // боковая панель разделов: открывается шестерёнкой, страница сдвигается, кнопки дерева не под панелью сверху
            const p = await ctx.newPage();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.goto(BASE + 'info/quick-start/', { waitUntil: 'networkidle' });
            const wasOpen = await p.evaluate(() => document.documentElement.classList.contains('e-has-sideframe'));
            if (!wasOpen) await p.click('.pagetb_logo');
            await p.waitForTimeout(2500);
            const f = await (await p.$('.e-sideframe iframe')).contentFrame();
            await f.waitForSelector('#divTree li a', { timeout: 10000 }).catch(() => null);
            const side = await p.evaluate(() => ({ pl: getComputedStyle(document.body).paddingLeft,
                top: document.querySelector('.e-topframe').getBoundingClientRect().bottom }));
            const tb = await f.evaluate(() => { const li = document.querySelector('ul.toolbar li'); return li ? li.getBoundingClientRect().top : -1; });
            const icons = await f.evaluate(() => document.querySelectorAll('#divTree li > a svg use').length);
            check('боковая панель: страница сдвинута, кнопки дерева ниже панели сверху, у узлов значки', side.pl === '300px' && tb >= side.top && icons > 1,
                JSON.stringify({ side, tb, icons }));
            await shot(p, 'боковая-панель');
            if (!wasOpen) await p.click('.pagetb_logo');
            await p.waitForTimeout(500);
            await p.close();
        }

        // порядок слоёв в обоих файлах один и тот же (иначе у администратора каскад зависит от порядка подключения)
        {
            // порядок слоёв — по первому появлению имени в @layer (так его и считает браузер)
            const order = async (url) => { const r = await ctx.request.get(url); const t = r.ok() ? await r.text() : '';
                const names = [];
                for (const m of t.matchAll(/@layer ([a-z,]+)[;{]/g)) m[1].split(',').forEach((n) => { if (!names.includes(n)) names.push(n); });
                return names.join(','); };
            const want = 'properties,theme,base,components,admin,utilities';
            const site = await order(BASE + 'stylesheets/main/main.css'), admin = await order(BASE + 'stylesheets/admin.css');
            check('порядок слоёв в main.css и admin.css один: ' + want, site === want && admin === want, JSON.stringify({ site, admin }));
        }

        // в каталоге картинок ядра только используемое: на каждый файл есть ссылка в коде (не в комментарии XML)
        {
            const R = path.resolve(__dirname, '../..');
            const dir = path.join(R, 'core/modules/share/images');
            const files = execFileSync('find', [dir, '-type', 'f'], { encoding: 'utf8' }).trim().split('\n').map((f) => path.relative(dir, f));
            const unused = files.filter((f) => {
                let out = '';
                try {
                    out = execFileSync('grep', ['-rl', '--include=*.js', '--include=*.xslt', '--include=*.php', '--include=*.xml', '--include=*.css',
                        path.basename(f), path.join(R, 'core'), path.join(R, 'site'), path.join(R, 'setup')], { encoding: 'utf8' });
                } catch (e) { out = ''; }
                return !out.split('\n').filter(Boolean).some((hit) => !hit.includes('/images/')
                    && fs.readFileSync(hit, 'utf8').replace(/<!--[\s\S]*?-->/g, '').includes(path.basename(f)));
            });
            check('картинки ядра: каждая используется', !unused.length, unused.join(' '));
        }

        // подсказка «?» (константы HELP_<КЛАСС>_<СОСТОЯНИЕ>): кнопка с доступным именем, щелчок открывает текст;
        // где подсказки нет — нет и кнопки
        {
            const pageId = 3629;
            for (const [label, url, want] of [['форма раздела', `admin/structure/single/divEditor/${pageId}/edit/`, true],
                ['грид пользователей', 'admin/users/single/userEditor/', true], ['файлы', 'admin/users/single/adminPanel/file-library/', true],
                // у грида языков подсказка есть с этапа 3 надёжности (HELP_LANGUAGEEDITOR_MAIN — язык «в подготовке»);
                // без подсказки — грид ролей
                ['грид языков', 'admin/translations/languages/single/langEditor/', true],
                ['грид ролей', 'admin/users/roles/single/roleEditor/', false]]) {
                const p = await ctx.newPage();
                await p.setViewportSize({ width: 1280, height: 900 });
                await p.goto(BASE + url, { waitUntil: 'networkidle' });
                const h = await p.evaluate(() => {
                    const d = document.querySelector('details.e-help');
                    if (!d) return null;
                    const s = d.querySelector('summary');
                    s.click();
                    const body = d.querySelector('.e-help-text');
                    return { name: s.getAttribute('aria-label'), open: d.open, text: body ? body.textContent.trim().length : 0,
                        visible: !!body && body.getBoundingClientRect().height > 0 };
                });
                const over = await p.evaluate(() => document.documentElement.scrollWidth - innerWidth);
                check(`подсказка, ${label}: ${want ? 'кнопка «?» с именем открывает текст' : 'нет'}`, want
                    ? !!h && !!h.name && h.open && h.text > 20 && h.visible && over <= 0 : h === null, JSON.stringify({ h, over }));
                if (want) await shot(p, `подсказка-${label.replace(/ /g, '-')}`);
                await p.close();
            }
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
