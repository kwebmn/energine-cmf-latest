<?php
// Очистка текстового блока на одном языке не трогает другие языки: пустое сохранение удаляет только перевод своего
// языка; строка блока (share_textblocks) исчезает, лишь когда переводов не осталось. Стенд — страница claude-tb с
// блоком на двух языках; удаляется здесь.
require __DIR__ . '/testlib.php';

$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function unstand(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'claude-tb'")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        q('DELETE tt FROM share_textblocks_translation tt JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ?', [$id]);
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
unstand();
register_shutdown_function('unstand');
q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num)
   VALUES ('default.layout.xml', 'textblock.content.xml', ?, 'claude-tb', 0, 999)", [$root]);
$id = (int)pdo()->lastInsertId();
$langs = q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_default DESC')->fetchAll();
foreach ($langs as $l) q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l['lang_id'], 'Стенд']);
q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
q("INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, '1')", [$id]);
$tb = (int)pdo()->lastInsertId();
foreach ($langs as $l) q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [$tb, $l['lang_id'], '<p>текст ' . $l['lang_abbr'] . '</p>']);
[$def, $other] = [$langs[0], $langs[1] ?? null];
if (!$other) { check('на площадке два языка', false); done('textblock-langs'); }
$rows = fn() => q('SELECT lang_id FROM share_textblocks_translation WHERE tb_id = ? ORDER BY lang_id', [$tb])->fetchAll(PDO::FETCH_COLUMN);
$blockRows = fn() => (int)scalar("SELECT COUNT(*) FROM share_textblocks WHERE smap_id = ? AND tb_num = '1'", [$id]);

login();
// пустое сохранение на языке по умолчанию (адрес без префикса)
[$c, $b] = http('/claude-tb/single/textBlock_1/save-text', ['data' => '', 'ID' => $id, 'num' => 1]);
check('пустое сохранение на основном языке: ответ успешный', $c == 200 && str_contains($b, '"result":true'), "HTTP $c " . substr($b, 0, 120));
check('перевод основного языка удалён, перевод второго языка на месте, строка блока есть',
    $rows() == [$other['lang_id']] && $blockRows() === 1, json_encode(['rows' => $rows(), 'block' => $blockRows()]));
// пустое сохранение на втором языке (адрес с префиксом) — последний перевод, строка блока уходит
[$c, $b] = http('/' . $other['lang_abbr'] . '/claude-tb/single/textBlock_1/save-text', ['data' => '', 'ID' => $id, 'num' => 1]);
check('последний перевод стёрт — строки блока нет', $c == 200 && $rows() == [] && $blockRows() === 0, json_encode(['rows' => $rows(), 'block' => $blockRows()]));
// текст снова сохраняется после полного удаления
[$c, $b] = http('/claude-tb/single/textBlock_1/save-text', ['data' => '<p>снова</p>', 'ID' => $id, 'num' => 1]);
check('после удаления блок создаётся заново', $c == 200 && $blockRows() === 1
    && scalar("SELECT tb_content FROM share_textblocks t JOIN share_textblocks_translation tt USING (tb_id) WHERE t.smap_id = ? AND tt.lang_id = ?", [$id, $def['lang_id']]) === '<p>снова</p>');
logout();
done('textblock-langs');
