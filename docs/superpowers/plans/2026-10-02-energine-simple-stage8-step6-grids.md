# Этап 8, шаг 6 — гриды админки без MooTools: план

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Grid`, `GridManager`, `FileRepository`, `UserManager`, `ActionLogManager` — на чистом JavaScript; гриды и
их окна работают без MooTools.

**Architecture:** классы JavaScript с прежним интерфейсом. `Grid` получает обработчики `onSelect`, `onSortChange`,
`onDoubleClick` параметрами и вызывает их методом `emit`; закрытая функция `addRecord` становится методом. Размеры —
целыми пикселями, как `getSize`/`getComputedSize` MooTools (`offsetWidth/Height`, `getComputedStyle`). Файловый грид —
подкласс `FileRepository.Grid`, его создаёт переопределённый `createGrid`. Cookie папки — `Energine.readCookie/
writeCookie`.

**Tech Stack:** браузерный JavaScript (классические скрипты, `ScriptLoader.load`), Playwright-аудит `tests/audit/grids.js`,
`tests/no-traces.sh`.

**Spec:** `docs/superpowers/specs/2026-10-02-energine-simple-stage8-step6-grids-design.md`

## Global Constraints

- Клон `/var/www/clients/client1/web97/private/stage8/energine`, ветка `main`; стенд —
  `STAND_MAILBOX=web97@loki.kweb.biz bash tests/tools/stand.sh start`, команды — `bash tests/tools/stand.sh run …`;
  карта скриптов стенда после смены зависимостей — от web97:
  `php8.5 /tmp/stand-web97/site/web/index.php setup scriptMap`.
- Коммиты — `bash tests/tools/stand.sh run git commit -q -m "…" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`;
  после git-операций от root — `chown -R web97:client1 /var/www/clients/client1/web97/private/stage8/energine`.
- В файлах из `VANILLA_JS` нет совпадений с `MOOTOOLS_CODE` (`tests/no-traces.sh`) и в комментариях: `$(`, `.each(`,
  `.getElement(` (и у своих объектов — `pageList.element`, не `pageList.getElement()`), `.addEvent(`, `.addClass(`,
  `.pass(`, `.fireEvent(`, `new Element(`, `typeOf(`, `.toInt()` и т. п.
- В комментариях не писать вызов загрузчика скриптов с именем в кавычках; классы — `var Имя = class Имя …`, никаких
  `const`/`let` на верхнем уровне файла.
- Проверки на площадке не меняют порядок языков и не очищают журнал действий: такие запросы перехватываются; всё, что
  проверки создают, удаляется (`grids-db.php remove`).
- База не меняется; адрес new.energine.org нигде не упоминается; пароли и `configs/system.config.*.php` не выводятся.
- Выкладка — без отдельного согласования (владелец: «продолжай без остановки»), с точкой отката.

## Review Focus

1. Ширины колонок и высоты: `adjustColumns`, `fitGridSize`, `fitGridFormSize` должны давать те же целые числа, что и
   `getSize`/`getComputedSize` MooTools (колонки заголовка совпадают с телом, грид не прыгает при каждой загрузке).
   Проверки — «колонки» и «размер окна».
2. Выбор строк: Shift+щелчок от строки выше и ниже, повторный Shift после Ctrl — ключи и подсветка как прежде (порядок
   ключей в `getSelectedRecordKey(true)` уходит в адрес удаления).
3. Окно поверх грида возвращает ответ (`afterClose`) — действие вызывается, ошибка в нём не ломает грид.
4. Файловый грид: папка `folderup`, хранилища, картинка с ошибкой загрузки (заглушка, увеличение отключено), запрос
   `HEAD` к файлу без `Content-Length`.
5. Два грида на одной странице (теоретически): у каждого свой выбор, файловые ячейки — только у файлового грида.

---

## Task 1: Проверки

**Files:**
- Modify: `tests/audit/grids-db.php` (`add` — пользователи и папка шага 6, `remove` — их уборка, команда `user-active`)
- Modify: `tests/audit/grids.js` (блок шага 6 перед `    } finally {\n        db('remove');`)

**Interfaces:**
- Produces: проверки задачи 2; красные до переделки — восемь «гриды без MooTools: …» и «репозиторий: размер файла
  меньше 1 КиБ — в байтах, без ошибки JS».

- [ ] **Step 1: Помощник базы.** В `tests/audit/grids-db.php`:
  - в шапку: `//   php8.5 grids-db.php user-active ID — активен ли пользователь (1/0)`;
  - константы после `const FILE = …;`:

```php
const DIR = 'uploads/public/claude-grid-dir';
// картинка 1×1 (меньше 1 КиБ) — размер файла в байтах
const TINY_PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
```

  - в `add` перед `echo json_encode(…)`:

```php
        // этап 8, шаг 6: три пользователя — выбор и удаление строк; неактивный — «Активировать»
        $del = [];
        foreach ([1, 2, 3] as $n) {
            q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
                ["claude-grid-del$n-" . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), "Claude Del $n"]);
            $del[] = (int)pdo()->lastInsertId();
        }
        q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 0)',
            ['claude-grid-off-' . getmypid() . '@localhost', password_hash(bin2hex(random_bytes(8)), PASSWORD_DEFAULT), 'Claude Off']);
        $off = (int)pdo()->lastInsertId();
        // папка репозитория с большой картинкой и маленькой (меньше 1 КиБ): папки, крошки, размер файла, превью
        $pub = scalar("SELECT upl_id FROM share_uploads WHERE upl_path = 'uploads/public' LIMIT 1");
        @mkdir(WEB . '/' . DIR);
        copy(WEB . '/uploads/public/13662314846.png', WEB . '/' . DIR . '/claude-grid-big.png');
        file_put_contents(WEB . '/' . DIR . '/claude-grid-tiny.png', base64_decode(TINY_PNG));
        foreach (['', '/claude-grid-big.png', '/claude-grid-tiny.png'] as $f) {
            chown(WEB . '/' . DIR . $f, SITE_USER);
        }
        q("INSERT INTO share_uploads (upl_pid, upl_childs_count, upl_path, upl_filename, upl_name, upl_title, upl_publication_date,
                upl_internal_type, upl_mime_type, upl_is_active)
           VALUES (?, 2, ?, 'claude-grid-dir', 'claude-grid-dir', 'claude-grid-dir', NOW(), 'folder', 'unknown/mime-type', 1)", [$pub, DIR]);
        $dir = (int)pdo()->lastInsertId();
        $files = [];
        foreach (['big' => [90, 68], 'tiny' => [1, 1]] as $name => [$w, $h]) {
            q("INSERT INTO share_uploads (upl_pid, upl_path, upl_filename, upl_name, upl_title, upl_publication_date, upl_internal_type,
                    upl_mime_type, upl_width, upl_height, upl_is_active)
               VALUES (?, ?, ?, ?, ?, NOW(), 'image', 'image/png', ?, ?, 1)",
                [$dir, DIR . "/claude-grid-$name.png", "claude-grid-$name.png", "claude-grid-$name.png", "claude-grid-$name", $w, $h]);
            $files[$name] = (int)pdo()->lastInsertId();
        }
```

  и в выводимый JSON добавить `'del' => $del, 'off' => $off, 'dir' => $dir, 'big' => $files['big'],
  'tiny' => $files['tiny'], 'pub' => (int)$pub`;
  - в `remove` перед `break;`:

```php
        q("DELETE FROM share_uploads WHERE upl_path LIKE 'uploads/public/claude-grid-dir%'");
        @unlink(WEB . '/' . DIR . '/claude-grid-big.png');
        @unlink(WEB . '/' . DIR . '/claude-grid-tiny.png');
        @rmdir(WEB . '/' . DIR);
```

  - команду перед `default:`:

```php
    case 'user-active':
        echo scalar('SELECT u_is_active FROM user_users WHERE u_id = ?', [(int)$argv[2]]);
        break;
```

- [ ] **Step 2: Проверки.** В `tests/audit/grids.js` перед последним `    } finally {\n        db('remove');\n    }`
  вставить:

Full file `tests/audit/grids-step6-block.js`:
```js

        // ===== stage 8, step 6: the grids without MooTools — what they do stays as it was =====
        const SITE_PATH = new URL(BASE).pathname;
        const showTab = (page, selector) => page.evaluate((sel) => {
            for (let el = document.querySelector(sel); el; el = el.parentElement) {
                const link = el.id && document.querySelector('a[href="#' + el.id + '"]');
                if (link) {
                    link.click();
                    return true;
                }
            }
            return false;
        }, selector);
        const gridState = (target) => target.evaluate(() => {
            const gm = [...document.querySelectorAll('.e-pane')].find((pane) => pane.GridManager).GridManager;
            return {
                rows: [...gm.grid.tbody.querySelectorAll('tr')].filter((tr) => tr.record)
                    .map((tr) => ({ key: String(tr.record[gm.grid.keyFieldName]), sel: tr.classList.contains('selected'), text: tr.textContent.trim() })),
                keys: String(gm.grid.getSelectedRecordKey(true)),
            };
        });
        const filterGrid = async (page, value) => {
            await page.click('.filter_toggle');
            await page.waitForTimeout(300);
            await page.fill('.filters .filter .f_query_container input.query', value);
            await Promise.all([page.waitForResponse((r) => r.url().includes('/get-data/')), page.click('button.f_apply')]);
            await page.waitForTimeout(500);
        };

        // 1. no MooTools: the grid pages and the file library in a form window (requests of the checked document
        //    only: the sidebar of a full page — DivSidebar — keeps MooTools till step 7)
        {
            const mooFree = async (label, open) => {
                const p = await ctx.newPage();
                const errors = watch(p);
                const requests = [];
                p.on('request', (r) => { if (/mootools/i.test(r.url())) requests.push(r); });
                const target = await open(p);
                const frame = target && (target.mainFrame ? target.mainFrame() : target);
                const asked = requests.filter((r) => r.frame() === frame).map((r) => r.url());
                const moo = target ? await target.evaluate(() => typeof window.MooTools) : 'no window';
                check(`гриды без MooTools: ${label}`, moo === 'undefined' && !asked.length, JSON.stringify({ moo, asked }));
                check(`гриды без MooTools: ${label} — без ошибок JS и 404`, !errors.list().length, errors.list().join(' | '));
                await p.close();
            };
            for (const [label, url] of [['пользователи', 'admin/users/'], ['роли', 'admin/users/roles/'],
                ['языки', 'admin/translations/languages/'], ['переводы', 'admin/translations/'],
                ['шаблоны писем', 'admin/mail-templates/'], ['журнал действий', 'admin/action-log/'],
                ['репозиторий файлов', 'admin/users/single/adminPanel/file-library/']]) {
                await mooFree(label, async (p) => {
                    await p.goto(BASE + url, { waitUntil: 'networkidle' });
                    return p;
                });
            }
            await mooFree('библиотека файлов в окне формы', async (p) => {
                await p.goto(BASE + `admin/users/single/userEditor/${ids.user}/edit/`, { waitUntil: 'networkidle' });
                await showTab(p, 'button[onclick*="openFileLib"]');
                await p.click('button[onclick*="openFileLib"]');
                const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
                const f = el && await el.contentFrame();
                if (f) {
                    await f.waitForLoadState('networkidle').catch(() => null);
                    await f.waitForSelector('tbody tr td', { timeout: 10000 }).catch(() => null);
                }
                return f;
            });
        }

        // 2. rows (users window, the test users by the grid filter): a click selects one row, Shift — a range,
        //    Ctrl — one more; the keys go comma-separated; a double click opens the record; «Удалить» two rows
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const dialogs = [];
            p.on('dialog', (d) => { dialogs.push(d.type()); d.accept(); });
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            await filterGrid(p, 'claude-grid-del');
            const rows = p.locator('.gridContainer tbody tr');
            const s0 = await gridState(p);
            await rows.nth(0).click();
            const s1 = await gridState(p);
            await rows.nth(2).click({ modifiers: ['Shift'] });
            const s2 = await gridState(p);
            await rows.nth(1).click();
            await rows.nth(2).click({ modifiers: ['Control'] });
            const s3 = await gridState(p);
            check('выбор строк: щелчок — одна строка', s0.rows.length === 3 && s1.rows.filter((r) => r.sel).length === 1 && s1.rows[0].sel,
                JSON.stringify({ s0, s1 }));
            check('выбор строк: Shift+щелчок — диапазон', s2.rows.every((r) => r.sel)
                && s2.keys === [s2.rows[0].key, s2.rows[1].key, s2.rows[2].key].join(','), JSON.stringify(s2));
            check('выбор строк: Ctrl+щелчок — ещё одна, ключи через запятую', !s3.rows[0].sel && s3.rows[1].sel && s3.rows[2].sel
                && s3.keys === [s3.rows[1].key, s3.rows[2].key].join(','), JSON.stringify(s3));

            await rows.nth(1).dblclick();
            const win = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 }).catch(() => null);
            const src = win ? await win.evaluate((f) => f.src) : '';
            check('двойной щелчок по строке — окно правки этой записи', src.endsWith(`/${s3.rows[1].key}/edit`), src);
            await p.evaluate(() => ModalBox.close());
            await p.waitForTimeout(600);

            await rows.nth(1).click();
            await rows.nth(2).click({ modifiers: ['Control'] });
            const keys = (await gridState(p)).keys;
            const [del] = await Promise.all([
                p.waitForRequest((r) => /\/delete\/?$/.test(r.url()), { timeout: 10000 }),
                p.click('ul.toolbar li.delete_btn'),
            ]);
            await p.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 10000 }).catch(() => null);
            await p.waitForTimeout(600);
            const left = await gridState(p);
            check('«Удалить» двух выбранных: подтверждение, запрос …/id1,id2/delete/, осталась одна строка', dialogs.includes('confirm')
                && del.url().endsWith(`/${keys}/delete/`) && left.rows.length === 1 && left.rows[0].key === s3.rows[0].key,
                JSON.stringify({ dialogs, url: del.url(), keys, left }));
            check('выбор и удаление строк: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 3. sorting, columns, window size (users window): the header cycles asc → desc → none; the head columns are
        //    as wide as the body ones; the grid follows the window height
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const urls = [];
            p.on('request', (r) => { if (r.url().includes('/get-data/')) urls.push(r.url()); });
            await p.setViewportSize({ width: 1280, height: 720 });
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            const head = '.gridHeadContainer th[name="u_name"]';
            const clickSort = async () => {
                await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), p.click(head)]);
                await p.waitForTimeout(300);
                return { url: urls[urls.length - 1], cls: await p.evaluate((s) => document.querySelector(s).className, head) };
            };
            const a = await clickSort(), d = await clickSort(), n = await clickSort();
            check('сортировка: щелчок по заголовку — по возрастанию, второй — по убыванию, третий — без сортировки',
                /get-data\/u_name-asc\/page-1$/.test(a.url) && a.cls === 'asc' && /get-data\/u_name-desc\/page-1$/.test(d.url)
                && d.cls === 'desc' && /get-data\/page-1$/.test(n.url) && n.cls === '', JSON.stringify({ a, d, n }));
            const cols = await p.evaluate(() => ({
                head: [...document.querySelectorAll('.gridHeadContainer col')].map((c) => c.style.width),
                body: [...document.querySelectorAll('.gridContainer col')].map((c) => c.style.width),
                ths: [...document.querySelectorAll('.gridHeadContainer th')].map((th) => Math.round(th.getBoundingClientRect().width)),
                tds: [...document.querySelectorAll('.gridContainer tbody tr:first-child td')].map((td) => Math.round(td.getBoundingClientRect().width)),
            }));
            check('колонки: ширины колонок заголовка — как у тела', cols.head.length > 0 && cols.head.join() === cols.body.join()
                && cols.head.every((w) => /^\d+px$/.test(w)) && cols.ths.every((w, i) => Math.abs(w - cols.tds[i]) <= 1), JSON.stringify(cols));
            const height = () => p.evaluate(() => parseInt(document.querySelector('.gridContainer').style.height, 10));
            const h720 = await height();
            await p.setViewportSize({ width: 1280, height: 480 });
            await p.waitForTimeout(600);
            const h480 = await height();
            check('размер окна: высота грида в окне следует за окном', h720 > 0 && h720 - h480 === 240, JSON.stringify({ h720, h480 }));
            check('сортировка, колонки, размер окна: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }
        {
            // a full page: the pane follows the window
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.setViewportSize({ width: 1280, height: 720 });
            await p.goto(BASE + 'admin/translations/', { waitUntil: 'networkidle' });
            await p.waitForTimeout(600);
            const size = () => p.evaluate(() => {
                const g = document.querySelector('.gridContainer');
                return { pane: parseInt(g.closest('.e-pane').style.height, 10), grid: parseInt(g.style.height, 10) };
            });
            const s720 = await size();
            await p.setViewportSize({ width: 1280, height: 480 });
            await p.waitForTimeout(600);
            const s480 = await size();
            await p.setViewportSize({ width: 1280, height: 900 });
            await p.waitForTimeout(600);
            const s900 = await size();
            check('размер окна: панель грида на странице следует за окном', s480.pane < s720.pane && s720.pane < s900.pane
                && s900.grid > s720.grid, JSON.stringify({ s480, s720, s900 }));
            check('размер окна, страница: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 4. «Вверх», «Вниз» (languages window; the requests are answered here — the order of the languages stays)
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            const moves = [];
            await p.route(/\/(up|down)\/$/, (route) => {
                moves.push(route.request().url());
                route.fulfill({ status: 200, contentType: 'application/json', body: '{"result":true}' });
            });
            await p.goto(BASE + 'admin/translations/languages/single/langEditor/', { waitUntil: 'networkidle' });
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const key = (await gridState(p)).keys;
            const [down] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.down_btn'),
            ]);
            await p.waitForTimeout(500);
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const [up] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.up_btn'),
            ]);
            check('«Вниз» и «Вверх»: запросы …/<id>/down/ и …/<id>/up/, грид перезагружает ту же страницу', moves.length === 2
                && moves[0].endsWith(`/${key}/down/`) && moves[1].endsWith(`/${key}/up/`)
                && /get-data\/page-1$/.test(down.url()) && /get-data\/page-1$/.test(up.url()), JSON.stringify({ moves, down: down.url(), up: up.url() }));
            check('«Вниз» и «Вверх»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 5. «Править предыдущий» (mail templates): the window closes, the grid opens the previous template; the
        //    template saved without edits is unchanged
        {
            const mailAll = () => execFileSync('php8.5', [path.join(__dirname, 'editors-db.php'), 'mail-all'], { encoding: 'utf8' });
            const was = mailAll();
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/mail-templates/', { waitUntil: 'networkidle' });
            await p.waitForSelector('tbody tr td', { timeout: 10000 });
            const rows = p.locator('.gridContainer tbody tr');
            await rows.nth(1).click();
            const keys = (await gridState(p)).rows.map((r) => r.key);
            await p.click('ul.toolbar li.edit_btn');
            const frameEl = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const first = await frameEl.evaluate((f) => f.src);
            const frame = await frameEl.contentFrame();
            await frame.waitForSelector('li.save_btn', { timeout: 10000 });
            await frame.selectOption('li.select select', 'editPrev');
            await Promise.all([
                p.waitForResponse((r) => /\/save\/?(\?|$)/.test(r.url()) && r.request().method() === 'POST', { timeout: 15000 }),
                frame.click('li.save_btn'),
            ]);
            await p.waitForFunction((url) => [...document.querySelectorAll('.e-modalbox iframe')]
                .some((f) => f.src !== url && /\/edit\/?$/.test(f.src)), first, { timeout: 15000 }).catch(() => null);
            const next = await p.evaluate(() => [...document.querySelectorAll('.e-modalbox iframe')].map((f) => f.src));
            check('«Править предыдущий»: окно закрыто, открыта правка предыдущей записи', first.endsWith(`/${keys[1]}/edit`)
                && next.length === 1 && next[0].endsWith(`/${keys[0]}/edit`), JSON.stringify({ keys, first, next }));
            check('«Править предыдущий»: шаблон без правки не изменился', mailAll() === was);
            check('«Править предыдущий»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
            await ctx.clearCookies({ name: 'after_add_default_action' });
        }

        // 6. the file repository: a double click opens the repository and the folder; the crumbs lead back; the
        //    folder is remembered in a cookie and opened after a reload; file sizes (also of a file under 1 KiB);
        //    hovering a preview shows a bigger picture, leaving it removes it
        {
            await ctx.clearCookies({ name: 'NRGNFRPID' });
            const p = await ctx.newPage();
            const errors = watch(p);
            const loads = [];
            p.on('request', (r) => { if (r.url().includes('/get-data/')) loads.push(r.url()); });
            const lib = BASE + 'admin/users/single/adminPanel/file-library/';
            await p.goto(lib, { waitUntil: 'networkidle' });
            const openRow = async (title) => {
                const row = p.locator('.gridContainer tbody tr', { hasText: title }).first();
                await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), row.dblclick()]);
                await p.waitForTimeout(800);
            };
            const titles = async () => (await gridState(p)).rows.map((r) => r.text);
            await openRow((await titles())[0]);
            await openRow('claude-grid-dir');
            const inside = await titles();
            const crumbs = await p.evaluate(() => [...document.querySelectorAll('#breadcrumbs a')].map((a) => a.textContent));
            const cookie = (await ctx.cookies(BASE)).find((c) => c.name === 'NRGNFRPID');
            check('репозиторий: двойной щелчок открывает хранилище и папку, крошки — путь', inside.some((t) => t.includes('claude-grid-big'))
                && inside.some((t) => t.includes('claude-grid-tiny')) && crumbs.length >= 2 && crumbs[crumbs.length - 1].includes('claude-grid-dir'),
                JSON.stringify({ inside, crumbs }));
            check('репозиторий: папка запомнена в cookie на сутки с путём сайта', !!cookie && cookie.value === String(ids.dir)
                && cookie.path === SITE_PATH, JSON.stringify(cookie));
            await p.waitForTimeout(1500);
            const sizes = await p.evaluate(() => [...document.querySelectorAll('.gridContainer tbody tr')].map((tr) => ({
                text: tr.textContent, size: [...tr.querySelectorAll('td.properties tr')].map((r) => r.textContent).find((t) => /\d (B|KiB|MiB)$/.test(t)) || '',
            })).filter((r) => r.text.includes('claude-grid-')));
            const big = sizes.find((r) => r.text.includes('claude-grid-big')) || {}, tiny = sizes.find((r) => r.text.includes('claude-grid-tiny')) || {};
            check('репозиторий: размер файла в свойствах', /9\.0\d KiB$/.test(big.size || ''), JSON.stringify(sizes));
            check('репозиторий: размер файла меньше 1 КиБ — в байтах, без ошибки JS', /\d+(\.\d+)? B$/.test(tiny.size || '')
                && !errors.list().some((e) => /toPrecision/.test(e)), JSON.stringify({ sizes, errors: errors.list() }));

            const thumb = p.locator('.gridContainer tbody tr', { hasText: 'claude-grid-big' }).locator('.thumb_container').first();
            await thumb.hover();
            await p.waitForTimeout(1200);
            const popup = await p.evaluate(() => {
                const img = [...document.querySelectorAll('body > img')].find((i) => i.src.includes('w298-h224/'));
                return img ? { src: img.src, w: Math.round(img.getBoundingClientRect().width) } : null;
            });
            await p.mouse.move(5, 5);
            await p.waitForTimeout(500);
            const after = await p.evaluate(() => [...document.querySelectorAll('body > img')].filter((i) => i.src.includes('w298-h224/')).length);
            check('репозиторий: наведение на превью — увеличенная картинка, уход мыши — убрана', !!popup
                && popup.src.endsWith('w298-h224/uploads/public/claude-grid-dir/claude-grid-big.png') && popup.w > 200 && after === 0,
                JSON.stringify({ popup, after }));

            loads.length = 0;
            await p.goto(lib, { waitUntil: 'networkidle' });
            check('репозиторий: после перезагрузки открыта запомненная папка', loads.length > 0 && loads[0].includes(`/${ids.dir}/get-data/`),
                JSON.stringify(loads));
            await Promise.all([p.waitForResponse((r) => r.url().includes('/get-data/')), p.click('#breadcrumbs a')]);
            await p.waitForTimeout(800);
            check('репозиторий: крошка ведёт назад — в папке видна папка теста', (await titles()).some((t) => t.includes('claude-grid-dir')),
                JSON.stringify(await titles()));
            check('репозиторий: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 7. the library in a form window: «…» → the remembered folder → a file → «Выбрать» — the path in the form
        {
            await ctx.addCookies([{ name: 'NRGNFRPID', value: String(ids.dir), url: BASE }]);
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + `admin/users/single/userEditor/${ids.user}/edit/`, { waitUntil: 'networkidle' });
            await showTab(p, 'button[onclick*="openFileLib"]');
            await p.click('button[onclick*="openFileLib"]');
            const el = await p.waitForSelector('.e-modalbox iframe', { timeout: 10000 });
            const f = await el.contentFrame();
            await f.waitForSelector('tbody tr td', { timeout: 10000 });
            await f.waitForTimeout(800);
            await f.locator('.gridContainer tbody tr', { hasText: 'claude-grid-big' }).first().click();
            await f.click('ul.toolbar li.open_btn');
            await p.waitForTimeout(800);
            const value = await p.evaluate(() => {
                const btn = document.querySelector('button[onclick*="openFileLib"]');
                return { path: document.getElementById(btn.getAttribute('link')).value, windows: document.querySelectorAll('.e-modalbox').length };
            });
            check('библиотека в окне формы: файл из папки — путь в поле формы, окно закрыто',
                value.path === 'uploads/public/claude-grid-dir/claude-grid-big.png' && value.windows === 0, JSON.stringify(value));
            check('библиотека в окне формы: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();   // the form is not saved
            await ctx.clearCookies({ name: 'NRGNFRPID' });
        }

        // 8. «Активировать» (users window, the inactive test user)
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            await p.goto(BASE + 'admin/users/single/userEditor/', { waitUntil: 'networkidle' });
            await filterGrid(p, 'claude-grid-off');
            await p.locator('.gridContainer tbody tr').nth(0).click();
            const before = db('user-active', String(ids.off)).trim();
            const [act] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/activate/'), { timeout: 10000 }),
                p.click('ul.toolbar li.activate_btn'),
            ]);
            await p.waitForResponse((r) => r.url().includes('/get-data/'), { timeout: 10000 }).catch(() => null);
            check('«Активировать»: запрос …/<id>/activate/, пользователь активен, грид перезагружен', before === '0'
                && act.url().endsWith(`/${ids.off}/activate/`) && db('user-active', String(ids.off)).trim() === '1', act.url());
            check('«Активировать»: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }

        // 9. «Очистить» the action log (the request is answered here — the log stays): a refusal sends nothing,
        //    the consent sends clear and reloads the grid
        {
            const p = await ctx.newPage();
            const errors = watch(p);
            let consent = false;
            p.on('dialog', (d) => (consent ? d.accept() : d.dismiss()));
            const clears = [];
            await p.route(/\/clear\/$/, (route) => {
                clears.push(route.request().url());
                route.fulfill({ status: 200, contentType: 'application/json', body: '{"result":true}' });
            });
            await p.goto(BASE + 'admin/action-log/single/actionsList/', { waitUntil: 'networkidle' });
            await p.click('ul.toolbar li.clear_btn');
            await p.waitForTimeout(600);
            const refused = clears.length;
            consent = true;
            const [reload] = await Promise.all([
                p.waitForRequest((r) => r.url().includes('/get-data/'), { timeout: 10000 }),
                p.click('ul.toolbar li.clear_btn'),
            ]);
            check('«Очистить» журнал: отказ — запроса нет, согласие — запрос clear и перезагрузка', refused === 0 && clears.length === 1
                && /\/clear\/$/.test(clears[0]) && !!reload, JSON.stringify({ refused, clears }));
            check('«Очистить» журнал: без ошибок JS и 404', !errors.list().length, errors.list().join(' | '));
            await p.close();
        }
```

(Файла `tests/audit/grids-step6-block.js` нет: блок вставляется в `grids.js` как есть.)

- [ ] **Step 3: Прогон до переделки.**

Run: `cd tests/audit && bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node grids.js' > $W/t1-grids.log 2>&1; grep -E '^FAIL|failures' $W/t1-grids.log`
Expected: FAIL — восемь «гриды без MooTools: …» (пользователи, роли, языки, переводы, шаблоны писем, журнал действий,
репозиторий файлов, библиотека файлов в окне формы), «репозиторий: размер файла меньше 1 КиБ — в байтах, без ошибки
JS» и «репозиторий: без ошибок JS и 404» (ошибка `toPrecision` у маленькой картинки); остальные — OK.

- [ ] **Step 4: Commit**

```bash
git add tests/audit/grids.js tests/audit/grids-db.php
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 6: проверки — гриды без MooTools, выбор строк, сортировка, колонки, репозиторий, действия" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 2: `Grid`, `GridManager`, `FileRepository`, `UserManager`, `ActionLogManager`

**Files:**
- Modify (весь файл): `core/modules/share/scripts/GridManager.js`, `core/modules/share/scripts/FileRepository.js`,
  `core/modules/user/scripts/UserManager.js`, `core/modules/share/scripts/ActionLogManager.js`
- Modify: `tests/no-traces.sh` (`VANILLA_JS` + четыре файла)

**Interfaces:**
- Consumes: `Filters(gridManager)` (`element`, `remove()`, `getValue()`; вызывает `gridManager.reload()`),
  `PageList({onPageSelect})` (`element`, `currentPage`, `disable()`, `enable()`, `build(n, current)`),
  `TabPane(element, {onTabChange})` (`element`), `Toolbar` (`element`, `controls`, `getControlById`, `disableControls`,
  `enableControls`, `bindTo`; у кнопки — `properties.action`, `disabled()`, `enable()`, `disable()`,
  `DisableAndSetProperty`, `EnableByProperty`), `Overlay(container)`, `ModalBox`, `Energine.request`,
  `Energine.readCookie/writeCookie/sitePath`, `Energine.placeholder`.
- Produces: интерфейс спецификации 2.1–2.3; `GridManager.prototype.createGrid(element, options)`,
  `Grid.clean(text)`, `Grid.scrollBarWidth()`, `FileRepository.Grid`, `PathList`.

- [ ] **Step 1: GridManager.js.** Заменить `core/modules/share/scripts/GridManager.js` целиком:

Full file `core/modules/share/scripts/GridManager.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[Grid]{@link Grid}</li>
 *     <li>[GridManager]{@link GridManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires Energine
 * @requires TabPane
 * @requires PageList
 * @requires Toolbar
 * @requires Overlay
 * @requires ModalBox
 * @requires Filters
 *
 * @author Pavel Dubenko
 * @author Valerii Zinchenko
 * @author Oleg Marichev
 *
 * @version 1.2.0
 */

// todo: Strange to use scrolling and changing pages to see more data fields.

ScriptLoader.load('TabPane', 'PageList', 'Toolbar', 'Overlay', 'ModalBox', 'Filters');

/**
 * Таблица грида: строки записей, выбор (Ctrl — ещё строка, Shift — диапазон), сортировка по заголовку, ширины колонок
 * и высота под панель и окно.
 *
 * @constructor
 * @param {Element} element Элемент .grid.
 * @param {Object} [options] Обработчики onSelect(строка), onSortChange(), onDoubleClick().
 */
var Grid = class Grid {
    constructor(element, options) {
        Energine.loadCSS('grid.css');
        this.element = element;
        this.options = Object.assign({}, options);
        /**
         * Data of the grid.
         * @type {Object[]}
         */
        this.data = null;
        /**
         * Metadata of the grid.
         * @type {Object}
         */
        this.metadata = null;
        /**
         * Selected rows.
         * @type {Element[]}
         */
        this.selectedItem = [];
        /**
         * Sort parameters.
         * @type {{field: string, order: string}}
         */
        this.sort = {field: null, order: null};

        // TODO: I think this.headOff can be removed, because it is always hidden.
        this.headOff = this.element.querySelector('.gridContainer thead');
        this.headOff.style.display = 'none';
        this.tbody = this.element.querySelector('.gridContainer tbody');
        this.headers = Array.from(this.element.querySelectorAll('.gridHeadContainer table.gridTable th'));
        this.headers.forEach((header) => header.addEventListener('click', (event) => this.onChangeSort(event)));

        // добавляем к контейнеру класс, который указывает, что в нем есть грид
        this.element.closest('.e-pane').classList.add('e-grid-pane');

        // вешаем пересчет размеров гридовой формы на ресайз окна
        if (document.querySelector('.e-singlemode-layout')) {
            window.addEventListener('resize', () => this.fitGridSize());
        } else {
            window.addEventListener('resize', () => this.fitGridFormSize());
        }
    }

    /**
     * Обработчик из параметров: 'select' → onSelect и т. д.
     *
     * @param {string} type
     * @param {...*} args
     */
    emit(type, ...args) {
        const handler = this.options['on' + type.charAt(0).toUpperCase() + type.slice(1)];
        if (handler) {
            handler(...args);
        }
    }

    /**
     * Set the metadata; the key field is the one marked key.
     *
     * @param {Object} metadata
     */
    setMetadata(metadata) {
        for (const fieldName in metadata) {
            if (metadata[fieldName].key) {
                /**
                 * Key field name.
                 * @type {string}
                 */
                this.keyFieldName = fieldName;
            }
        }
        this.metadata = metadata;
    }

    getMetadata() {
        return this.metadata;
    }

    /**
     * Set the data (metadata first).
     *
     * @param {Object[]} data
     * @returns {boolean}
     */
    setData(data) {
        if (!this.metadata) {
            alert('Cannot set data without specified metadata.');
            return false;
        }
        this.data = data;
        return true;
    }

    // кнопки с классом nomultiselect выключены, пока выбрано несколько строк
    disableControlByMultiselect() {
        this.multiselectControls().forEach((control) => control.DisableAndSetProperty('DisabledByMultiselect'));
    }

    enableControlByMultiselect() {
        this.multiselectControls().forEach((control) => control.EnableByProperty('DisabledByMultiselect'));
    }

    multiselectControls() {
        const manager = this.element.closest('.e-pane').GridManager;
        if (!manager || !manager.toolbar) {
            return [];
        }
        return manager.toolbar.controls.filter((control) => control.element.classList.contains('nomultiselect'));
    }

    /**
     * Выбрать строку: без multiple — только её; multiple — добавить к выбранным; rangeselect — ещё и строки между ней
     * и последней выбранной.
     *
     * @param {Element} item
     * @param {boolean} [multiple]
     * @param {boolean} [rangeselect]
     */
    selectItem(item, multiple, rangeselect) {
        if (!multiple) {
            this.deselectItem();
            this.enableControlByMultiselect();
        }
        if (item) {
            item.classList.add('selected');
            if (multiple) {
                this.disableControlByMultiselect();
                if (rangeselect && this.selectedItem.length > 0) {
                    const el = this.selectedItem[this.selectedItem.length - 1];
                    let findup = el, finddown = el;
                    while (findup.previousSibling || finddown.nextSibling) {
                        if (findup.previousSibling) {
                            findup = findup.previousSibling;
                        }
                        if (finddown.nextSibling) {
                            finddown = finddown.nextSibling;
                        }
                        if (findup === item) {
                            finddown = false;
                            break;
                        } else if (finddown === item) {
                            findup = false;
                            break;
                        }
                    }
                    if (finddown === false || findup === false) {
                        let selected = (finddown === false) ? findup.nextSibling : finddown.previousSibling;
                        while (selected !== el) {
                            selected.classList.add('selected');
                            this.selectedItem.push(selected);
                            this.emit('select', selected);
                            selected = (finddown === false) ? selected.nextSibling : selected.previousSibling;
                        }
                    }
                }
                this.selectedItem.push(item);
            } else {
                this.selectedItem = [item];
            }
            this.emit('select', item);
        }
    }

    deselectItem() {
        this.selectedItem.forEach((row) => row.classList.remove('selected'));
    }

    /**
     * Выбранная строка (первая) или, с аргументом, все выбранные; null — ничего не выбрано.
     *
     * @param {boolean} [returnAsArray]
     * @returns {Element|Element[]|null}
     */
    getSelectedItem(returnAsArray) {
        if (!arguments.length) {
            return (this.selectedItem.length) ? this.selectedItem[0] : null;
        }
        return (this.selectedItem.length) ? this.selectedItem : null;
    }

    /**
     * Поля записи в порядке заголовков: скрытые и особые (custom) — первыми; заголовок без поля в записи прячется.
     *
     * @param {Object} record
     * @param {Element[]} header
     * @returns {Object}
     */
    sortRecordAsHeadersName(record, header) {
        const sorted = {};
        for (const fieldName in record) {
            if ((this.metadata[fieldName].type == 'hidden') ^ (this.metadata[fieldName].type == 'custom')) {
                sorted[fieldName] = record[fieldName];
            }
        }
        for (let i = 0; i < header.length; i++) {
            const colname = header[i].getAttribute('name');
            if (Object.prototype.hasOwnProperty.call(record, colname)) {
                sorted[colname] = record[colname];
            } else {
                header[i].style.display = 'none';
            }
        }
        return sorted;
    }

    /**
     * Build the rows: the record selected before (if it is still there) is selected and scrolled into view,
     * otherwise the first row; then the columns and the height.
     */
    build() {
        let previouslySelectedRecordKey = this.getSelectedRecordKey();
        this.selectedItem = [];
        this.gridHeadContainer = this.element.querySelector('.gridHeadContainer');
        this.gridHeadContainerTabs = Array.from(this.gridHeadContainer.querySelectorAll('th'));
        this.paneContent = this.element.closest('.e-pane-item');
        this.gridToolbar = this.element.querySelector('.grid_toolbar');
        this.gridContainer = this.element.querySelector('.gridContainer');

        if (!this.isEmpty()) {
            if (!this.dataKeyExists(previouslySelectedRecordKey)) {
                previouslySelectedRecordKey = false;
            }
            this.data.forEach((record, id) => {
                this.addRecord(this.sortRecordAsHeadersName(record, this.gridHeadContainerTabs), id, previouslySelectedRecordKey);
            });
            if (!this.selectedItem.length && !previouslySelectedRecordKey) {
                this.selectItem(this.tbody.firstElementChild);
            }
        } else {
            this.tbody.appendChild(document.createElement('tr'));
        }

        this.adjustColumns();
        // растягиваем gridContainer на высоту родительского элемента минус фильтр и голова грида
        this.fitGridSize();
        if (!this.minGridHeight) {
            const h = Grid.style(this.gridContainer, 'height');
            //Если грид запустился внутри вкладки формы
            this.minGridHeight = h ? parseInt(h, 10) : 300;
        }

        /* растягиваем всю форму до высоты видимого окна */
        if (!document.querySelector('.e-singlemode-layout')) {
            this.pane = this.element.closest('.e-pane');
            this.gridBodyContainer = this.element.querySelector('.gridBodyContainer');
            this.fitGridFormSize();
        }
    }

    /**
     * Строка записи: ячейки полей, подсветка под мышью, выбор щелчком (Ctrl — ещё строка, Shift — диапазон),
     * двойной щелчок — onDoubleClick.
     *
     * @param {Object} record
     * @param {number} id номер записи (чётность — класс строки)
     * @param {*} currentKey ключ записи, выбранной до перезагрузки
     */
    addRecord(record, id, currentKey) {
        // Проверяем соответствие записи метаданным.
        for (const fieldName in record) {
            if (!this.metadata[fieldName]) {
                alert('Grid: record doesn\'t conform to metadata.');
                return;
            }
        }
        // Создаем новую строку в таблице.
        const row = document.createElement('tr');
        row.className = (id % 2 == 0) ? 'odd' : 'even';
        row.setAttribute('unselectable', 'on');
        this.tbody.appendChild(row);
        // Сохраняем запись в объекте строки.
        row.record = record;
        for (const fieldName in record) {
            this.iterateFields(fieldName, record, row);
        }
        // Помечаем первую ячейку строки.
        row.firstElementChild.classList.add('firstColumn');

        if (currentKey == record[this.keyFieldName]) {
            this.selectItem(row);
            // выбранная прежде запись — в видимой части списка
            const container = document.body.querySelector('.gridContainer');
            container.scrollTop += row.getBoundingClientRect().top - container.getBoundingClientRect().top;
        }

        row.addEventListener('mouseover', () => {
            if (row != this.getSelectedItem()) {
                row.classList.add('highlighted');
            }
        });
        row.addEventListener('mouseout', () => row.classList.remove('highlighted'));
        row.addEventListener('click', (event) => {
            if (!(event.ctrlKey || event.shiftKey)) {
                if (row != this.getSelectedItem()) {
                    this.selectItem(row);
                }
            } else if (event.shiftKey) {
                this.selectItem(row, true, true);
            } else {
                this.selectItem(row, true);
            }
        });
        row.addEventListener('dblclick', () => this.emit('doubleClick'));
    }

    /**
     * Ячейка поля записи (невидимые поля пропускаются).
     *
     * @param {string} fieldName
     * @param {Object} record
     * @param {Element} row
     */
    iterateFields(fieldName, record, row) {
        // Пропускаем невидимые поля.
        if (!this.metadata[fieldName].visible || this.metadata[fieldName].type == 'hidden') {
            return;
        }
        const cell = document.createElement('td');
        cell.setAttribute('unselectable', 'on');
        row.appendChild(cell);
        cell.classList.add(fieldName); // добавляем имя поля в класс
        switch (this.metadata[fieldName].type) {
            case 'boolean': {
                const checkbox = document.createElement('img');
                checkbox.setAttribute('src', 'images/checkbox_' + (record[fieldName] == true ? 'on' : 'off') + '.png');
                checkbox.setAttribute('width', '13');
                checkbox.setAttribute('height', '13');
                cell.appendChild(checkbox);
                cell.style.textAlign = 'center';
                cell.style.verticalAlign = 'middle';
                break;
            }
            // значения — текстом: в данных может оказаться разметка посетителя (обратная связь, регистрация)
            case 'value':
                cell.textContent = record[fieldName]['value'];
                break;
            case 'file':
                if (record[fieldName]) {
                    const image = document.createElement('img');
                    image.setAttribute('src', Energine.resizer + 'w40-h40/' + record[fieldName]);
                    image.setAttribute('width', 40);
                    image.setAttribute('height', 40);
                    cell.appendChild(image);
                    cell.style.textAlign = 'center';
                    cell.style.verticalAlign = 'middle';
                }
                break;
            default: {
                let fieldValue = '';
                if (record[fieldName] || record[fieldName] == 0) {
                    fieldValue = Grid.clean(record[fieldName].toString());
                }
                const prevRow = row.previousElementSibling;
                if ((this.metadata[fieldName].type == 'select') && (row.firstElementChild == cell) && prevRow
                    && (prevRow.record[fieldName] == record[fieldName])) {
                    fieldValue = '';
                    prevRow.firstElementChild.style.fontWeight = 'bold';
                }
                cell.textContent = (fieldValue != '') ? fieldValue : ' ';
            }
        }
    }

    /**
     * Ширины колонок заголовка — по ячейкам первой строки; заголовок шире своей ячейки — колонка по заголовку,
     * остальные сужаются пропорционально.
     */
    adjustColumns() {
        const headers = [];
        // Adjust padding-right for '.gridHeadContainer' element.
        this.gridHeadContainer.style.paddingRight = Grid.scrollBarWidth() + 'px';
        if (!this.element.querySelector('table.gridTable').classList.contains('fixed_columns')) {
            const tds = Array.from(this.tbody.querySelector('tr').querySelectorAll('td')),
                ths = Array.from(this.gridHeadContainer.querySelectorAll('th')),
                headCols = Array.from(this.gridHeadContainer.querySelectorAll('col')),
                bodyCols = Array.from(this.element.querySelectorAll('.gridContainer col'));
            const setWidth = (n) => {
                if (headCols[n] !== undefined) {
                    headCols[n].style.width = Math.round(headers[n]) + 'px';
                }
                if (bodyCols[n] !== undefined) {
                    bodyCols[n].style.width = Math.round(headers[n]) + 'px';
                }
            };

            // Get the col width from the tbody
            for (let n = 0; n < tds.length; n++) {
                headers[n] = Grid.totalWidth(tds[n]);
            }
            // Set col width
            for (let n = 0; n < tds.length; n++) {
                setWidth(n);
            }

            const oversizeHead = [];
            for (let n = 0; n < tds.length; n++) {
                if (ths[n] !== undefined) {
                    oversizeHead[n] = Grid.totalWidth(ths[n]) > headers[n];
                }
            }
            if (oversizeHead.length > 0) {
                const newWidth = [], colWidth = [0, 0];
                for (let n = 0; n < tds.length; n++) {
                    if (oversizeHead[n]) {
                        newWidth[n] = Grid.totalWidth(ths[n]);
                        colWidth[1] += newWidth[n] - headers[n];
                    } else {
                        colWidth[0] += headers[n];
                    }
                }
                colWidth[1] += colWidth[0];
                const scaleCoef = colWidth[0] / colWidth[1];
                for (let n = 0; n < tds.length; n++) {
                    headers[n] = (oversizeHead[n]) ? newWidth[n] : Math.floor(headers[n] * scaleCoef);
                    // Reset col width
                    setWidth(n);
                }
            }
        } else {
            this.tbody.parentElement.style.tableLayout = 'fixed';
        }
        this.tbody.parentElement.style.wordWrap = 'break-word';
    }

    /**
     * Высота списка — высота панели минус голова грида, фильтр, отступ и нижняя панель окна.
     */
    fitGridSize() {
        if (this.paneContent) {
            const margin = Grid.style(this.element, 'marginTop'),
                eBToolbar = document.body.querySelector('.e-pane-b-toolbar'),
                gridHeight = this.paneContent.offsetHeight
                    - this.gridHeadContainer.offsetHeight
                    - ((this.gridToolbar) ? this.gridToolbar.offsetHeight : 0)
                    - ((margin) ? parseInt(margin, 10) : 0)
                    - ((eBToolbar) ? eBToolbar.offsetHeight : 0);
            if (gridHeight > 0) {
                this.gridContainer.style.height = (gridHeight - 9) + 'px';
            }
        }
    }

    /**
     * Панель грида на странице — по содержимому, но не выше видимой части окна; затем высота списка.
     */
    fitGridFormSize() {
        if (this.pane) {
            const toolbarH = (this.gridToolbar) ? this.gridToolbar.offsetHeight : 0,
                gridHeadH = Grid.totalHeight(this.gridHeadContainer),
                paneToolbarT = this.pane.querySelector('.e-pane-t-toolbar'),
                paneToolbarTH = (paneToolbarT) ? paneToolbarT.offsetHeight : 0,
                paneToolbarB = this.pane.querySelector('.e-pane-b-toolbar'),
                paneToolbarBH = (paneToolbarB) ? paneToolbarB.offsetHeight : 0,
                paneH = this.pane.offsetHeight,
                margin = Grid.style(this.element, 'marginTop'),
                gridBodyContainer = this.element.querySelector('.gridBodyContainer');
            let gridBodyHeight = gridBodyContainer.offsetHeight
                + parseInt(Grid.style(this.gridContainer, 'borderTopWidth'), 10)
                + parseInt(Grid.style(this.gridContainer, 'borderBottomWidth'), 10);

            if (gridBodyHeight < this.minGridHeight) {
                gridBodyHeight = this.minGridHeight;
            }

            /*
             * +3 at the end is:
             *   +2 from e-pane-content border
             *   +1 from somewhere, I do not why this should be
             */
            const totalH = toolbarH + gridHeadH + gridBodyHeight + paneToolbarTH + paneToolbarBH
                + ((margin) ? parseInt(margin, 10) : 0) + 3;

            /*
             * -81 at the end is:
             *   -31 from e-topframe height
             *   -50 from footer
             * they are not visible from grid
             */
            const windowHeight = document.documentElement.clientHeight;
            let freespace = windowHeight;

            if (document.body.scrollHeight - Grid.scrollBarWidth() < windowHeight) {
                freespace -= Grid.pageY(this.pane) + Grid.scrollBarWidth();
            }

            if (totalH > paneH) {
                this.pane.style.height = Math.round((totalH > freespace) ? freespace : totalH) + 'px';
                const leftCol = document.querySelectorAll('div[column=left]');//ugly

                if (this.pane.parentNode.parentNode.parentNode.classList.contains('fitGridHeightToLeftCol') && leftCol.length) {
                    const fitGridHeightToLeftCol = leftCol.clientHeight - (toolbarH + gridHeadH - 30);//ugly

                    this.pane.style.height = Math.round(fitGridHeightToLeftCol) + 'px';
                }
            }

            this.fitGridSize();
        }
    }

    isEmpty() {
        return !this.data.length;
    }

    /**
     * Record of the selected row or false.
     * @returns {Object|boolean}
     */
    getSelectedRecord() {
        if (!this.getSelectedItem()) {
            return false;
        }
        return this.getSelectedItem().record;
    }

    /**
     * Selected rows or false.
     * @returns {Element[]|boolean}
     */
    getSelectedRecords() {
        if (!this.getSelectedItem(true)) {
            return false;
        }
        return this.getSelectedItem(true);
    }

    /**
     * Ключ выбранной записи; с аргументом и несколькими выбранными — ключи через запятую; false — ничего не выбрано.
     *
     * @param {boolean} [multiple]
     * @returns {*}
     */
    getSelectedRecordKey(multiple) {
        if (arguments.length < 1 || this.selectedItem.length < 2) {
            if (!this.keyFieldName || !this.getSelectedRecord()) {
                return false;
            }
            return this.getSelectedRecord()[this.keyFieldName];
        }
        if (!this.keyFieldName || !this.getSelectedRecords()) {
            return false;
        }
        return this.getSelectedRecords().map((row) => row.record[this.keyFieldName]).join(',');
    }

    /**
     * Есть ли запись с этим ключом.
     *
     * @param {*} key
     * @returns {boolean}
     */
    dataKeyExists(key) {
        if (!this.data || !this.keyFieldName) {
            return false;
        }
        return this.data.some((item) => item[this.keyFieldName] == key);
    }

    clear() {
        this.deselectItem();
        this.tbody.replaceChildren();
    }

    /**
     * Щелчок по заголовку сортируемой колонки: порядок по кругу «нет → по возрастанию → по убыванию».
     *
     * @param {Object} event
     */
    onChangeSort(event) {
        const sortDirectionOrder = ['', 'asc', 'desc'],
            next = (current) => {
                const index = sortDirectionOrder.indexOf(current || '');
                return (index != -1 && index + 1 < sortDirectionOrder.length) ? sortDirectionOrder[index + 1] : sortDirectionOrder[0];
            };
        const header = event.target,
            sortFieldName = header.getAttribute('name'),
            sortDirection = header.getAttribute('class');

        //проверяем есть ли колонка сортировки в списке колонок
        if (this.metadata[sortFieldName] && this.metadata[sortFieldName].sort == 1) {
            this.sort.field = sortFieldName;
            this.sort.order = next(sortDirection);
            header.className = this.sort.order;
            this.emit('sortChange');
        }
    }

    /**
     * Строка без лишних пробелов (clean MooTools).
     *
     * @param {string} text
     * @returns {string}
     */
    static clean(text) {
        return String(text).replace(/\s+/g, ' ').trim();
    }

    /**
     * Стиль элемента: заданный в атрибуте style, иначе вычисленный (getStyle MooTools).
     *
     * @param {Element} element
     * @param {string} property
     * @returns {string}
     */
    static style(element, property) {
        return element.style[property] || getComputedStyle(element)[property];
    }

    /**
     * Ширина с полями и рамками целыми пикселями (getComputedSize MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static totalWidth(element) {
        const px = (property) => parseInt(Grid.style(element, property), 10) || 0,
            width = Grid.style(element, 'width');
        return ((width === 'auto') ? element.offsetWidth : (parseInt(width, 10) || 0))
            + px('paddingLeft') + px('paddingRight') + px('borderLeftWidth') + px('borderRightWidth');
    }

    /**
     * Высота с полями и рамками целыми пикселями (getComputedSize MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static totalHeight(element) {
        const px = (property) => parseInt(Grid.style(element, property), 10) || 0,
            height = Grid.style(element, 'height');
        return ((height === 'auto') ? element.offsetHeight : (parseInt(height, 10) || 0))
            + px('paddingTop') + px('paddingBottom') + px('borderTopWidth') + px('borderBottomWidth');
    }

    /**
     * Верх элемента от начала документа (getPosition MooTools).
     *
     * @param {Element} element
     * @returns {number}
     */
    static pageY(element) {
        const html = document.documentElement;
        return parseInt(element.getBoundingClientRect().top, 10) + (window.pageYOffset || html.scrollTop) - html.clientTop;
    }

    /**
     * Ширина полосы прокрутки: у верхнего окна, если оно её уже измерило, иначе — измеряется здесь, один раз.
     *
     * @returns {number}
     */
    static scrollBarWidth() {
        if (typeof window.ScrollBarWidth !== 'number') {
            let width = null;
            try {
                width = window.top.ScrollBarWidth;
            } catch (e) {
            }
            if (!width || typeof width !== 'number') {
                const outer = document.createElement('div'),
                    inner = document.createElement('div');
                outer.style.cssText = 'height: 1px; overflow: scroll; visibility: hidden';
                inner.style.height = '2px';
                outer.appendChild(inner);
                document.body.appendChild(outer);
                width = outer.offsetWidth - inner.offsetWidth;
                outer.remove();
            }
            window.ScrollBarWidth = width;
        }
        return window.ScrollBarWidth;
    }
};

/**
 * Грид с панелью, листалкой, фильтром и вкладками языков: загрузка страниц записей, действия кнопок панели, окна
 * правки (ответ окна — processAfterCloseAction).
 *
 * @constructor
 * @param {Element|string} element Элемент компонента (или его id).
 */
var GridManager = class GridManager {
    constructor(element) {
        /**
         * Id of the record that is moved (state /move/).
         * @type {number|string}
         */
        this.mvElementId = null;
        /**
         * Language ID.
         * @type {number}
         */
        this.langId = 0;
        this.toolbar = null;
        this.initialized = false;
        this.element = (typeof element === 'string') ? document.getElementById(element) : element;
        this.element.GridManager = this;

        // документ родительского окна — без методов MooTools: её может не быть там (страница сайта у администратора)
        if (window.parent.document.querySelector('form.e-grid-form')) {
            this.element.classList.add('inside-form');
        }

        this.delConfirmCounter = 0;
        this.filter = new Filters(this);
        this.pageList = new PageList({onPageSelect: (pageNum) => this.loadPage(pageNum)});
        this.grid = this.createGrid(this.element.querySelector('.grid'), {
            onSelect: (item) => this.onSelect(item),
            onSortChange: () => this.onSortChange(),
            onDoubleClick: () => this.onDoubleClick()
        });
        this.tabPane = new TabPane(this.element, {onTabChange: (data) => this.onTabChange(data)});

        const toolbarContainer = this.tabPane.element.querySelector('.e-pane-b-toolbar');
        if (toolbarContainer) {
            toolbarContainer.appendChild(this.pageList.element);
            this.tabPane.element.classList.remove('e-pane-has-b-toolbar1');
            this.tabPane.element.classList.add('e-pane-has-b-toolbar2');
        } else {
            this.tabPane.element.appendChild(this.pageList.element);
        }

        this.overlay = new Overlay(this.element);
        this.singlePath = this.element.getAttribute('single_template');

        // инициализация id записи, которую будем двигать в стейте /move/
        const moveFromId = this.element.getAttribute('move_from_id');
        if (moveFromId) {
            this.setMvElementId(moveFromId);
        }

        this.reload();
    }

    /**
     * Таблица грида; наследник может подставить свою (файловый репозиторий).
     *
     * @param {Element} element .grid
     * @param {Object} options обработчики
     * @returns {Grid}
     */
    createGrid(element, options) {
        return new Grid(element, options);
    }

    setMvElementId(id) {
        this.mvElementId = id;
    }

    getMvElementId() {
        return this.mvElementId;
    }

    clearMvElementId() {
        this.mvElementId = null;
    }

    /**
     * Панель — над гридом (в .e-pane-t-toolbar), кнопки выключены до загрузки записей.
     *
     * @param {Toolbar} toolbar
     */
    attachToolbar(toolbar) {
        this.toolbar = toolbar;
        const toolbarContainer = this.tabPane.element.querySelector('.e-pane-t-toolbar');
        (toolbarContainer || this.tabPane.element).prepend(this.toolbar.element);
        this.toolbar.disableControls();
        toolbar.bindTo(this);
    }

    /**
     * Другая вкладка языка: фильтр сбрасывается, записи — на её языке.
     *
     * @param {Object} data {lang}
     */
    onTabChange(data) {
        this.langId = data.lang;
        // Загружаем первую страницу только если панель инструментов уже прикреплена.
        if (this.filter.element) {
            this.filter.remove();
        }
        this.reload();
    }

    onSelect() {
    }

    /**
     * Двойной щелчок: правка, если можно, иначе первое действие панели.
     */
    onDoubleClick() {
        let c;
        if ((c = this.toolbar.getControlById('edit')) && !c.disabled()) {
            this.edit();
        } else if (this.toolbar.controls.length) {
            const action = this.toolbar.controls[0].properties.action;
            if (this[action] && !this.toolbar.controls[0].disabled()) {
                this[action]();
            }
        }
    }

    onSortChange() {
        this.loadPage(1);
    }

    reload() {
        this.loadPage(1);
    }

    /**
     * Загрузить страницу записей: листалка и кнопки выключены, грид затемнён и пуст до ответа.
     *
     * @param {number} pageNum
     */
    loadPage(pageNum) {
        this.pageList.disable();
        // todo: The toolbar is attached later as this function calls.
        if (this.toolbar) {
            this.toolbar.disableControls();
        }
        this.overlay.show();
        this.grid.clear();

        // запрос — после текущего обработчика, как прежде: в Firefox 26 панель иначе мерилась до перерисовки
        setTimeout(() => {
            Energine.request(
                this.buildRequestURL(pageNum),
                this.buildRequestPostBody(),
                (result) => this.processServerResponse(result),
                null,
                (responseText) => this.processServerError(responseText)
            );
        }, 0);
    }

    /**
     * Адрес страницы записей (с сортировкой, если она выбрана).
     *
     * @param {number|string} pageNum
     * @returns {string}
     */
    buildRequestURL(pageNum) {
        if (this.grid.sort.order) {
            return this.singlePath + 'get-data/' + this.grid.sort.field + '-' + this.grid.sort.order + '/page-' + pageNum;
        }
        return this.singlePath + 'get-data/page-' + pageNum;
    }

    /**
     * Тело запроса: язык вкладки и фильтр.
     *
     * @returns {string}
     */
    buildRequestPostBody() {
        let postBody = '';
        if (this.langId) {
            postBody += 'languageID=' + this.langId + '&';
        }
        if (this.filter) {
            postBody += this.filter.getValue();
        }
        return postBody;
    }

    /**
     * Ответ со страницей записей: метаданные (один раз), записи, листалка, кнопки; грид строится заново.
     *
     * @param {Object} result
     */
    processServerResponse(result) {
        let control = false;
        if (this.toolbar) {
            control = this.toolbar.getControlById('add');
        }
        if (!this.initialized) {
            this.grid.setMetadata(result.meta);
            this.initialized = true;
        }
        this.grid.setData(result.data || []);
        if (result.pager) {
            this.pageList.build(result.pager.count, result.pager.current);
        }
        if (!this.grid.isEmpty()) {
            if (this.toolbar) {
                this.toolbar.enableControls();
            }
            this.pageList.enable();
        }
        if (control) {
            control.enable();
        }
        this.grid.build();
        this.overlay.hide();
    }

    /**
     * Ошибка сервера: текст — администратору, затемнение снимается.
     *
     * @param {string} responseText
     */
    processServerError(responseText) {
        alert(responseText);
        this.overlay.hide();
    }

    /**
     * Ответ окна правки: действие, названное в ответе (afterClose), иначе — та же страница заново.
     *
     * @param {Object} returnValue
     */
    processAfterCloseAction(returnValue) {
        if (returnValue) {
            if (returnValue.afterClose && this[returnValue.afterClose]) {
                try {
                    this[returnValue.afterClose]();
                } catch (e) {
                    console.error(e);
                }
            } else {
                this.loadPage(this.pageList.currentPage);
            }
        }
    }

    // Actions:
    view() {
        ModalBox.open({url: this.singlePath + this.grid.getSelectedRecordKey()});
    }

    add() {
        ModalBox.open({
            url: this.singlePath + 'add/',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    edit(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        ModalBox.open({
            url: this.singlePath + id + '/edit',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    move(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.setMvElementId(id);
        ModalBox.open({
            url: this.singlePath + 'move/' + id,
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    moveFirst() {
        this.moveTo('first', this.grid.getSelectedRecordKey());
    }

    moveLast() {
        this.moveTo('last', this.grid.getSelectedRecordKey());
    }

    moveAbove(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.moveTo('above', this.getMvElementId(), id);
    }

    moveBelow(id) {
        if (!parseInt(id)) {
            id = this.grid.getSelectedRecordKey();
        }
        this.moveTo('below', this.getMvElementId(), id);
    }

    /**
     * Передвинуть запись; ответ окну — перезагрузить грид.
     *
     * @param {string} dir first, last, above, below
     * @param {number|string} fromId
     * @param {number|string} [toId]
     */
    moveTo(dir, fromId, toId) {
        toId = toId || '';
        this.overlay.show();
        Energine.request(this.singlePath + 'move/' + fromId + '/' + dir + '/' + toId + '/',
            null,
            () => {
                this.overlay.hide();
                ModalBox.setReturnValue(true); // reload
                this.reload();
            },
            () => this.overlay.hide(),
            (responseText) => {
                alert(responseText);
                this.overlay.hide();
            }
        );
    }

    editPrev() {
        let prevRow;
        if (this.grid.getSelectedItem() && (prevRow = this.grid.getSelectedItem().previousElementSibling)) {
            this.grid.selectItem(prevRow);
            this.edit();
        }
    }

    editNext() {
        let nextRow;
        if (this.grid.getSelectedItem() && (nextRow = this.grid.getSelectedItem().nextElementSibling)) {
            this.grid.selectItem(nextRow);
            this.edit();
        }
    }

    /**
     * Удалить выбранные записи (несколько — одним запросом «1,2,3/delete/»); после двух подтверждений подряд больше
     * не спрашивает, как прежде.
     */
    del() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete selected record?';
        if ((this.delConfirmCounter > 1) || confirm(MSG_CONFIRM_DELETE)) {
            this.delConfirmCounter++;
            this.overlay.show();
            let delstr = this.grid.getSelectedRecordKey(true);
            if (delstr === false) {
                this.overlay.hide();
                this.delConfirmCounter = 0;
                return;
            }
            delstr += '/delete/';
            Energine.request(this.singlePath + delstr, null,
                () => {
                    this.overlay.hide();
                    this.loadPage(this.pageList.currentPage);
                },
                () => this.overlay.hide(),
                (responseText) => {
                    alert(responseText);
                    this.overlay.hide();
                }
            );
        } else {
            this.delConfirmCounter = 0;
        }
    }

    use() {
        ModalBox.setReturnValue(this.grid.getSelectedRecord());
        ModalBox.close();
    }

    close() {
        ModalBox.close();
    }

    up() {
        const page = this.pageList.currentPage;
        Energine.request(this.singlePath + this.grid.getSelectedRecordKey() + '/up/',
            (this.filter) ? this.filter.getValue() : null, () => this.loadPage(page));
    }

    down() {
        const page = this.pageList.currentPage;
        Energine.request(this.singlePath + this.grid.getSelectedRecordKey() + '/down/',
            (this.filter) ? this.filter.getValue() : null, () => this.loadPage(page));
    }

    print() {
        window.open(this.element.getAttribute('single_template') + 'print/');
    }

    csv() {
        document.location.href = this.element.getAttribute('single_template') + 'csv/';
    }
};
```

- [ ] **Step 2: FileRepository.js.** Заменить целиком:

Full file `core/modules/share/scripts/FileRepository.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[FileRepository]{@link FileRepository}</li>
 *     <li>[FileRepository.Grid]{@link FileRepository.Grid}</li>
 *     <li>[PathList]{@link PathList}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires GridManager
 *
 * @author Pavel Dubenko
 */

ScriptLoader.load('GridManager');

/**
 * Cookie с папкой, открытой последней.
 * @type {string}
 */
var FILE_COOKIE_NAME = 'NRGNFRPID';

/**
 * Файловый репозиторий: двойной щелчок по папке открывает её, по файлу — выбор (в окне выбора) или правка; хлебные
 * крошки ведут в папки пути; папка запоминается в cookie.
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
var FileRepository = class FileRepository extends GridManager {
    constructor(element) {
        super(element);
        document.FileRepository = this;
        /**
         * Path (bread crumbs).
         * @type {PathList}
         */
        this.pathBreadCrumbs = new PathList(this.element.querySelector('#breadcrumbs'));
        document.querySelectorAll('.e-pane-toolbar.e-tabs.clearfix .current').forEach((tab) => {
            tab.style.padding = '0px';
            tab.style.width = '100%';
            tab.appendChild(this.element.querySelector('#breadcrumbs'));
        });
        /**
         * Current folder.
         * @type {number|string}
         */
        this.currentPID = '';
    }

    /**
     * Файловый грид вместо обычного.
     *
     * @param {Element} element
     * @param {Object} options
     * @returns {FileRepository.Grid}
     */
    createGrid(element, options) {
        return new FileRepository.Grid(element, options);
    }

    onDoubleClick() {
        this.open();
    }

    /**
     * Кнопки по типу выбранной строки и правам папки (upl_allows_*).
     */
    onSelect() {
        this.toolbar.enableControls();
        const r = this.grid.getSelectedRecord(),
            openBtn = this.toolbar.getControlById('open');
        switch (r.upl_internal_type) {
            case 'folder':
                if (openBtn) {
                    openBtn.enable();
                }
                break;
            case 'folderup':
                this.toolbar.disableControls();
                if (openBtn) {
                    openBtn.enable();
                }
                if (this.toolbar.getControlById('addDir')) {
                    this.toolbar.getControlById('addDir').enable();
                }
                if (this.toolbar.getControlById('add')) {
                    this.toolbar.getControlById('add').enable();
                }
                break;
            case 'repo':
                this.toolbar.disableControls();
                if (openBtn) {
                    openBtn.enable();
                }
                break;
            default:
                break;
        }

        const btn_map = {
            'addDir': 'upl_allows_create_dir',
            'add': 'upl_allows_upload_file',
            'edit': (r.upl_internal_type == 'folder') ? 'upl_allows_edit_dir' : 'upl_allows_edit_file',
            'delete': (r.upl_internal_type == 'folder') ? 'upl_allows_delete_dir' : 'upl_allows_delete_file'
        };
        for (const btn in btn_map) {
            const control = this.toolbar.getControlById(btn);
            if (r[btn_map[btn]] && control && !control.disabled()) {
                control.enable();
            } else if (control) {
                control.disable();
            }
        }
    }

    /**
     * Ответ со страницей папки: папка — в cookie на сутки, крошки пути, грид.
     *
     * @param {Object} result
     */
    processServerResponse(result) {
        // todo: It is better to set this width as fixed over CSS.
        this.grid.headOff.querySelector('th').style.width = '100px';
        if (!this.initialized) {
            this.grid.setMetadata(result.meta);
            this.initialized = true;
        }
        if (!result.data) {
            result.data = [];
        }
        if (this.currentPID) {
            Energine.writeCookie(FILE_COOKIE_NAME, this.currentPID, {path: Energine.sitePath(), days: 1});
        }
        this.grid.setData(result.data);
        if (result.pager) {
            this.pageList.build(result.pager.count, result.pager.current);
        }
        if (!this.grid.isEmpty()) {
            this.toolbar.enableControls();
            this.pageList.enable();
        }
        this.pathBreadCrumbs.load(result.breadcrumbs, (upl_id) => {
            this.currentPID = upl_id;
            if (this.filter) {
                this.filter.remove();
            }
            this.loadPage(1);
        });
        this.grid.build();
        this.overlay.hide();
    }

    /**
     * Открыть выбранное: хранилище и папку — их файлы; файл — выбор (если есть кнопка «Выбрать») или правка.
     */
    open() {
        const r = this.grid.getSelectedRecord();
        switch (r.upl_internal_type) {
            case 'repo':
            case 'folder':
                this.currentPID = r.upl_id;
                if (this.filter) {
                    this.filter.remove();
                }
                this.loadPage(1);
                break;
            case 'folderup':
                this.currentPID = r.upl_id;
                this.loadPage(1);
                break;
            default:
                if (this.toolbar.getControlById('open')) {
                    if (r['upl_path']) {
                        r['upl_path'] = r['upl_path'].split('?')[0];
                    }
                    ModalBox.setReturnValue(r);
                    ModalBox.close();
                } else {
                    this.edit();
                }
                break;
        }
    }

    add() {
        let pid = this.grid.getSelectedRecord().upl_pid;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'add/',
            onClose: (returnValue) => this.processAfterCloseAction(returnValue)
        });
    }

    addDir() {
        let pid = this.grid.getSelectedRecord().upl_pid;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'add-dir/',
            onClose: (response) => {
                if (response && response.result) {
                    this.currentPID = response.data;
                    this.processAfterCloseAction(response);
                }
            }
        });
    }

    moveToDir() {
        let pid = this.grid.getSelectedRecord().upl_id;
        if (pid) {
            pid += '/';
        }
        ModalBox.open({
            url: this.singlePath + pid + 'moveToDir/',
            onClose: () => this.reload()
        });
    }

    copy() {
        let pid = this.grid.getSelectedRecord().upl_id;
        if (pid) {
            pid += '/';
        }
        Energine.request(this.singlePath + pid + 'copy/', '', () => document.FileRepository.reload());
    }

    /**
     * Загрузка zip-архива (кнопка-файл панели).
     *
     * @param {Object} data прочитанный файл
     */
    uploadZip(data) {
        Energine.request(this.singlePath + 'upload-zip', 'PID=' + this.grid.getSelectedRecord().upl_pid + '&data='
            + encodeURIComponent(data.result), (response) => console.log(response));
    }

    /**
     * Адрес страницы папки: текущей, иначе — запомненной в cookie.
     *
     * @param {number|string} pageNum
     * @returns {string}
     */
    buildRequestURL(pageNum) {
        let level = '';
        const cookiePID = Energine.readCookie(FILE_COOKIE_NAME);
        if (this.currentPID === 0) {
            level = '';
        } else if (this.currentPID) {
            level = this.currentPID + '/';
        } else if (cookiePID) {
            this.currentPID = cookiePID;
            level = this.currentPID + '/';
        }
        if (this.grid.sort.order) {
            return this.singlePath + level + 'get-data/' + this.grid.sort.field + '-' + this.grid.sort.order + '/page-' + pageNum + '/';
        }
        return this.singlePath + level + 'get-data/' + 'page-' + pageNum + '/';
    }

    buildRequestPostBody() {
        let postBody = '';
        if (this.filter) {
            postBody += this.filter.getValue();
        }
        return postBody;
    }
};

/**
 * Грид файлового репозитория: значки папок и хранилищ, превью картинок (наведение — увеличенная), свойства файла и его
 * размер, название — ссылкой на файл.
 *
 * @augments Grid
 *
 * @constructor
 * @param {Element} element
 * @param {Object} [options]
 */
FileRepository.Grid = class FileRepositoryGrid extends Grid {
    /**
     * Увеличенная картинка над превью: появляется по его центру и растёт до 298×224; уходит по щелчку или уходу мыши.
     *
     * @param {string} path путь картинки
     * @param {Element} tmplElement превью
     */
    popImage(path, tmplElement) {
        const popUpImg = document.createElement('img');
        popUpImg.setAttribute('src', Energine.resizer + 'w298-h224/' + path);
        popUpImg.setAttribute('width', 60);
        popUpImg.setAttribute('height', 45);
        Object.assign(popUpImg.style, {
            border: '1px solid gray',
            borderRadius: '10px',
            zIndex: 1,
            position: 'absolute',
            transition: 'width 250ms linear, height 250ms linear'
        });
        popUpImg.addEventListener('click', () => popUpImg.remove());
        popUpImg.addEventListener('mouseleave', () => popUpImg.remove());
        document.body.appendChild(popUpImg);

        const rect = tmplElement.getBoundingClientRect();
        popUpImg.style.left = Math.round(rect.left + window.pageXOffset + (rect.width - 60) / 2) + 'px';
        popUpImg.style.top = Math.round(rect.top + window.pageYOffset + (rect.height - 45) / 2) + 'px';
        // размер меняется после первой отрисовки — так рост виден
        requestAnimationFrame(() => requestAnimationFrame(() => {
            popUpImg.style.width = '298px';
            popUpImg.style.height = '224px';
        }));
    }

    // overridden
    iterateFields(fieldName, record, row) {
        // Пропускаем невидимые поля.
        if (!this.metadata[fieldName].visible || this.metadata[fieldName].type == 'hidden') {
            return;
        }
        let fieldValue = '';
        const cell = document.createElement('td');
        row.appendChild(cell);
        switch (fieldName) {
            case 'upl_path':
                this.thumbnail(cell, record, fieldName);
                break;
            case 'upl_publication_date':
                if (record[fieldName]) {
                    fieldValue = Grid.clean(record[fieldName]);
                }
                cell.textContent = fieldValue;
                break;
            case 'upl_properties': {
                const propsTable = document.createElement('tbody'),
                    table = document.createElement('table');
                cell.classList.add('properties');
                table.appendChild(propsTable);
                cell.appendChild(table);
                if (!/folder|repo/.test(record['upl_internal_type'])) {
                    if (record['upl_mime_type']) {
                        FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_mime_type'].title + ' :', record['upl_mime_type']);
                    }
                    if (record['upl_internal_type'] == 'image') {
                        if (record['upl_width']) {
                            FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_width'].title + ' :', record['upl_width']);
                        }
                        if (record['upl_height']) {
                            FileRepository.Grid.propertyRow(propsTable, this.metadata['upl_height'].title + ' :', record['upl_height']);
                        }
                    }
                }
                break;
            }
            case 'upl_title':
                if (record[fieldName]) {
                    fieldValue = Grid.clean(record[fieldName]);
                }
                // название — текстом: его пишет редактор, в нём может оказаться разметка
                if (!/folder|repo/.test(record['upl_internal_type'])) {
                    const link = document.createElement('a');
                    link.target = '_blank';
                    link.href = Energine.media + record['upl_path'];
                    link.textContent = fieldValue;
                    cell.appendChild(link);
                } else {
                    cell.textContent = fieldValue;
                }
                break;
            default:
                break;
        }
    }

    /**
     * Значок строки: папка, хранилище, «наверх», файл; у картинки — превью 60×45 (наведение на 0,7 с — увеличенная,
     * ошибка загрузки — заглушка без увеличения) и размер файла в свойствах (запрос HEAD).
     *
     * @param {Element} cell
     * @param {Object} record
     * @param {string} fieldName
     */
    thumbnail(cell, record, fieldName) {
        cell.style.textAlign = 'center';
        cell.style.verticalAlign = 'middle';
        const image = document.createElement('img'),
            container = document.createElement('div');
        image.setAttribute('src', 'about:blank');
        container.className = 'thumb_container';
        cell.appendChild(container);
        let dimensions = {width: 40, height: 40};

        switch (record['upl_internal_type']) {
            case 'folder':
                dimensions = {width: 50, height: 50};
                image.setAttribute('src', 'images/icons/icon_folder.png');
                break;
            case 'repo':
                image.setAttribute('src', 'images/icons/icon_repository.gif');
                if (record['upl_path'] == 'uploads/public') {
                    image.setAttribute('src', 'images/icons/public.png');
                }
                if (record['upl_path'] == 'uploads/user_files') {
                    image.setAttribute('src', 'images/icons/user_files.png');
                }
                break;
            case 'folderup':
                dimensions = {width: 80, height: 78};
                image.setAttribute('src', 'images/icons/icon_folder_up2.png');
                break;
            case 'image': {
                dimensions = {width: 60, height: 45};
                let tmt;
                const target = (event) => (event.target.tagName === 'IMG') ? event.target : event.target.querySelector('img'),
                    enter = (event) => {
                        const el = target(event);
                        el.style.border = '1px solid gray';
                        tmt = setTimeout(() => this.popImage(record[fieldName], el), 700);
                    },
                    leave = (event) => {
                        target(event).style.border = '1px solid transparent';
                        if (tmt) {
                            clearTimeout(tmt);
                        }
                    };
                image.setAttribute('src', Energine.resizer + 'w60-h45/' + record[fieldName]);
                image.addEventListener('error', () => {
                    image.setAttribute('src', Energine.placeholder(60, 45));
                    container.removeEventListener('mouseenter', enter);
                    container.removeEventListener('mouseleave', leave);
                });
                image.style.borderRadius = '5px';
                image.style.border = '1px solid transparent';
                container.addEventListener('mouseenter', enter);
                container.addEventListener('mouseleave', leave);
                this.fileSize(cell, record[fieldName]);
                break;
            }
            default:
                dimensions = {width: 39, height: 48};
                image.setAttribute('src', 'images/icons/icon_undefined.gif');
                break;
        }
        image.setAttribute('width', dimensions.width);
        image.setAttribute('height', dimensions.height);
        container.appendChild(image);
    }

    /**
     * Размер файла (заголовок Content-Length ответа на HEAD) — строкой в таблицу свойств строки.
     *
     * @param {Element} cell ячейка строки файла
     * @param {string} path путь файла
     */
    fileSize(cell, path) {
        fetch(path, {method: 'HEAD', credentials: 'same-origin'}).then((response) => {
            const length = response.headers.get('Content-Length'),
                props = cell.parentNode && cell.parentNode.getElementsByClassName('properties');
            if (response.status != 200 || length === null || !props || !props.length) {
                return;
            }
            let size = Number(length), sizeAbbr = 'B';
            if (size > 1024) {
                size = size / 1024;
                sizeAbbr = 'KiB';
                if (size > 1024) {
                    size = size / 1024;
                    sizeAbbr = 'MiB';
                    if (size > 1024) {
                        size = size / 1024;
                        sizeAbbr = 'GiB';
                    }
                }
            }
            FileRepository.Grid.propertyRow(props[0].getElementsByTagName('tbody')[0],
                Energine.translations.get('TXT_FILE_SIZE') + ':', size.toPrecision(3) + ' ' + sizeAbbr);
        }).catch(() => {
        });
    }

    /**
     * Строка таблицы свойств: подпись и значение — текстом.
     *
     * @param {Element} tbody
     * @param {string} title
     * @param {*} value
     */
    static propertyRow(tbody, title, value) {
        const tr = document.createElement('tr');
        [title, value].forEach((text) => {
            const td = document.createElement('td');
            td.textContent = text;
            tr.appendChild(td);
        });
        tbody.appendChild(tr);
    }
};

/**
 * Хлебные крошки: папки пути — ссылками.
 *
 * @constructor
 * @param {Element|string} el
 */
var PathList = class PathList {
    constructor(el) {
        this.element = (typeof el === 'string') ? document.getElementById(el) : el;
    }

    /**
     * Путь: {id: название}; щелчок по папке — loader(id).
     *
     * @param {Object} data
     * @param {function} loader
     */
    load(data, loader) {
        this.element.replaceChildren();
        Object.entries(data || {}).forEach(([id, title]) => {
            const link = document.createElement('a'),
                divider = document.createElement('span');
            link.href = '#';
            link.textContent = title;
            link.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                loader(id);
            });
            divider.textContent = ' / ';
            this.element.append(link, divider);
        });
    }
};
```

- [ ] **Step 3: UserManager.js и ActionLogManager.js.**

Full file `core/modules/user/scripts/UserManager.js`:
```js
/**
 * @file Contain the description of the next classes:
 * <ul>
 *     <li>[UserManager]{@link UserManager}</li>
 * </ul>
 * Чистый JavaScript, без MooTools.
 *
 * @requires share/GridManager
 *
 * @author Pavel Dubenko
 *
 * @version 1.1.0
 */

ScriptLoader.load('GridManager');

/**
 * Пользователи: «Активировать».
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
var UserManager = class UserManager extends GridManager {
    /**
     * Активировать выбранного пользователя; грид — та же страница заново.
     */
    activate() {
        const page = this.pageList.currentPage;
        Energine.request(
            this.singlePath + this.grid.getSelectedRecordKey() + '/activate/',
            null,
            () => this.loadPage(page)
        );
    }
};
```

Full file `core/modules/share/scripts/ActionLogManager.js`:
```js
/**
 * @file Журнал действий: «Очистить». Чистый JavaScript, без MooTools.
 *
 * @requires GridManager
 */

ScriptLoader.load('GridManager');

/**
 * Журнал действий.
 *
 * @augments GridManager
 *
 * @constructor
 * @param {Element|string} element The main holder element.
 */
var ActionLogManager = class ActionLogManager extends GridManager {
    /**
     * Очистить журнал — после подтверждения; грид — та же страница заново.
     */
    clear() {
        const MSG_CONFIRM_DELETE = Energine.translations.get('MSG_CONFIRM_DELETE') ||
            'Do you really want to delete selected record?';
        if (confirm(MSG_CONFIRM_DELETE)) {
            this.overlay.show();
            Energine.request(this.singlePath + '/clear/', null,
                () => {
                    this.overlay.hide();
                    this.loadPage(this.pageList.currentPage);
                },
                () => this.overlay.hide(),
                (responseText) => {
                    alert(responseText);
                    this.overlay.hide();
                }
            );
        }
    }
};
```

- [ ] **Step 4: no-traces.** В `VANILLA_JS` добавить `core/modules/share/scripts/GridManager.js
  core/modules/share/scripts/FileRepository.js core/modules/share/scripts/ActionLogManager.js
  core/modules/user/scripts/UserManager.js`.

- [ ] **Step 5: Карта стенда и прогон.**

Run: `runuser -u web97 -- php8.5 /tmp/stand-web97/site/web/index.php setup scriptMap; bash tests/tools/stand.sh run bash tests/no-traces.sh mootools; cd tests/audit && for t in grids editors; do bash ../tools/stand.sh run bash -c 'envsh=$(php8.5 ../env.php --shell) && eval "$envsh" && node '$t'.js' > $W/t2-$t.log 2>&1; echo "$t $?"; grep -E '^FAIL' $W/t2-$t.log; done`
Expected: карта — `MooCompat` только у `DivManager`, `DivSidebar`, `DivTree`, `getDirsTree`; no-traces — 0; grids — 0
(все красные задачи 1 — OK); editors — 0.

- [ ] **Step 6: Commit**

```bash
git add core/modules/share/scripts/GridManager.js core/modules/share/scripts/FileRepository.js core/modules/user/scripts/UserManager.js core/modules/share/scripts/ActionLogManager.js tests/no-traces.sh
bash tests/tools/stand.sh run git commit -q -m "Этап 8, шаг 6: гриды на чистом JavaScript; файловый грид — подклассом, размер маленького файла — в байтах" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

## Task 3: Документы и итоговая проверка

**Files:**
- Modify: `README.md` (абзац этапа 8 — шаг 6; список спецификаций), `tests/README.md` (что проверяет `grids.js`)

- [ ] **Step 1: README.md.** После предложения о шаге 5 добавить: «Шаг 6
  (`docs/superpowers/specs/2026-10-02-energine-simple-stage8-step6-grids-design.md`): гриды админки — на чистом
  JavaScript; гриды и их окна MooTools не получают.»; в список спецификаций — строку шага 6.
- [ ] **Step 2: tests/README.md.** В описание `grids.js` добавить: «Без MooTools: гриды пользователей, ролей, языков,
  переводов, шаблонов писем, журнала действий, репозиторий, библиотека в окне формы. Выбор строк (щелчок, Shift, Ctrl),
  удаление двух строк, двойной щелчок; сортировка по заголовку; ширины колонок; высота под окно; «Вверх»/«Вниз»
  (запросы перехватываются); «Править предыдущий»; репозиторий: папки, крошки, cookie папки, размер файла (и меньше
  1 КиБ), увеличенное превью; выбор файла из папки в окне формы; «Активировать»; «Очистить» журнал (запрос
  перехватывается).»
- [ ] **Step 3: Весь набор на стенде** — no-traces all, регрессия, аудиты `public`, `grids`, `editors`, `theme`,
  `crawl` (как в задаче 4 шага 5).
Expected: no-traces 0; регрессия 17/17, журнал PHP чист; аудиты — `failures: 0`; crawl — `pages: 72, with errors: 0`.
- [ ] **Step 4: Commit** — `git add README.md tests/README.md`, сообщение «Этап 8, шаг 6: документы».

## Task 4: Выкладка и проверка на simple.energine.org

Без отдельного согласования (владелец: «продолжай без остановки»). База не меняется.

- [ ] **Step 1: Точка отката** — HEAD живого дерева и `web/system.jsmap.php` в `private/backup/stage8-step6-<дата>/`.
- [ ] **Step 2: Код** — от имени web97: `git fetch <клон> main && git merge --ff-only FETCH_HEAD` в живом дереве.
- [ ] **Step 3: Статика** — в `web/` от web97: `setup linker && setup scriptMap`; карта: `GridManager` — `TabPane`,
  `PageList`, `Toolbar`, `Overlay`, `ModalBox`, `Filters`; `FileRepository`, `UserManager`, `ActionLogManager` —
  `GridManager`; `MooCompat` — только у четырёх скриптов структуры.
- [ ] **Step 4: Проверка гостем** — `live-guest.js`.
- [ ] **Step 5: Регрессия и аудиты на площадке**, затем `chown -R web97:client1` для `private` и `web`.
- [ ] **Step 6: При провале** — откат: от web97 `git reset --hard <прежний HEAD>`, `setup linker && setup scriptMap`.
