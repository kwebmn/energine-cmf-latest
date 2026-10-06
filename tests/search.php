<?php
// Поиск по сайту: основы слов (Stemmer), индекс страниц (SearchIndex, setup reindex), обновление индекса, страница
// результатов, журнал поиска.
// Стенд: страницы claude-sr (текст на двух языках), claude-sr-link (страница-ссылка), claude-sr-ruonly (выключена на
// втором языке) — в базе напрямую, без сдвига порядка; удаляются в конце (строки индекса — каскадом).
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
    q("DELETE FROM share_sitemap WHERE smap_segment IN ('claude-sr', 'claude-sr-link', 'claude-sr-ruonly')");
}
unstand();
register_shutdown_function('unstand');
$stand = function (string $segment, array $o = []) use ($root, $info, $langs): int {
    q("INSERT INTO share_sitemap (smap_layout, smap_content, smap_pid, smap_segment, smap_in_menu, smap_order_num, smap_redirect_url)
       VALUES ('default.layout.xml', 'textblock.content.xml', ?, ?, 0, 999, ?)", [$root, $segment, $o['redirect'] ?? null]);
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
$row = fn(int $id, int $lang) => q('SELECT title, body, title_stems, body_stems FROM share_search_index WHERE smap_id = ? AND lang_id = ?', [$id, $lang])->fetch();

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

done('search');
