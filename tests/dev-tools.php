<?php
// Удобство разработчика (этап 2):
//  1. в XML страницы компонент можно указать коротким именем (class="TextBlock"); неизвестное имя — ошибка
//     разработчика с этим именем;
//  2. текстовый блок секции задаётся именем секции (param section=hero): номер блока и образец — из TextBlock.
// Временные страницы со своим XML создаются и удаляются здесь.
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function stand(string $segment, string $xml): int {
    global $root, $info;
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_content_xml, smap_pid, smap_segment, smap_in_menu, smap_order_num)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, ?, 0, 999)", [$xml, $root, $segment]);
    $id = (int)pdo()->lastInsertId();
    foreach (q('SELECT lang_id FROM share_languages')->fetchAll(PDO::FETCH_COLUMN) as $l)
        q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l, 'Стенд']);
    q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
    return $id;
}
function unstand(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment LIKE 'claude-dev-%'")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
unstand();
register_shutdown_function('unstand');

stand('claude-dev-short', '<content><container name="s" section="hero"><component name="tbShort" class="TextBlock">'
    . '<params><param name="section">hero</param></params></component></container>'
    . '<component name="tbFull" class="Energine\share\components\TextBlock"><params><param name="num">1</param></params></component></content>');
stand('claude-dev-bad', '<content><component name="x" class="NoSuchThing"/></content>');

login();
[$code, $xml] = http('/claude-dev-short/?debug');
$d = new DOMDocument();
$ok = $code == 200 && @$d->loadXML($xml);
$xp = $ok ? new DOMXPath($d) : null;
$short = $xp ? $xp->query('//component[@name="tbShort"]')->item(0) : null;
$full = $xp ? $xp->query('//component[@name="tbFull"]')->item(0) : null;
check('короткое имя class="TextBlock" — компонент TextBlock', $short && $short->getAttribute('sample') === 'TextBlock', "HTTP $code");
check('полное имя по-прежнему работает', $full && $full->getAttribute('sample') === 'TextBlock' && $full->getAttribute('num') === '1');
check('секция по имени: section=hero → номер 11', $short && $short->getAttribute('num') === '11'
    && $short->getAttribute('section') === 'hero',
    $short ? 'num=' . $short->getAttribute('num') . ' section=' . $short->getAttribute('section') : 'нет');
[$code, $body] = http('/claude-dev-bad/');
check('неизвестное короткое имя — ошибка разработчика с этим именем (в отладке)', str_contains($body, 'NoSuchThing')
    && str_contains($body, 'ERR_DEV_NO_COMPONENT_CLASS'), "HTTP $code " . substr(strip_tags($body), 0, 200));
logout();
done('dev-tools');
