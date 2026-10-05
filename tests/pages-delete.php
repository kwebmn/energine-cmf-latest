<?php
// Безопасное удаление страницы (DivisionEditor::deleteData):
//  1. страница с подстраницами не удаляется (ERR_DIV_HAS_CHILDREN) — иначе каскад снёс бы поддерево с текстами;
//  2. системные страницы (под admin/ и служебные сегменты корня) не удаляются (ERR_DIV_SYSTEM);
//  3. страница, на которую ссылаются тексты: без подтверждения — ответ с полем confirm и списком страниц, страница
//     на месте (result true, mode confirm — это вопрос, а не ошибка); с ?confirm=1 — удалена.
// Стенды claude-del-* создаются и удаляются здесь; системная проверка — на стенде внутри admin/, живые страницы не трогаются.
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
$admin = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'admin' AND smap_pid = ?", [$root]);
function unstand(): void {
    // дети раньше родителей
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment LIKE 'claude-del-%' ORDER BY smap_pid DESC, smap_id DESC")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        q('DELETE tt FROM share_textblocks_translation tt JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ?', [$id]);
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
function stand(string $segment, int $pid): int {
    global $info;
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, 0, 999)", [$pid, $segment]);
    $id = (int)pdo()->lastInsertId();
    foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l)
        q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l, 'Стенд ' . $segment]);
    q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
    return $id;
}
unstand();
register_shutdown_function('unstand');
$parent = stand('claude-del-parent', $root);
$child = stand('claude-del-child', $parent);
$linked = stand('claude-del-linked', $root);
$referrer = stand('claude-del-referrer', $root);
q("INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, '1')", [$referrer]);
q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, 1, ?)', [pdo()->lastInsertId(), '<p><a href="claude-del-linked/">см.</a></p>']);
$sys = stand('claude-del-sys', $admin);
$exists = fn($id) => (int)scalar('SELECT COUNT(*) FROM share_sitemap WHERE smap_id = ?', [$id]) === 1;
$del = fn($id, $q = '') => json("/admin/structure/single/divEditor/$id/delete/$q", '');

login();
[$c, $j, $raw] = $del($parent);
$msg = fn($j) => json_encode($j['errors'] ?? [], JSON_UNESCAPED_UNICODE);
check('страница с подстраницей: отказ ERR_DIV_HAS_CHILDREN (переведён), обе на месте', empty($j['result']) && translation('ERR_DIV_HAS_CHILDREN')
    && str_contains($msg($j), (string)translation('ERR_DIV_HAS_CHILDREN')) && $exists($parent) && $exists($child),
    "HTTP $c " . substr($raw, 0, 200) . ' | exists ' . var_export([$exists($parent), $exists($child)], true));
[$c, $j, $raw] = $del($sys);
check('страница внутри admin/: отказ ERR_DIV_SYSTEM (переведён), на месте', empty($j['result']) && translation('ERR_DIV_SYSTEM')
    && str_contains($msg($j), (string)translation('ERR_DIV_SYSTEM')) && $exists($sys), "HTTP $c " . substr($raw, 0, 200));
// служебные сегменты корня — в списке класса
$src = file_get_contents(ROOT . '/core/modules/share/components/DivisionEditor.php');
check('список служебных сегментов корня в DivisionEditor::SYSTEM_SEGMENTS', preg_match("~SYSTEM_SEGMENTS = \\[([^\\]]+)\\]~", $src, $m)
    && !array_diff(['admin', 'login', 'register', 'restore-password', 'profile', 'sitemap', 'google-sitemap', 'robots.txt'], array_map(fn($x) => trim($x, " '"), explode(',', $m[1]))));
[$c, $j, $raw] = $del($linked);
check('страница, на которую ссылается текст: без подтверждения — поле confirm со списком, страница на месте',
    is_array($j) && ($j['mode'] ?? '') === 'confirm' && !empty($j['confirm']) && str_contains($j['confirm'], 'claude-del-referrer/') && $exists($linked),
    "HTTP $c " . substr($raw, 0, 200));
[$c, $j, $raw] = $del($linked, '?confirm=1');
check('с ?confirm=1 — удалена', !empty($j['result']) && ($j['mode'] ?? '') === 'delete' && !$exists($linked), "HTTP $c " . substr($raw, 0, 200));
[$c, $j, $raw] = $del($child);
check('обычная страница без ссылок и подстраниц — удаляется сразу', !empty($j['result']) && !$exists($child), "HTTP $c " . substr($raw, 0, 200));
logout();
done('pages-delete');
