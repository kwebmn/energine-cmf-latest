<?php
// Поиск по сайту: основы слов (Stemmer), индекс страниц (SearchIndex, setup reindex), обновление индекса, страница
// результатов, журнал поиска.
// Стенд: страницы claude-sr (текст на двух языках) с подразделом claude-sr-child, claude-sr-link (страница-ссылка),
// claude-sr-ruonly (выключена на втором языке) — в базе напрямую, без сдвига порядка; удаляются в конце (строки
// индекса — каскадом).
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\SearchIndex;
use Energine\share\gears\Stemmer;

$owner = posix_getpwuid(fileowner(WEB))['name'];
// setup от владельца площадки: [код выхода, вывод]
$setup = function (string ...$args) use ($owner): array {
    exec('cd ' . escapeshellarg(WEB) . ' && runuser -u ' . escapeshellarg($owner) . ' -- php8.5 index.php setup '
        . implode(' ', array_map('escapeshellarg', $args)) . ' 2>&1', $out, $code);
    return [$code, implode("\n", $out)];
};

// 1. основы слов
if (check('класс Stemmer есть', class_exists(Stemmer::class))) {
    $same = fn(array $words) => count(array_unique(array_map([Stemmer::class, 'stem'], $words))) === 1;
    check('ru: услуги, услуга, услугами, услугу, Услуг — одна основа', $same(['услуги', 'услуга', 'услугами', 'услугу', 'Услуг']));
    check('ru: цены, цена, ценами — одна основа', $same(['цены', 'цена', 'ценами']));
    check('ru: стоимость, стоимости — одна основа', $same(['стоимость', 'стоимости']));
    check('ua: послуги, послуга, послугами — одна основа', $same(['послуги', 'послуга', 'послугами']));
    check('en: services, service — одна основа; prices, price — одна', $same(['services', 'service']) && $same(['prices', 'price']));
    check('ё и е: ёлка, елки — одна основа', $same(['ёлка', 'елки']));
    check('короткие слова и числа — как есть', Stemmer::stem('IT') === 'it' && Stemmer::stem('2024') === '2024');
    check('words: слова текста, знаки и пробелы — разделители', Stemmer::words('Наши «услуги»: доставка, 24/7!') === ['наши', 'услуги', 'доставка', '24', '7'],
        json_encode(Stemmer::words('Наши «услуги»: доставка, 24/7!'), JSON_UNESCAPED_UNICODE));
}

// 2. текст страницы из HTML
if (check('класс SearchIndex есть', class_exists(SearchIndex::class))) {
    $t = SearchIndex::text('<p>Один&nbsp;два</p><p>три &amp; четыре</p><script>x()</script>');
    check('SearchIndex::text: теги — пробелы, script — прочь, сущности раскрыты', $t === 'Один два три & четыре', $t);
}

// 3. стенд и переиндексация всего сайта
if (!check('таблица индекса share_search_index есть (sql/cut/stage20.sql)', (bool)q("SHOW TABLES LIKE 'share_search_index'")->fetch())) {
    done('search');
}
$root = (int)scalar('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL');
$info = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'info' AND smap_pid = ?", [$root]);
$langs = q('SELECT lang_id, lang_abbr, lang_default FROM share_languages ORDER BY lang_default DESC, lang_id')->fetchAll();
[$L1, $L2] = [(int)$langs[0]['lang_id'], (int)($langs[1]['lang_id'] ?? 0)];
function unstand(): void {
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-sr-child', 'claude-sr', 'claude-sr-link', 'claude-sr-ruonly')");
}
unstand();
register_shutdown_function('unstand');
$stand = function (string $segment, array $o = []) use ($root, $info, $langs): int {
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num, smap_redirect_url)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, 0, 999, ?)", [$o['pid'] ?? $root, $segment, $o['redirect'] ?? null]);
    $id = (int)pdo()->lastInsertId();
    foreach ($langs as $l) {
        q('INSERT INTO share_sitemap_translation (smap_id, lang_id, smap_name, smap_is_disabled) VALUES (?, ?, ?, ?)',
            [$id, $l['lang_id'], $o['names'][$l['lang_abbr']] ?? 'Стенд поиска', (int)!empty($o['disabled'][$l['lang_abbr']])]);
    }
    q('INSERT INTO share_access_level (smap_id, group_id, right_id) SELECT ?, group_id, right_id FROM share_access_level WHERE smap_id = ?', [$id, $info]);
    if (!empty($o['texts'])) {
        q("INSERT INTO share_textblocks (smap_id, tb_num) VALUES (?, '1')", [$id]);
        $tb = (int)pdo()->lastInsertId();
        foreach ($langs as $l) {
            if (isset($o['texts'][$l['lang_abbr']])) {
                q('INSERT INTO share_textblocks_translation (tb_id, lang_id, tb_content) VALUES (?, ?, ?)', [$tb, $l['lang_id'], $o['texts'][$l['lang_abbr']]]);
            }
        }
    }
    return $id;
};
$sr = $stand('claude-sr', ['names' => ['ru' => 'Стенд поиска', 'ua' => 'Стенд пошуку'],
    'texts' => ['ru' => '<p>Наши <b>услуги</b>: доставка мебели по городу</p>', 'ua' => '<p>Наші послуги: доставка меблів</p>']]);
$link = $stand('claude-sr-link', ['redirect' => '/info/', 'texts' => ['ru' => '<p>Ссылка-услуги</p>']]);
$ruOnly = $stand('claude-sr-ruonly', ['disabled' => ['ua' => 1], 'texts' => ['ru' => '<p>Только по-русски: услуги</p>', 'ua' => '<p>Тільки</p>']]);
$child = $stand('claude-sr-child', ['pid' => $sr, 'texts' => ['ru' => '<p>Подраздел стенда: услуги</p>']]);
$row =fn(int $id, int $lang) => q('SELECT title, body, title_stems, body_stems FROM share_search_index WHERE smap_id = ? AND lang_id = ?', [$id, $lang])->fetch();

[$code, $out] = $setup('reindex');
check('setup reindex — код 0 и число страниц в выводе', $code === 0 && str_contains($out, 'В индексе поиска страниц'), substr($out, -300));
// список служебных сегментов индекса — тот же, что у редактора разделов (компонент в setup не загрузить)
$src = (string)file_get_contents(ROOT . '/core/modules/share/components/DivisionEditor.php');
preg_match('~SYSTEM_SEGMENTS = (\[[^\]]+\])~', $src, $m);
check('SearchIndex::SYSTEM_SEGMENTS — тот же список, что DivisionEditor::SYSTEM_SEGMENTS',
    isset($m[1]) && eval('return ' . $m[1] . ';') === SearchIndex::SYSTEM_SEGMENTS, $m[1] ?? 'нет');
$r = $row($sr, $L1);
check('индекс: страница стенда — название, текст и основы', $r && $r['title'] === 'Стенд поиска' && str_contains($r['body'], 'Наши услуги: доставка мебели')
    && preg_match('~(^| )услуг( |$)~u', $r['body_stems']) && preg_match('~(^| )поиск( |$)~u', $r['title_stems']), json_encode($r, JSON_UNESCAPED_UNICODE));
if ($L2) {
    $r = $row($sr, $L2);
    check('индекс: второй язык — свой текст', $r && str_contains($r['body'], 'Наші послуги') && preg_match('~(^| )послуг( |$)~u', $r['body_stems']),
        json_encode($r, JSON_UNESCAPED_UNICODE));
    check('страница, выключенная на втором языке, — на нём не в индексе, на основном — в индексе', !$row($ruOnly, $L2) && $row($ruOnly, $L1));
}
check('страница-ссылка — не в индексе', !$row($link, $L1));
$loginId = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'login' AND smap_pid = ?", [$root]);
$adminId = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'admin' AND smap_pid = ?", [$root]);
check('служебные страницы (вход, админка и её разделы) — не в индексе', !$row($loginId, $L1) && !$row($adminId, $L1)
    && (int)scalar('SELECT COUNT(*) FROM share_search_index i JOIN share_sitemap s USING (smap_id) WHERE s.smap_pid = ?', [$adminId]) === 0);
check('обычная страница сайта (info) — в индексе', (bool)$row($info, $L1));
$rows1 = (int)scalar('SELECT COUNT(*) FROM share_search_index');
[$code2] = $setup('reindex');
$rows2 = (int)scalar('SELECT COUNT(*) FROM share_search_index');
check('setup reindex повторяем: код 0, строк столько же', $code2 === 0 && $rows1 > 0 && $rows1 === $rows2, "$rows1 → $rows2");

// 4. индекс обновляется сам: правка текста на странице, откат из истории, переименование и выключение на языке,
// перенос раздела в служебный и обратно (вместе с подразделом), удаление
login();
[$c] = http('/claude-sr/single/textBlock_1/save-text', ['data' => '<p>Наши услуги: калибровка весов и доставка</p>', 'ID' => $sr, 'num' => 1]);
$r = $row($sr, $L1);
check('правка текста на странице — новое слово в индексе', $c == 200 && $r && str_contains($r['body'], 'калибровка')
    && preg_match('~(^| )калибровк( |$)~u', $r['body_stems']), "HTTP $c " . json_encode($r, JSON_UNESCAPED_UNICODE));
$tbh = (int)scalar('SELECT h.tbh_id FROM share_textblocks_history h JOIN share_textblocks t USING (tb_id) WHERE t.smap_id = ? AND h.lang_id = ?
    ORDER BY h.tbh_id DESC LIMIT 1', [$sr, $L1]);
[$c, $j] = json("/claude-sr/single/textBlock_1/history/restore/$tbh/", '');
$r = $row($sr, $L1);
check('откат из истории — в индексе прежний текст', !empty($j['result']) && $r && !str_contains($r['body'], 'калибровка')
    && str_contains($r['body'], 'доставка мебели'), "HTTP $c " . json_encode($r, JSON_UNESCAPED_UNICODE));
$renamed = savePage($sr, $root, 'claude-sr', ['names' => [$L1 => 'Переименованный стенд', $L2 => 'Перейменований стенд'], 'disabled' => [$L2 => 1]]);
$r = $row($sr, $L1);
check('переименование страницы — новое название в индексе', $renamed === $sr && $r && $r['title'] === 'Переименованный стенд'
    && preg_match('~(^| )переименова~u', $r['title_stems']), json_encode($r, JSON_UNESCAPED_UNICODE));
if ($L2) {
    check('выключение страницы на втором языке — на нём её нет в индексе', $renamed === $sr && !$row($sr, $L2));
}
$profile = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'profile' AND smap_pid = ?", [$root]);
check('подраздел стенда — в индексе (до переноса)', (bool)$row($child, $L1));
$moved = savePage($sr, $profile, 'claude-sr', ['names' => [$L1 => 'Переименованный стенд']]);
check('перенос раздела в служебный (профиль) — ни раздела, ни его подраздела в индексе', $moved === $sr && !$row($sr, $L1) && !$row($child, $L1));
$back = savePage($sr, $root, 'claude-sr', ['names' => [$L1 => 'Переименованный стенд']]);
check('перенос обратно — раздел и подраздел снова в индексе', $back === $sr && $row($sr, $L1) && $row($child, $L1));
check('удаление страницы — её строк в индексе нет', deletePage($ruOnly) && !$row($ruOnly, $L1));
// сбой индекса (таблицы нет) не отменяет сохранение: текст в базе, ответ — «сохранено», ошибка — в журнале ошибок
function indexBack(): void {
    if (q("SHOW TABLES LIKE 'claude_search_index_off'")->fetch()) {
        q('RENAME TABLE claude_search_index_off TO share_search_index');
    }
}
indexBack();
register_shutdown_function('indexBack');
$logFrom = is_readable($E['LOG']) ? (int)filesize($E['LOG']) : 0;
q('RENAME TABLE share_search_index TO claude_search_index_off');
[$c, $j] = json('/claude-sr/single/textBlock_1/save-text', ['data' => '<p>Сбой индекса: текст сохранён</p>', 'ID' => $sr, 'num' => 1]);
indexBack();
$saved = (string)scalar('SELECT tt.tb_content FROM share_textblocks t JOIN share_textblocks_translation tt USING (tb_id)
    WHERE t.smap_id = ? AND t.tb_num = ? AND tt.lang_id = ?', [$sr, '1', $L1]);
$logged = is_readable($E['LOG']) ? (string)file_get_contents($E['LOG'], false, null, $logFrom) : 'журнала нет';
check('сбой индекса: текст сохранён, ответ — сохранено, ошибка — в журнале ошибок', $c == 200 && !empty($j['result'])
    && str_contains($saved, 'Сбой индекса') && ($logged === 'журнала нет' || str_contains($logged, 'Energine: индекс поиска')),
    "HTTP $c " . json_encode($j, JSON_UNESCAPED_UNICODE) . ' | ' . substr($saved, 0, 80));
logout();
// общий блок (без страницы) не индексируется; взаимная блокировка откатывает всю транзакцию сохранения — её ошибка
// уходит вызывающему (откат и сообщение), а не в журнал с ответом «сохранено» — по коду
$th = (string)file_get_contents(ROOT . '/core/modules/share/gears/TextHistory.php');
$si = (string)file_get_contents(ROOT . '/core/modules/share/gears/SearchIndex.php');
check('по коду: индекс при сохранении текста — только у блока страницы (общий блок без страницы — нет), через refresh',
    preg_match('~if \(\$block\[.smap_id.\]\)\s*\{\s*SearchIndex::refresh\(~', $th) === 1);
check('по коду: сохранение раздела обновляет индекс через refresh',
    str_contains((string)file_get_contents(ROOT . '/core/modules/share/components/DivisionEditor.php'), 'SearchIndex::refresh('));
check('по коду: refresh — сбой в журнал, взаимная блокировка (40001) — вызывающему',
    preg_match("~getCode\(\) === '40001'\)\s*\{\s*throw \\\$e;~", $si) === 1 && str_contains($si, "error_log('Energine: индекс поиска: '"));

done('search');
