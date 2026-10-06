<?php
// Память старых адресов (надёжность, этап 5): переименованная или перенесённая страница (и её подразделы) отвечает со
// старого адреса переадресацией 301 на нынешний — с хвостом пути, строкой запроса и языком; прежде старый адрес давал
// 404 и ломал ссылки и закладки. Настоящая страница по старому адресу важнее псевдонима; страница, которую посетитель не
// может открыть (нет права, выключена на его языке), переадресацией не выдаётся; удаление страницы уносит её старые
// адреса. Стенд — разделы claude-pa*, создаются и правятся формой раздела администратора, удаляются в конце.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\Db;

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$INFO = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_pid = ? AND smap_segment = 'info'", [$ROOT]);
$GUEST = (int)scalar('SELECT group_id FROM user_groups WHERE group_default = 1');
$S = '/admin/structure/single/divEditor/';
$base = rtrim(BASE, '/');
$hasTable = (bool)scalar("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'share_sitemap_aliases'");
check('таблица share_sitemap_aliases есть', $hasTable);

// запрос без переадресации: код, Location и Cache-Control; гостем — без cookie, администратором — с банкой testlib
function req(string $path, string $method = 'GET', array $headers = [], bool $asAdmin = false): array {
    $ch = curl_init(BASE . $path);
    $opts = [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_TIMEOUT => 60];
    if ($method === 'POST') $opts[CURLOPT_POSTFIELDS] = 'a=1';
    if ($asAdmin) $opts += [CURLOPT_COOKIEFILE => $GLOBALS['jar'], CURLOPT_COOKIEJAR => $GLOBALS['jar']];
    curl_setopt_array($ch, $opts);
    $raw = (string)curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), preg_match('~^Location:\s*(\S+)~mi', $raw, $m) ? $m[1] : '',
        preg_match('~^Cache-Control:\s*([^\r\n]+)~mi', $raw, $m) ? $m[1] : ''];
}
function moved(string $label, string $from, string $to): void {
    [$code, $loc] = req($from);
    $ok = $code === 301 && $loc === rtrim(BASE, '/') . $to;
    // одна переадресация: адрес, куда ведёт, сам отвечает страницей
    if ($ok && !str_contains($to, 'page-2')) {
        [$next] = req($to);
        $ok = $next === 200;
        $code .= " → $next";
    }
    check($label, $ok, "$code $loc");
}
// форма раздела (как в smoke-write.sh): добавить или изменить; ответ — id раздела
function savePage(?int $id, int $pid, string $segment): ?int {
    $f = ['componentAction' => $id ? 'edit' : 'add', 'share_sitemap[smap_id]' => (string)$id, 'share_sitemap[smap_pid]' => $pid,
        'share_sitemap[smap_layout]' => 'default.layout.xml', 'share_sitemap[smap_content]' => 'textblock.content.xml',
        'share_sitemap[smap_segment]' => $segment, 'share_sitemap[smap_redirect_url]' => '', 'share_sitemap[smap_in_menu]' => '0',
        'right_id[1]' => 3, 'right_id[3]' => 1, 'right_id[4]' => 1];
    foreach ([1, 2] as $l) {
        foreach (['smap_title', 'smap_html_title', 'smap_meta_keywords', 'smap_meta_description', 'smap_description_rtf'] as $k) {
            $f["share_sitemap_translation[$l][$k]"] = '';
        }
        $f["share_sitemap_translation[$l][smap_name]"] = 'Адрес ' . $segment;
    }
    [$c, $b] = http($GLOBALS['S'] . 'save', $f, ['X-Request: JSON']);
    $j = json_decode($b, true);
    if ($c != 200 || empty($j['result'])) {
        echo "  (сохранение $segment: HTTP $c " . substr($b, 0, 200) . ")\n";
        return null;
    }
    return (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid = ? AND smap_segment = ?', [$pid, $segment]);
}
function deletePage(int $id): bool {
    [$c, $b] = http($GLOBALS['S'] . $id . '/delete/', '', ['X-Request: JSON']);
    return $c == 200 && !empty(json_decode($b, true)['result']) && !(int)scalar('SELECT COUNT(*) FROM share_sitemap WHERE smap_id = ?', [$id]);
}
$aliasesOf = fn(array $ids) => $GLOBALS['hasTable'] && $ids ? (int)scalar('SELECT COUNT(*) FROM share_sitemap_aliases WHERE smap_id IN (' . implode(',', array_map('intval', $ids)) . ')') : 0;

// добавление страниц сдвигает smap_order_num всему сайту (так устроено ядро) — порядок возвращается в конце
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();
$guestRow = null;
$disabled = null;
login();
try {
    $A = savePage(null, $ROOT, 'claude-pa');
    $B = $A ? savePage(null, $A, 'claude-pa-child') : null;
    if (!check('стенд: раздел claude-pa с подразделом', $A && $B)) {
        throw new RuntimeException('стенд не создан');
    }
    // 1. переименование
    $renamed = savePage($A, $ROOT, 'claude-pa2') === $A;
    check('переименование раздела сохранено', $renamed);
    moved('старый адрес → 301 на новый', '/claude-pa/', '/claude-pa2/');
    // переадресацию со старого адреса браузер не запоминает навсегда: владелец может вернуть прежнее имя — иначе у
    // гостя, уже открывавшего старый адрес, была бы петля (браузер уводит со старого, сервер — на старый)
    [$code, , $cc] = req('/claude-pa/');
    check('301 со старого адреса — с Cache-Control: no-cache (браузер спрашивает сервер каждый раз)', $code === 301
        && str_contains(strtolower($cc), 'no-cache'), "$code Cache-Control: $cc");
    moved('старый адрес подраздела → 301 сразу на его новый адрес', '/claude-pa/claude-pa-child/', '/claude-pa2/claude-pa-child/');
    moved('строка запроса сохраняется', '/claude-pa/?x=1', '/claude-pa2/?x=1');
    moved('хвост пути (параметр компонента) переносится', '/claude-pa/page-2/', '/claude-pa2/page-2/');
    if ((int)scalar("SELECT lang_is_active FROM share_languages WHERE lang_abbr = 'ua'") === 1) {
        moved('второй язык: /ua/claude-pa/ → /ua/claude-pa2/', '/ua/claude-pa/', '/ua/claude-pa2/');
    } else {
        echo "SKIP второй язык закрыт\n";
    }
    [$code] = req('/claude-pa/', 'POST');
    check('POST на старый адрес — не 301', $code !== 301, (string)$code);
    [$code] = req('/claude-pa/', 'GET', ['X-Request: JSON']);
    check('запрос JSON на старый адрес — не 301', $code !== 301, (string)$code);
    // 2. перенос к другому родителю: оба прежних адреса — сразу на нынешний, без цепочки
    check('перенос раздела под info сохранён', savePage($A, $INFO, 'claude-pa2') === $A);
    moved('перенос: прошлый адрес → 301 на новый', '/claude-pa2/', '/info/claude-pa2/');
    moved('перенос: первый адрес → 301 сразу на новый (без цепочки)', '/claude-pa/', '/info/claude-pa2/');
    moved('перенос: старый адрес подраздела → на его новый адрес', '/claude-pa/claude-pa-child/', '/info/claude-pa2/claude-pa-child/');
    // 3. старый адрес снова занят страницей — отвечает она, псевдонима нет
    $C = savePage(null, $ROOT, 'claude-pa');
    [$code] = req('/claude-pa/');
    check('старый адрес, снова ставший страницей, — страница (200)', $C && $code === 200, (string)$code);
    check('псевдоним, совпавший с адресом страницы, удалён', $hasTable && !(int)scalar("SELECT COUNT(*) FROM share_sitemap_aliases WHERE alias_path = 'claude-pa'"));
    moved('подраздел старого адреса по-прежнему переадресуется', '/claude-pa/claude-pa-child/', '/info/claude-pa2/claude-pa-child/');
    // 4. страница, которую гость открыть не может, переадресацией не выдаётся
    $guestRow = q('SELECT * FROM share_access_level WHERE smap_id = ? AND group_id = ?', [$A, $GUEST])->fetch() ?: null;
    q('DELETE FROM share_access_level WHERE smap_id = ? AND group_id = ?', [$A, $GUEST]);
    [$code] = req('/claude-pa2/');
    check('нет права гостя: старый адрес — 404, а не 301', $code === 404, (string)$code);
    [$code, $loc] = req('/claude-pa2/', 'GET', [], true);
    check('администратору тот же старый адрес — 301', $code === 301 && $loc === $base . '/info/claude-pa2/', "$code $loc");
    if ($guestRow) {
        q('INSERT INTO share_access_level (smap_id, group_id, right_id) VALUES (?, ?, ?)', [$guestRow['smap_id'], $guestRow['group_id'], $guestRow['right_id']]);
        $guestRow = null;
    }
    $disabled = (int)scalar('SELECT smap_is_disabled FROM share_sitemap_translation WHERE smap_id = ? AND lang_id = 1', [$A]);
    q('UPDATE share_sitemap_translation SET smap_is_disabled = 1 WHERE smap_id = ? AND lang_id = 1', [$A]);
    [$code] = req('/claude-pa2/');
    check('страница выключена на языке: старый адрес — 404', $code === 404, (string)$code);
    q('UPDATE share_sitemap_translation SET smap_is_disabled = ? WHERE smap_id = ? AND lang_id = 1', [$disabled, $A]);
    $disabled = null;
    // 5. PageAliases::find — самый длинный записанный префикс пути
    if (class_exists('Energine\share\gears\PageAliases')) {
        $db = new Db(pdo());
        $pa = new Energine\share\gears\PageAliases($db);
        pdo()->beginTransaction();
        try {
            q('INSERT INTO share_sitemap_aliases (alias_path, smap_id) VALUES (?, ?), (?, ?)', ['claude-x', $ROOT, 'claude-x/y', $INFO]);
            $long = $pa->find(['claude-x', 'y', 'z']);
            $short = $pa->find(['claude-x', 'q']);
            check('find: самый длинный префикс, остаток — сегментами', $long === ['id' => $INFO, 'rest' => ['z']] && $short === ['id' => $ROOT, 'rest' => ['q']],
                json_encode([$long, $short]));
            check('find: пустой путь и неизвестный путь — null', $pa->find([]) === null && $pa->find(['claude-nope']) === null);
        } finally {
            pdo()->rollBack();
        }
    } else {
        check('гир PageAliases есть', false);
    }
    // 6. удаление уносит старые адреса
    check('удаление стенда (подраздел, раздел, новый раздел)', deletePage($B) && deletePage($A) && deletePage($C));
    check('у удалённых страниц старых адресов нет', $hasTable && $aliasesOf([$A, $B]) === 0, (string)$aliasesOf([$A, $B]));
    [$code] = req('/claude-pa2/');
    check('старый адрес удалённой страницы — 404', $code === 404, (string)$code);
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    if ($guestRow) {
        q('INSERT IGNORE INTO share_access_level (smap_id, group_id, right_id) VALUES (?, ?, ?)', [$guestRow['smap_id'], $guestRow['group_id'], $guestRow['right_id']]);
    }
    // остатки стенда (сбой посередине): подразделы и старые адреса уходят каскадом
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-pa-child')");
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-pa', 'claude-pa2')");
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    logout();
}
done('page-aliases');
