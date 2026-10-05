<?php
// Битые ссылки в текстах (этап «удобство владельца»): setup checklinks находит ссылки на несуществующие страницы и
// файлы и на отключённые страницы (и помечает страницы только для вошедших), и не трогает рабочие, внешние, якоря, mailto:, tel:.
// Стенд: страница claude-links с текстовым блоком и отключённая claude-links-off; удаляются здесь.
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function unstand(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment LIKE 'claude-links%'")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        q('DELETE tt FROM share_textblocks_translation tt JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ?', [$id]);
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
function stand(string $segment, bool $disabled = false): int {
    global $root, $info;
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, 0, 999)", [$root, $segment]);
    $id = (int)pdo()->lastInsertId();
    foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l)
        q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, ?)', [$id, $l, 'Стенд', (int)$disabled]);
    q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
    return $id;
}
unstand();
register_shutdown_function('unstand');
$domain = parse_url(BASE, PHP_URL_HOST);
$good = ['service/', '/ua/contacts/', 'contacts', "https://$domain/sitemap/", 'uploads/public/13662314846.png', 'service/?x=1', 'service/#top',
    '#contacts', 'mailto:info@example.org', 'tel:+70000000000', 'https://example.org/nope/', 'info/quick-start/'];
$bad = ['nope/', '/ua/nope/', 'uploads/public/nope.png', 'claude-links-off/', 'info/nope-deeper/', "https://www.$domain/nope-www/"];
// страница, отключённая только на украинском: со ссылкой из русского текста — рабочая
$good[] = 'claude-links-half/';
$html = '<p>' . implode(' ', array_map(fn($u) => '<a href="' . htmlspecialchars($u) . '">x</a>', array_merge($good, $bad))) . '<img src="uploads/public/nope2.png"></p>';
$bad[] = 'uploads/public/nope2.png';
$id = stand('claude-links');
stand('claude-links-off', true);
$half = stand('claude-links-half');
q("UPDATE share_sitemap_translation SET smap_is_disabled = 1 WHERE smap_id = ? AND lang_id <> (SELECT lang_id FROM share_languages WHERE lang_default = 1)", [$half]);
q("INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, '1')", [$id]);
$tbId = (int)pdo()->lastInsertId();
$def = (int)scalar('SELECT lang_id FROM share_languages WHERE lang_default = 1');
q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [$tbId, $def, $html]);
q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) SELECT ?, lang_id, ? FROM share_languages WHERE lang_default = 0',
    [$tbId, '<p><a href="ua/claude-links-half/">x</a></p>']);

$owner = posix_getpwuid(fileowner(WEB))['name'];
exec('cd ' . escapeshellarg(WEB) . ' && runuser -u ' . escapeshellarg($owner) . ' -- php8.5 index.php setup checklinks 2>&1', $out, $rc);
$lines = array_filter($out, fn($l) => str_contains($l, 'claude-links/'));
$found = fn($u) => (bool)array_filter($lines, fn($l) => str_contains($l, " $u "));
$missed = array_filter($bad, fn($u) => !$found($u));
$false = array_filter($good, fn($u) => $found($u));
check('setup checklinks: все битые ссылки стенда найдены', !$missed, 'не найдены: ' . implode(' ', $missed) . ' | ' . implode(' / ', array_slice($out, -8)));
check('setup checklinks: рабочие, внешние, якоря, mailto, tel — не битые', !$false, 'ложные: ' . implode(' ', $false));
check('setup checklinks: при битых ссылках выход 1', $rc === 1, "выход $rc");
// та же страница из украинского текста — битая (на украинском отключена)
$uaTb = (int)scalar("SELECT tb_id FROM share_textblocks WHERE smap_id = ?", [$id]);
check('страница отключена только на украинском: из украинского текста ссылка ua/… — битая', (bool)array_filter($out, fn($l) => str_contains($l, '[ua]')
    && str_contains($l, ' ua/claude-links-half/ ')), implode(' / ', array_slice($out, -6)));
check('ссылка на отключённую страницу — причина «страница отключена»', (bool)array_filter($lines, fn($l) => str_contains($l, 'claude-links-off/') && preg_match('~отключена~u', $l)));
// страница админки «Битые ссылки»: администратор видит битую ссылку стенда со страницей и причиной; гостю — отказ
logout();
[$gc, $gb] = http('/admin/links/');
check('гостю /admin/links/ — отказ (как у прочих страниц админки — 404)', $gc == 404 || $gc == 403 || ($gc == 200 && !str_contains($gb, 'uploads/public/nope.png')), "HTTP $gc");
login();
[$ac, $ab] = http('/admin/links/');
check('администратор: /admin/links/ — таблица битых ссылок со ссылкой стенда и причиной', $ac == 200 && str_contains($ab, 'uploads/public/nope.png')
    && str_contains($ab, 'claude-links/') && preg_match('~<table~', $ab) && str_contains($ab, 'Нет файла'), "HTTP $ac " . substr(strip_tags($ab), 0, 200));
check('администратор: ссылки только для вошедших — отдельным списком', str_contains($ab, 'только для вошедших'));
logout();
done('links');
