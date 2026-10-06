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
    // апостроф внутри слова — часть слова и убирается: FULLTEXT делит слово по апострофу («п» и «ять» не в индексе)
    check("words: апостроф — часть слова и убирается: П'ять м’ясних комп'ютерів", Stemmer::words("П'ять м’ясних комп'ютерів") === ['пять', 'мясних', 'компютерів'],
        json_encode(Stemmer::words("П'ять м’ясних комп'ютерів"), JSON_UNESCAPED_UNICODE));
    check("ua: комп'ютери, комп’ютерів, компютер — одна основа", $same(["комп'ютери", 'комп’ютерів', 'компютер']));
    check('слова через дефис — два слова: интернет-магазин', Stemmer::words('Интернет-магазин') === ['интернет', 'магазин']);
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
    // все стенды claude-sr…; подразделы стендов уходят каскадом
    q("DELETE FROM share_sitemap WHERE smap_segment LIKE 'claude-sr%'");
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

// 5. поиск: страница результатов (/search/?q=), видимость, порядок, отрывок, языки, листалка, служебные знаки, бюджет
//    запросов, поле в шапке. Стенды со словом «флюгер» в разных формах: в названии (claude-sr-title) и в тексте
//    (claude-sr-text, с «<script>» в тексте), закрытый гостю (claude-sr-closed), только на втором языке (claude-sr-ua, с
//    апострофом), страница-ссылка (claude-sr-flink), служебный (claude-sr-sys — в профиле), подраздел выключенного на
//    языке раздела (claude-sr-hidden/claude-sr-kid), листалка — ещё одиннадцать (claude-sr-p01…p11).
$admins = (int)scalar('SELECT group_id FROM share_access_level WHERE smap_id = ? AND right_id = 3 ORDER BY group_id LIMIT 1', [$root]);
$ss = [
    'title' => $stand('claude-sr-title', ['names' => ['ru' => 'Флюгеры для крыш', 'ua' => 'Флюгери для дахів'], 'texts' => ['ru' => '<p>Мастерская делает разные вещи</p>']]),
    'text' => $stand('claude-sr-text', ['names' => ['ru' => 'Стенд текста', 'ua' => 'Стенд тексту'],
        'texts' => ['ru' => '<p>Кованые флюгерами украшают крыши: флюгер на каждом доме. Пример кода: &lt;script&gt;alert(1)&lt;/script&gt; и &amp;nbsp; в тексте.</p>']]),
    'closed' => $stand('claude-sr-closed', ['texts' => ['ru' => '<p>Закрытый флюгер</p>']]),
    'ua' => $stand('claude-sr-ua', ['disabled' => ['ru' => 1], 'names' => ['ua' => 'Мідь'], 'texts' => ['ua' => '<p>Мідні флюгери для комп’ютерів</p>', 'ru' => '<p>Медные флюгеры</p>']]),
    'flink' => $stand('claude-sr-flink', ['redirect' => '/info/', 'texts' => ['ru' => '<p>Ссылка на флюгеры</p>']]),
    'sys' => $stand('claude-sr-sys', ['pid' => $profile, 'texts' => ['ru' => '<p>Служебный флюгер</p>']]),
    'hidden' => $stand('claude-sr-hidden', ['disabled' => ['ru' => 1]]),
];
$ss['kid'] = $stand('claude-sr-kid', ['pid' => $ss['hidden'], 'texts' => ['ru' => '<p>Флюгер в скрытом разделе</p>']]);
for ($i = 1; $i <= 11; $i++) {
    $ss[sprintf('p%02d', $i)] = $stand(sprintf('claude-sr-p%02d', $i), ['texts' => ['ru' => "<p>Флюгер номер $i</p>"]]);
}
// закрытый — только администраторам
q('DELETE FROM share_access_level WHERE smap_id = ? AND group_id <> ?', [$ss['closed'], $admins]);
q('REPLACE INTO share_access_level (smap_id, group_id, right_id) VALUES (?, ?, 3)', [$ss['closed'], $admins]);
foreach ($ss as $id) {
    (new SearchIndex(pdo()))->page($id);
}
$find = function (string $q, string $lang = '', string $extra = ''): array {
    [$c, $b] = http('/' . $lang . 'search/?q=' . rawurlencode($q) . $extra);
    preg_match_all('~<li class="search-result[^"]*">\s*<a[^>]*href="[^"]*?/((?:ua/)?claude-sr[a-z0-9-]*)/"~', $b, $m);
    return [$c, $b, $m[1]];
};
$has = fn(array $links, string $segment) => in_array($segment, array_map(fn($l) => preg_replace('~^ua/~', '', $l), $links), true);
logout();
[$c, $b, $links] = $find('флюгеры');
$found = (string)translation('TXT_SEARCH_FOUND');
check('гость /search/?q=флюгеры — 200, «Найдено страниц: 13», на первой странице 10', $c == 200 && $found !== ''
    && str_contains($b, $found . ': 13') && count($links) === 10, "HTTP $c " . implode(' ', $links));
check('другие формы слова: «флюгеры» находит «флюгерами» (текст) и «Флюгеры» (название)', $has($links, 'claude-sr-text') && $has($links, 'claude-sr-title'),
    implode(' ', $links));
check('совпадение в названии — выше совпадения в тексте; два совпадения в тексте — выше одного', ($links[0] ?? '') === 'claude-sr-title'
    && ($links[1] ?? '') === 'claude-sr-text', implode(' ', $links));
check('не находятся: закрытая гостю, выключенная на языке, страница-ссылка, служебная, подраздел выключенного раздела',
    !array_intersect(['claude-sr-closed', 'claude-sr-ua', 'claude-sr-flink', 'claude-sr-sys', 'claude-sr-kid'], $links)
    && !preg_match('~claude-sr-(closed|ua|flink|sys|kid)/~', $b), implode(' ', $links));
check('отрывок: найденное слово в <mark>', str_contains($b, '<mark>флюгерами</mark>') && str_contains($b, '<mark>Флюгер</mark>'), substr($b, (int)strpos($b, 'search-results'), 600));
check('отрывок: «<script>» и «&nbsp;» из текста страницы — текстом (экранированы)', str_contains($b, '&lt;script&gt;alert(1)&lt;/script&gt;')
    && str_contains($b, '&amp;nbsp;') && !str_contains($b, '<script>alert(1)'), substr($b, (int)strpos($b, 'claude-sr-text'), 500));
[$c, $b, $links2] = $find('флюгеры', '', '&page=2');
check('листалка: вторая страница — остальные 3, номер 2 текущий, ссылка на первую', $c == 200 && count($links2) === 3 && !array_intersect($links, $links2)
    && preg_match('~aria-current="page"[^>]*>2<~', $b) && preg_match('~href="[^"]*search/\?q=[^"&]*&amp;page=1"~', $b), "HTTP $c " . implode(' ', $links2));
[$c, , $links3] = $find('флюгеры', '', '&page=99');
check('листалка: номер за последней — последняя страница', $c == 200 && $links3 === $links2, implode(' ', $links3));
if ($L2) {
    [$c, $b, $ua] = $find('флюгери', 'ua/');
    check('второй язык /ua/search/ — страницы этого языка: только на нём (claude-sr-ua) и название (claude-sr-title); нет текста первого',
        $c == 200 && $has($ua, 'claude-sr-ua') && $has($ua, 'claude-sr-title') && !$has($ua, 'claude-sr-text') && !$has($ua, 'claude-sr-p01')
        && str_contains($b, 'href="' . BASE . '/ua/claude-sr-ua/"'), "HTTP $c " . implode(' ', $ua));
    [$c, , $ua] = $find("комп'ютери", 'ua/');
    check("апостроф: «комп'ютери» находит «комп’ютерів»", $c == 200 && $has($ua, 'claude-sr-ua'), implode(' ', $ua));
}
[$c, $b] = $find('');
check('пустой запрос — поле и подсказка, без «Найдено»', $c == 200 && str_contains($b, 'id="search-q"') && str_contains($b, (string)translation('TXT_SEARCH_HINT'))
    && !str_contains($b, 'search-total'), "HTTP $c");
[$c, $b] = $find('зюзюзюзяблик');
check('ничего не найдено — совет', $c == 200 && str_contains($b, (string)translation('TXT_SEARCH_NOTHING')), "HTTP $c");
[$c, $b] = $find('IT 24 я');
check('запрос из одних коротких слов — «ничего не найдено», не ошибка', $c == 200 && str_contains($b, (string)translation('TXT_SEARCH_NOTHING')), "HTTP $c");
[$c, , $links] = $find('+флюгеры -"(<>~@*)');
check('служебные знаки FULLTEXT в запросе — 200, ищутся слова', $c == 200 && $has($links, 'claude-sr-title'), "HTTP $c " . implode(' ', $links));
[$c, $b] = $find('+-*"()<>~@');
check('запрос из одних знаков — 200, подсказка или «ничего»', $c == 200 && (str_contains($b, (string)translation('TXT_SEARCH_NOTHING'))
    || str_contains($b, (string)translation('TXT_SEARCH_HINT'))), "HTTP $c");
[$c, $b] = $find('<script>alert(1)</script>');
check('запрос с <script> — только в значении поля (экранирован), не разметкой', $c == 200
    && preg_match_all('~<script>alert\(1\)</script>~', $b) === preg_match_all('~value="[^"]*<script>alert\(1\)</script>[^"]*"~', $b)
    && !str_contains($b, '"><script>'), "HTTP $c");
[$c, $b] = $find(str_repeat('флюгер ', 100));
check('очень длинный запрос — 200, в поле не длиннее 200 знаков', $c == 200 && preg_match('~<input id="search-q"[^>]*\bvalue="([^"]*)"~', $b, $m)
    && mb_strlen(html_entity_decode($m[1])) <= 200, "HTTP $c " . mb_strlen(html_entity_decode($m[1] ?? '')));
[$c, , $links] = $find('флюгеры 😀 𝐀');
check('символы вне BMP (эмодзи) — 200, ищутся остальные слова', $c == 200 && $has($links, 'claude-sr-title'), "HTTP $c");
[$c] = http('/search/?q=%FF%FE');
[$c2] = http('/search/?q[]=x&page[]=2');
[$c3] = http('/search/?q=' . rawurlencode('флюгеры') . '&page=abc');
check('неверный UTF-8, массив вместо строки, page не число — 200', $c == 200 && $c2 == 200 && $c3 == 200, "$c $c2 $c3");
// бюджет запросов страницы результатов (при отладке — document/@queries)
[$c, $b] = http('/search/?q=' . rawurlencode('флюгеры') . '&debug');
if ($c == 200 && str_starts_with(ltrim($b), '<?xml') && ($x = @simplexml_load_string($b)) && isset($x['queries'])) {
    check('страница результатов — не больше 20 запросов к базе (сейчас ' . (int)$x['queries'] . ')', (int)$x['queries'] <= 20);
} else {
    echo "SKIP бюджет запросов: отладка выключена\n";
}
// администратору видна и закрытая гостю страница
login();
[$c, $b] = $find('флюгеры');
check('администратору — и закрытая гостю страница (всего 14)', str_contains($b, $found . ': 14'), "HTTP $c");
logout();
// поле поиска в шапке — на странице своего языка
[$c, $b] = http('/');
check('шапка главной: поле поиска (форма GET на /search/, поле q)', $c == 200
    && preg_match('~<form class="site-search[^"]*"[^>]*method="get"[^>]*action="' . preg_quote(BASE, '~') . '/search/"~', $b)
    && preg_match('~<input id="site-search-q"[^>]*name="q"~', $b), "HTTP $c");
if ($L2) {
    [$c, $b] = http('/ua/');
    check('шапка /ua/: поиск на /ua/search/', $c == 200 && str_contains($b, 'action="' . BASE . '/ua/search/"'), "HTTP $c");
}
// сама страница поиска — служебная: в индексе её нет, её сегмент — в списках служебных
$searchId = (int)scalar("SELECT smap_id FROM share_sitemap WHERE smap_segment = 'search' AND smap_pid = ?", [$root]);
check('страница search есть у корня, служебная (SYSTEM_SEGMENTS), не в индексе', $searchId && in_array('search', SearchIndex::SYSTEM_SEGMENTS, true)
    && !(int)scalar('SELECT COUNT(*) FROM share_search_index WHERE smap_id = ?', [$searchId]));

done('search');
