<?php
// Кандидаты на удаление из справочника переводов после вырезания модулей.
//   php8.5 tests/tools/cut-constants.php --removed=ПУТЬ... --old-db-config=ФАЙЛ --cut-tables=REGEXP [--cut-column=таблица.колонка...]
// --removed        файлы и каталоги вырезанного кода (копии, пока они есть, например в полной версии);
// --old-db-config  конфиг базы, где вырезанные таблицы ещё есть (из неё берутся их колонки);
// --cut-tables     выражение REGEXP для имён вырезанных таблиц;
// --cut-column     вырезанная колонка оставшейся таблицы.
// Константа попадает в список, если она есть в справочнике текущей площадки, встречается
// в вырезанном коде или имеет вид FIELD_<вырезанная колонка>[_ENUM_…], и при этом:
//   - не встречается в оставшемся коде (core, site, htdocs, setup);
//   - не может быть собрана динамически оставшимся кодом: FIELD_<колонка оставшейся таблицы>,
//     FIELD_<колонка>_ENUM_…, TXT_<имя компонента на страницах и в шаблонах>, TXT_<право>.
// Печатает имена по одному в строке, служебную сводку — в stderr.
$E = require dirname(__DIR__) . '/env.php';
$root = $E['ROOT'];
$opt = ['removed' => [], 'cut-column' => []];
foreach (array_slice($argv, 1) as $a) {
    if (!preg_match('/^--([a-z-]+)=(.*)$/', $a, $m)) { fwrite(STDERR, "непонятный аргумент $a\n"); exit(2); }
    if (in_array($m[1], ['removed', 'cut-column'])) $opt[$m[1]][] = $m[2]; else $opt[$m[1]] = $m[2];
}
foreach (['old-db-config', 'cut-tables'] as $k) if (empty($opt[$k])) { fwrite(STDERR, "нужен --$k\n"); exit(2); }

const TOKEN = '/\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b/';
function files(array $paths): Generator {
    foreach ($paths as $p) {
        if (is_file($p)) { yield $p; continue; }
        if (!is_dir($p)) { fwrite(STDERR, "нет пути $p\n"); exit(2); }
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($p, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $f) if ($f->isFile() && preg_match('/\.(php|xml|xslt|js|html|css)$/', $f->getFilename())) yield $f->getPathname();
    }
}
function tokens(array $paths): array {
    $t = [];
    foreach (files($paths) as $f) {
        if (preg_match_all(TOKEN, file_get_contents($f), $m)) foreach ($m[0] as $x) $t[$x] = true;
    }
    return $t;
}
function pdoFor(string $configFile): PDO {
    $d = (include $configFile)['database'];
    return new PDO("mysql:host={$d['host']};dbname={$d['db']};charset=utf8", $d['username'], $d['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
}
$cur = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$old = pdoFor($opt['old-db-config']);

$dict = array_fill_keys($cur->query('SELECT ltag_name FROM share_lang_tags')->fetchAll(PDO::FETCH_COLUMN), true);

// вырезанное: токены кода и колонки вырезанных таблиц
$removed = array_intersect_key(tokens($opt['removed']), $dict);
$st = $old->prepare('SELECT DISTINCT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME REGEXP ?');
$st->execute([$opt['cut-tables']]);
$cutCols = $st->fetchAll(PDO::FETCH_COLUMN);
foreach ($opt['cut-column'] as $tc) $cutCols[] = explode('.', $tc, 2)[1];
foreach ($dict as $name => $_) {
    foreach ($cutCols as $c) {
        $f = 'FIELD_' . strtoupper($c);
        if ($name === $f || str_starts_with($name, $f . '_ENUM_')) $removed[$name] = true;
    }
}

// оставшееся: код, колонки, компоненты, права
$kept = tokens(array_map(fn($d) => "$root/$d", ['core', 'site', 'htdocs', 'setup']));
$keptCols = array_map('strtoupper', $cur->query('SELECT DISTINCT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()')->fetchAll(PDO::FETCH_COLUMN));
$components = [];
$xml = '';
foreach (files(["$root/core", "$root/site"]) as $f) if (str_ends_with($f, '.xml')) $xml .= file_get_contents($f);
$xml .= implode('', $cur->query('SELECT CONCAT_WS(" ", smap_content_xml, smap_layout_xml) FROM share_sitemap')->fetchAll(PDO::FETCH_COLUMN));
$xml .= implode('', $cur->query('SELECT widget_xml FROM share_widgets')->fetchAll(PDO::FETCH_COLUMN));
if (preg_match_all('/<component\b[^>]*\bname="([^"]+)"/', $xml, $m)) foreach ($m[1] as $n) $components['TXT_' . strtoupper($n)] = true;
$rights = [];
foreach ($cur->query('SELECT right_const FROM user_group_rights')->fetchAll(PDO::FETCH_COLUMN) as $r) $rights['TXT_' . $r] = true;

$out = [];
foreach ($removed as $name => $_) {
    if (isset($kept[$name]) || isset($components[$name]) || isset($rights[$name])) continue;
    $dynamicField = false;
    foreach ($keptCols as $c) {
        $f = 'FIELD_' . $c;
        if ($name === $f || str_starts_with($name, $f . '_ENUM_')) { $dynamicField = true; break; }
    }
    if (!$dynamicField) $out[] = $name;
}
sort($out);
fwrite(STDERR, sprintf("справочник %d, из вырезанного %d, колонок вырезанных таблиц %d, к удалению %d\n",
    count($dict), count($removed), count($cutCols), count($out)));
echo implode("\n", $out), $out ? "\n" : '';
