<?php
// История текста и откат (надёжность, этап 3): каждое сохранение блока кладёт прежний текст языка в
// share_textblocks_history (не больше 20 версий на блок и язык, одинаковый текст историю не пополняет); откат
// (restore/<версия>/) делает версию текущей, а текущий текст — версией; другие языки не трогаются; очищенный блок
// восстанавливается из истории; удаление блока уносит историю (каскад). Сохранение — событие: строка журнала
// CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK и дата страницы smap_last_mod. Стенд — страница claude-th с блоком на
// двух языках; удаляется здесь (и строки журнала о ней).
require __DIR__ . '/testlib.php';

if (!scalar("SHOW TABLES LIKE 'share_textblocks_history'")) {
    check('таблица share_textblocks_history есть (sql/cut/stage16.sql)', false);
    done('text-history');
}
$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
function unstand(): void {
    foreach (q("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'claude-th'")->fetchAll(PDO::FETCH_COLUMN) as $id) {
        q('DELETE FROM share_action_log WHERE al_classname LIKE ? AND al_data LIKE ?', ['CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK%', '%"smap_id";i:' . $id . ';%']);
        q('DELETE tt FROM share_textblocks_translation tt JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ?', [$id]);
        foreach (['share_textblocks', 'share_access_level', 'share_sitemap_translation', 'share_sitemap'] as $t) q("DELETE FROM $t WHERE smap_id = ?", [$id]);
    }
}
unstand();
register_shutdown_function('unstand');
q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num, smap_last_mod)
   VALUES ('default.layout.xml', 'textblock.content.xml', ?, 'claude-th', 0, 999, '2000-01-01 00:00:00')", [$root]);
$id = (int)pdo()->lastInsertId();
$langs = q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_default DESC')->fetchAll();
foreach ($langs as $l) q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, 0)', [$id, $l['lang_id'], 'Стенд истории']);
q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
q("INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, '1')", [$id]);
$tb = (int)pdo()->lastInsertId();
foreach ($langs as $l) q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [$tb, $l['lang_id'], '<p>исходный ' . $l['lang_abbr'] . '</p>']);
[$def, $other] = [$langs[0], $langs[1] ?? null];
if (!$other) { check('на площадке два языка', false); done('text-history'); }
$L = (int)$def['lang_id'];
$content = fn($lang) => scalar('SELECT tb_content FROM share_textblocks_translation WHERE tb_id = ? AND lang_id = ?', [$tb, $lang]);
$history = fn() => q('SELECT tbh_id, tbh_content FROM share_textblocks_history WHERE tb_id = ? AND lang_id = ? ORDER BY tbh_id', [$tb, $L])->fetchAll();
$save = fn($text, $prefix = '') => http($prefix . '/claude-th/single/textBlock_1/save-text', ['data' => $text, 'ID' => $id, 'num' => 1]);
$logRows = fn() => (int)scalar('SELECT COUNT(*) FROM share_action_log WHERE al_classname = ? AND al_action = ? AND al_data LIKE ?',
    ['CLASS_ENERGINE_SHARE_COMPONENTS_TEXTBLOCK', 'UPDATE', '%"smap_id";i:' . $id . ';%']);

login();
// 1. три сохранения: в истории две прежние версии, текущий — третий текст; одинаковый текст историю не пополняет
foreach (['<p>первый</p>', '<p>второй</p>', '<p>третий</p>'] as $t) { [$c, $b] = $save($t); }
check('после трёх сохранений: текущий — третий, в истории исходный, первый и второй',
    $content($L) === '<p>третий</p>' && array_column($history(), 'tbh_content') === ['<p>исходный ' . $def['lang_abbr'] . '</p>', '<p>первый</p>', '<p>второй</p>'],
    json_encode(['now' => $content($L), 'history' => array_column($history(), 'tbh_content')], JSON_UNESCAPED_UNICODE));
$logSame = $logRows();
$save('<p>третий</p>');
check('тот же текст заново — ни новой версии, ни события журнала', count($history()) === 3 && $logRows() === $logSame, count($history()) . ' ' . $logRows() . '/' . $logSame);
check('другой язык не тронут', $content((int)$other['lang_id']) === '<p>исходный ' . $other['lang_abbr'] . '</p>');

// 2. сохранение — событие: журнал и дата страницы
check('в журнале действий — строки TextBlock о странице стенда', $logRows() >= 3, $logRows());
check('дата страницы smap_last_mod обновлена сохранением текста',
    strtotime((string)scalar('SELECT smap_last_mod FROM share_sitemap WHERE smap_id = ?', [$id])) > time() - 120,
    (string)scalar('SELECT smap_last_mod FROM share_sitemap WHERE smap_id = ?', [$id]));

// 3. окно истории и откат
[$c, $b] = http('/claude-th/single/textBlock_1/history/');
check('окно истории открывается (200, заголовок)', $c == 200 && str_contains($b, (string)translation('TXT_TEXT_HISTORY')), "HTTP $c " . substr(strip_tags($b), 0, 120));
[$c, $j, $raw] = json('/claude-th/single/textBlock_1/history/get-data/', '');
check('данные грида истории — три версии с датой и началом текста', $c == 200 && is_array($j) && count($j['data'] ?? []) === 3
    && isset($j['data'][0]['tbh_date']) && str_contains(json_encode($j['data'], JSON_UNESCAPED_UNICODE), 'второй'), "HTTP $c " . substr($raw, 0, 200));
$first = $history()[1]['tbh_id']; // версия «первый»
$logBefore = $logRows();
[$c, $j, $raw] = json("/claude-th/single/textBlock_1/history/restore/$first/", '');
check('откат: ответ JSON с текстом версии', $c == 200 && !empty($j['result']) && ($j['data'] ?? '') === '<p>первый</p>', "HTTP $c " . substr($raw, 0, 160));
check('откат: текущий текст — первый, прежний текущий (третий) ушёл в историю, другой язык не тронут',
    $content($L) === '<p>первый</p>' && ($h0 = array_column($history(), 'tbh_content')) && end($h0) === '<p>третий</p>'
    && count($history()) === 4 && $content((int)$other['lang_id']) === '<p>исходный ' . $other['lang_abbr'] . '</p>',
    json_encode(['now' => $content($L), 'history' => array_column($history(), 'tbh_content')], JSON_UNESCAPED_UNICODE));
[$c, $b] = http("/claude-th/single/textBlock_1/history/show/$first/");
check('просмотр версии: страница с её текстом', $c == 200 && str_contains($b, 'первый'), "HTTP $c " . substr(strip_tags($b), 0, 120));
check('откат — тоже событие журнала', $logRows() === $logBefore + 1, $logRows() . ' vs ' . $logBefore);

// 4. очищенный блок восстанавливается из истории; предел — 20 версий
$save('');
check('очистка: перевода нет, история на месте', $content($L) === false && count($history()) === 5, json_encode([$content($L), count($history())]));
[$c, $j] = json("/claude-th/single/textBlock_1/history/restore/$first/", '');
check('откат после очистки возвращает текст', !empty($j['result']) && $content($L) === '<p>первый</p>', json_encode($j, JSON_UNESCAPED_UNICODE));
for ($i = 1; $i <= 22; $i++) { $save("<p>версия $i</p>"); }
$h = array_column($history(), 'tbh_content');
check('не больше 20 версий, старые вытеснены (последняя в истории — «версия 21»)', count($h) === 20 && end($h) === '<p>версия 21</p>' && !in_array('<p>первый</p>', $h, true),
    count($h) . ' ' . json_encode(array_slice($h, 0, 2), JSON_UNESCAPED_UNICODE));

// 5. удаление блока (все языки очищены) уносит историю
$save('');
$save('', '/' . $other['lang_abbr']);
check('блока нет — истории нет (каскад)', (int)scalar('SELECT COUNT(*) FROM share_textblocks WHERE tb_id = ?', [$tb]) === 0
    && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tb_id = ?', [$tb]) === 0);
logout();
done('text-history');
