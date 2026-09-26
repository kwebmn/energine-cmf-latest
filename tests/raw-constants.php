<?php
// Системные имена подписей (FIELD_…, TXT_…, BTN_…, MSG_…, ERR_…, TAB_… и т. п.), которые видны
// на страницах вместо текста: так выглядит константа, которой нет в справочнике переводов.
// Обходит страницы гостя (paths-guest.txt) и администратора (paths-all.txt), а для каждого грида
// из audit/crawl-singles.txt — его страницу, данные get-data, форму добавления и правки первой записи.
// Печатает отсортированные строки «имя<TAB>адрес». Сравнивать до и после чистки переводов:
//   php8.5 tests/raw-constants.php > before.txt
//   … чистка …
//   php8.5 tests/raw-constants.php > after.txt
//   comm -13 <(cut -f1 before.txt | sort -u) <(cut -f1 after.txt | sort -u)   # должно быть пусто
require __DIR__ . '/testlib.php';

const RAW = '/\b(?:FIELD|TXT|BTN|CONTENT|ERR|MSG|TAB|EXPORT|LAYOUT|LNK|FILTER|SHOW|ERROR|LBL)_[A-Z0-9_]{2,}\b/';

$found = [];
function note(array $names, string $where): void {
    foreach ($names as $n) $GLOBALS['found'][$n . "\t" . $where] = true;
}
function rawInHtml(string $html): array {
    $names = [];
    $dom = new DOMDocument();
    @$dom->loadHTML('<?xml encoding="utf-8"?>' . $html, LIBXML_NOWARNING | LIBXML_NOERROR);
    $xp = new DOMXPath($dom);
    $nodes = $xp->query('//text()[not(ancestor::script) and not(ancestor::style)]'
        . ' | //@title | //@alt | //@placeholder | //@value | //@data-title | //@aria-label');
    foreach ($nodes as $n) {
        if (preg_match_all(RAW, $n->nodeValue, $m)) array_push($names, ...$m[0]);
    }
    // переводы, переданные скриптам: у отсутствующей константы значение совпадает с именем
    foreach ($xp->query('//script') as $s) {
        if (preg_match_all('/"([A-Z]+_[A-Z0-9_]+)"\s*:\s*"\1"/', $s->nodeValue, $m)) array_push($names, ...$m[1]);
    }
    return array_values(array_unique($names));
}
function rawInJson($data): array {
    $names = [];
    array_walk_recursive($data, function ($v) use (&$names) {
        if (is_string($v) && preg_match('/^' . trim(RAW, '/') . '$/', $v)) $names[] = $v;
    });
    return array_values(array_unique($names));
}
function paths(string $file): array {
    return array_values(array_filter(array_map('trim', file(__DIR__ . '/' . $file)), 'strlen'));
}

// гость; главная на обоих языках — отдельно: в списках путей её нет (пустые строки пропускаются)
logout();
foreach (['', 'ua/', ...paths('paths-guest.txt')] as $p) {
    [, $html] = http('/' . ltrim($p, '/'));
    note(rawInHtml($html), 'guest /' . $p);
}
// администратор: страницы
login();
foreach (['', ...paths('paths-all.txt')] as $p) {
    [, $html] = http('/' . ltrim($p, '/'));
    note(rawInHtml($html), 'admin /' . $p);
}
// гриды: страница, данные, формы
foreach (paths('audit/crawl-singles.txt') as $single) {
    $single = '/' . ltrim($single, '/');
    [, $html] = http($single);
    note(rawInHtml($html), 'grid ' . $single);
    [$c, $j] = json($single . 'get-data/page-1');
    // только описание полей: в строках данных такие имена бывают содержимым (редактор переводов)
    if (is_array($j)) note(rawInJson($j['meta'] ?? []), 'data ' . $single);
    if (!preg_match('~[dD]ivEditor/$~', $single)) {
        [, $html] = http($single . 'add/');
        note(rawInHtml($html), 'add ' . $single);
    }
    $pk = is_array($j['meta'] ?? null) ? array_key_first(array_filter($j['meta'], fn($f) => !empty($f['key']))) : null;
    $row = $j['data'][0] ?? null;
    if ($pk && $row && isset($row[$pk])) {
        [, $html] = http($single . $row[$pk] . '/edit/');
        note(rawInHtml($html), 'edit ' . $single);
    }
}
logout();

$lines = array_keys($found);
sort($lines);
echo implode("\n", $lines), $lines ? "\n" : '';
