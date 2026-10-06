<?php
// Используемый файл не удаляется молча (идея xsight): удаление из репозитория файла, на который ссылается текст страницы
// (любой вид адреса, в том числе через ресайзер; у папки — файлы внутри), — вопрос со списком страниц
// ({result: true, mode: 'confirm', confirm}), ничего не удалено; повтор с ?confirm=1 удаляет; неиспользуемый файл
// удаляется сразу, как прежде. Файл, на который ведёт страница-ссылка (адрес переадресации), — тоже используемый.
// Стенд: папка uploads/public/claude-fg (записи репозитория и файлы), страница claude-fg с текстом, страница-ссылка
// claude-fg-link на linked.pdf; всё удаляется в конце.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\LinkChecker;

$ROOT = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$REPO = (int)scalar("SELECT upl_id FROM share_uploads WHERE upl_path = 'uploads/public'");
$REL = 'uploads/public/claude-fg';
$DIR = WEB . '/' . $REL;
$HOST = parse_url(BASE, PHP_URL_HOST);
$LIB = '/admin/users/single/adminPanel/file-library/';
$order = q('SELECT smap_id, smap_order_num FROM share_sitemap')->fetchAll();

function addUpload(int $pid, string $path, string $type): int {
    q('INSERT INTO share_uploads (upl_pid, upl_path, upl_filename, upl_name, upl_title, upl_internal_type, upl_childs_count) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [$pid, $path, basename($path), basename($path), basename($path), $type, $type === 'folder' ? 0 : null]);
    return (int)scalar('SELECT upl_id FROM share_uploads WHERE upl_path = ?', [$path]);
}
function del(string $ids, bool $confirm = false): array {
    [$c, $j, $body] = json($GLOBALS['LIB'] . $ids . '/delete/' . ($confirm ? '?confirm=1' : ''));
    return [$c, is_array($j) ? $j : [], $body];
}
$exists = fn(string $name) => is_file("$DIR/$name") && (int)scalar('SELECT COUNT(*) FROM share_uploads WHERE upl_path = ?', ["$REL/$name"]) === 1;

@mkdir($DIR, 0755, true);
chown($DIR, SITE_USER);
foreach (['used.pdf', 'pic.jpg', 'free.pdf', 'free2.pdf', 'with space.pdf', 'linked.pdf'] as $f) {
    file_put_contents("$DIR/$f", "claude\n");
    chmod("$DIR/$f", 0644);
    chown("$DIR/$f", SITE_USER); // удаляет сайт: файлы и каталог — владельца площадки
}
login();
try {
    $folder = addUpload($REPO, $REL, 'folder');
    $ids = [];
    foreach (['used.pdf' => 'file', 'pic.jpg' => 'image', 'free.pdf' => 'file', 'free2.pdf' => 'file', 'with space.pdf' => 'file',
                 'linked.pdf' => 'file'] as $f => $t) {
        $ids[$f] = addUpload($folder, "$REL/$f", $t);
    }
    $page = savePage(null, $ROOT, 'claude-fg');
    $pageLink = savePage(null, $ROOT, 'claude-fg-link', ['redirect' => "/$REL/linked.pdf"]);
    if (!check('стенд: папка с файлами, страница с текстом, страница-ссылка на файл', $page && $pageLink && count(array_filter($ids)) === 6)) {
        throw new RuntimeException('стенд не создан');
    }
    q('INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, ?)', [$page, '1']);
    $tb = (int)scalar('SELECT tb_id FROM share_textblocks WHERE smap_id = ? AND tb_num = ?', [$page, '1']);
    q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, 1, ?)', [$tb,
        '<p><a href="' . BASE . "/$REL/used.pdf\">договор</a> <img src=\"/resizer/w40-h40/$REL/pic.jpg\" alt=\"\"> "
        . '<a href="' . str_replace(' ', '%20', "$REL/with space.pdf") . '">с пробелом</a></p>']);

    // 1. LinkChecker::fileReferrers (консоль): все виды адреса, папка — по файлам внутри
    $lc = new LinkChecker(pdo(), WEB, $HOST, '/');
    if (method_exists($lc, 'fileReferrers')) {
        $refs = $lc->fileReferrers(["$REL/used.pdf", "$REL/pic.jpg", "$REL/with space.pdf", "$REL/free.pdf", $REL]);
        check('fileReferrers: абсолютный адрес своего сайта', in_array('claude-fg/', $refs["$REL/used.pdf"] ?? [], true), json_encode($refs, JSON_UNESCAPED_UNICODE));
        check('fileReferrers: адрес через ресайзер', in_array('claude-fg/', $refs["$REL/pic.jpg"] ?? [], true));
        check('fileReferrers: относительный адрес с %20', in_array('claude-fg/', $refs["$REL/with space.pdf"] ?? [], true));
        check('fileReferrers: неиспользуемый файл — нет страниц', empty($refs["$REL/free.pdf"]));
        check('fileReferrers: папка — по файлам внутри', in_array('claude-fg/', $refs[$REL] ?? [], true));
        check('fileReferrers: страница-ссылка на файл (адрес переадресации)', in_array('claude-fg-link/', $lc->fileReferrers(["$REL/linked.pdf"])["$REL/linked.pdf"] ?? [], true),
            json_encode($lc->fileReferrers(["$REL/linked.pdf"]), JSON_UNESCAPED_UNICODE));
        pdo()->beginTransaction();
        try {
            q('UPDATE share_textblocks_translation SET tb_content = ? WHERE tb_id = ? AND lang_id = 1', ['<p><a href="/' . "$REL/free.pdf" . '?v=2#p">от корня</a></p>', $tb]);
            check('fileReferrers: адрес от корня со строкой запроса и якорем', in_array('claude-fg/', $lc->fileReferrers(["$REL/free.pdf"])["$REL/free.pdf"] ?? [], true));
        } finally {
            pdo()->rollBack();
        }
    } else {
        check('LinkChecker::fileReferrers есть', false);
    }

    // 2. удаление через репозиторий (администратор)
    [$c, $j] = del((string)$ids['used.pdf']);
    check('используемый файл: вопрос (mode confirm) со страницей, файл и запись на месте', !empty($j['result']) && ($j['mode'] ?? '') === 'confirm'
        && str_contains((string)($j['confirm'] ?? ''), 'claude-fg') && $exists('used.pdf'), json_encode($j, JSON_UNESCAPED_UNICODE));
    [$c, $j] = del((string)$ids['used.pdf'], true);
    check('используемый файл с ?confirm=1 — удалён (файл и запись)', !empty($j['result']) && ($j['mode'] ?? '') !== 'confirm' && !$exists('used.pdf'),
        json_encode($j, JSON_UNESCAPED_UNICODE));
    [$c, $j] = del((string)$ids['free.pdf']);
    check('неиспользуемый файл — удалён сразу, без вопроса', !empty($j['result']) && ($j['mode'] ?? '') !== 'confirm' && !$exists('free.pdf'),
        json_encode($j, JSON_UNESCAPED_UNICODE));
    [$c, $j] = del($ids['pic.jpg'] . ',' . $ids['free2.pdf']);
    check('выделение с используемым файлом — вопрос, ничего не удалено', ($j['mode'] ?? '') === 'confirm' && $exists('pic.jpg') && $exists('free2.pdf'),
        json_encode($j, JSON_UNESCAPED_UNICODE));
    [$c, $j] = del((string)$ids['linked.pdf']);
    check('файл, на который ведёт страница-ссылка: вопрос с её адресом, файл на месте', ($j['mode'] ?? '') === 'confirm'
        && str_contains((string)($j['confirm'] ?? ''), 'claude-fg-link') && $exists('linked.pdf'), json_encode($j, JSON_UNESCAPED_UNICODE));
    [$c, $j] = del((string)$folder);
    check('папка с используемым файлом внутри — вопрос, папка на месте', ($j['mode'] ?? '') === 'confirm' && is_dir($DIR)
        && (int)scalar('SELECT COUNT(*) FROM share_uploads WHERE upl_id = ?', [$folder]) === 1, json_encode($j, JSON_UNESCAPED_UNICODE));
} catch (RuntimeException $e) {
    echo "  ({$e->getMessage()})\n";
} finally {
    q("DELETE FROM share_uploads WHERE upl_path LIKE 'uploads/public/claude-fg%'");
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-fg', 'claude-fg-link')");
    $st = pdo()->prepare('UPDATE share_sitemap SET smap_order_num = ? WHERE smap_id = ?');
    foreach ($order as $o) {
        $st->execute([$o['smap_order_num'], $o['smap_id']]);
    }
    foreach (glob("$DIR/*") ?: [] as $f) {
        @unlink($f);
    }
    @rmdir($DIR);
    logout();
}
done('file-guard');
