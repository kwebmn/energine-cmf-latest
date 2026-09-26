<?php
// Кандидаты на удаление из справочника переводов после вырезания модулей.
//   php8.5 tests/tools/cut-constants.php --removed=ПУТЬ... --old-db-config=ФАЙЛ --cut-tables=REGEXP [--cut-column=таблица.колонка...]
// --removed        файлы и каталоги вырезанного кода (копии, пока они есть, например в полной версии);
// --old-db-config  конфиг базы, где вырезанные таблицы ещё есть (из неё берутся их колонки);
// --cut-tables     выражение REGEXP для имён вырезанных таблиц;
// --cut-column     вырезанная колонка оставшейся таблицы.
//
// Имена сравниваются без учёта регистра (в справочнике бывает FIELD_form_5_field_2).
// Со стороны вырезанного константа — кандидат, если она есть в справочнике текущей площадки и:
//   - встречается в вырезанном коде буквально;
//   - собирается из слова вырезанного кода: FIELD_/TXT_/CONTENT_/LAYOUT_/TAB_/CLASS_ + слово
//     (имена полей, компонентов, классов, параметров), FIELD_<слово>_ENUM_…;
//   - начинается с литерального префикса модуля в вырезанном коде ('EXPORT_ORDERS_' . …;
//     общие префиксы FIELD_, TXT_ и т. п. сюда не входят — иначе в список попадут все
//     неиспользуемые константы с этим префиксом, а не только вырезанного модуля);
//   - это TAB_ или FIELD_[…_ENUM_…] вырезанной таблицы и её колонок, CONTENT_/LAYOUT_ её шаблонов.
// Кандидат остаётся в справочнике, если оставшийся код может его использовать:
//   - имя встречается в оставшемся коде (core, site, htdocs, setup) буквально;
//   - собирается тем же способом из слова оставшегося кода или базы (XML страниц и виджетов,
//     права, шаблоны страниц), из колонки или таблицы оставшейся базы, из имени её шаблона;
//   - начинается с литерального префикса оставшегося кода ('TXT_MONTH_' . …) — с запасом.
// Библиотеки сторонних разработчиков (CKEditor, CodeMirror, timthumb и т. п.) в словарь слов не входят.
// Комментарии тоже: слово из закомментированного кода или описания константу не использует.
// Печатает имена по одному в строке, сводку — в stderr.
$E = require dirname(__DIR__) . '/env.php';
$root = $E['ROOT'];
$opt = ['removed' => [], 'cut-column' => []];
foreach (array_slice($argv, 1) as $a) {
    if (!preg_match('/^--([a-z-]+)=(.*)$/', $a, $m)) { fwrite(STDERR, "непонятный аргумент $a\n"); exit(2); }
    if (in_array($m[1], ['removed', 'cut-column'])) $opt[$m[1]][] = $m[2]; else $opt[$m[1]] = $m[2];
}
foreach (['old-db-config', 'cut-tables'] as $k) if (empty($opt[$k])) { fwrite(STDERR, "нужен --$k\n"); exit(2); }

const DYNAMIC = ['FIELD', 'TXT', 'CONTENT', 'LAYOUT', 'TAB', 'CLASS'];
const VENDOR = '~/scripts/(ckeditor|codemirror|select2|jwplayer|FileAPI)/|/scripts/(mootools[^/]*|swfobject|Swiff\.Uploader)\.js$|/resizer/~';

function files(array $paths): Generator {
    foreach ($paths as $p) {
        // сторонние библиотеки не в счёт и тогда, когда файл передан явно (удалённые файлы этапа)
        if (is_file($p)) { if (!preg_match(VENDOR, $p)) yield $p; continue; }
        if (!is_dir($p)) { fwrite(STDERR, "нет пути $p\n"); exit(2); }
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($p, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $f) {
            $path = $f->getPathname();
            if ($f->isFile() && preg_match('/\.(php|xml|xslt|js|html|css)$/', $path) && !preg_match(VENDOR, $path)) yield $path;
        }
    }
}
// из набора текстов: слова (прописными), буквальные константы, литеральные префиксы 'XXX_' .
function scan(iterable $texts): array {
    $words = $prefixes = [];
    foreach ($texts as $t) {
        if (preg_match_all('/[A-Za-z_][A-Za-z0-9_]*/', $t, $m)) foreach ($m[0] as $w) $words[strtoupper($w)] = true;
        if (preg_match_all("/'([A-Z][A-Z0-9_]*_)'\\s*\\./", $t, $m)) foreach ($m[1] as $p) $prefixes[$p] = true;
    }
    return [$words, array_keys($prefixes)];
}
// текст файла без комментариев. PHP разбирается токенизатором; в JS и CSS снимаются только
// комментарии с начала строки: хвост «код; // …» и /* внутри строк ('image/*') остаются —
// лишнее слово может уберечь ненужную константу, но не удалить нужную
function stripComments(string $path, string $text): string {
    switch (pathinfo($path, PATHINFO_EXTENSION)) {
        case 'php':
            $out = '';
            foreach (token_get_all($text) as $t) {
                if (is_array($t) && in_array($t[0], [T_COMMENT, T_DOC_COMMENT], true)) { $out .= ' '; continue; }
                $out .= is_array($t) ? $t[1] : $t;
            }
            return $out;
        case 'xml': case 'xslt': case 'html':
            return preg_replace('/<!--.*?-->/s', ' ', $text);
        default:
            return preg_replace(['~^[ \t]*/\*.*?\*/~ms', '~^[ \t]*//.*$~m'], ' ', $text);
    }
}
function fileTexts(array $paths): Generator { foreach (files($paths) as $f) yield stripComments($f, file_get_contents($f)); }
function templateNames(array $paths): array {
    $n = [];
    foreach (files($paths) as $f) {
        if (preg_match('/([^\/]+)\.(content|layout)\.xml$/', $f, $m)) {
            $n['CONTENT_' . strtoupper($m[1])] = $n['LAYOUT_' . strtoupper($m[1])] = true;
        }
    }
    return $n;
}
// имя из справочника (прописными) собирается из слова: префикс динамический, остаток — слово
function builtFrom(string $name, array $words): bool {
    foreach (DYNAMIC as $p) {
        if (!str_starts_with($name, $p . '_')) continue;
        $rest = substr($name, strlen($p) + 1);
        if (isset($words[$rest])) return true;
        if ($p === 'FIELD' && ($i = strpos($rest, '_ENUM_')) !== false && isset($words[substr($rest, 0, $i)])) return true;
    }
    return false;
}
function pdoFor(string $configFile): PDO {
    $d = (include $configFile)['database'];
    return new PDO("mysql:host={$d['host']};dbname={$d['db']};charset=utf8", $d['username'], $d['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
}
$cur = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$old = pdoFor($opt['old-db-config']);

$dict = [];
foreach ($cur->query('SELECT ltag_name FROM share_lang_tags')->fetchAll(PDO::FETCH_COLUMN) as $n) $dict[strtoupper($n)] = $n;

// вырезанное
[$rWords, $rPrefixes] = scan(fileTexts($opt['removed']));
$st = $old->prepare('SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME REGEXP ?');
$st->execute([$opt['cut-tables']]);
foreach ($st->fetchAll(PDO::FETCH_NUM) as [$t, $c]) { $rWords[strtoupper($t)] = $rWords[strtoupper($c)] = true; }
foreach ($opt['cut-column'] as $tc) $rWords[strtoupper(explode('.', $tc, 2)[1])] = true;
$rTemplates = templateNames($opt['removed']);

// оставшееся: код, база
$keptPaths = array_map(fn($d) => "$root/$d", ['core', 'site', 'htdocs', 'setup']);
[$kWords, $kPrefixes] = scan(fileTexts($keptPaths));
// таблица может быть уже удалена этапом, который сейчас чистится (share_widgets — этап 3)
$exists = fn(string $t): bool => (bool)$cur->query('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ' . $cur->quote($t))->fetchColumn();
$dbTexts = array_merge(
    $cur->query('SELECT CONCAT_WS(" ", smap_content_xml, smap_layout_xml, smap_content, smap_layout) FROM share_sitemap')->fetchAll(PDO::FETCH_COLUMN),
    $exists('share_widgets') ? $cur->query('SELECT widget_xml FROM share_widgets')->fetchAll(PDO::FETCH_COLUMN) : [],
    $cur->query('SELECT right_const FROM user_group_rights')->fetchAll(PDO::FETCH_COLUMN),
    $cur->query('SELECT CONCAT_WS(" ", TABLE_NAME, COLUMN_NAME) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()')->fetchAll(PDO::FETCH_COLUMN));
[$dbWords, ] = scan(array_filter($dbTexts, 'is_string'));
$kWords += $dbWords;
$kTemplates = templateNames(array_map(fn($d) => "$root/$d", ['core', 'site']));

$out = [];
foreach ($dict as $upper => $name) {
    $removed = isset($rWords[$upper]) || builtFrom($upper, $rWords) || isset($rTemplates[$upper]);
    // префиксы модулей вроде 'EXPORT_ORDERS_' . …; общие ('FIELD_' . …) — это правило «слово + префикс»
    foreach ($rPrefixes as $p) if (!in_array(rtrim($p, '_'), DYNAMIC) && str_starts_with($upper, $p)) $removed = true;
    if (!$removed) continue;
    $kept = isset($kWords[$upper]) || builtFrom($upper, $kWords) || isset($kTemplates[$upper]);
    // литеральный префикс оставшегося кода ('TXT_MONTH_' . date('n')) защищает всё, что с него начинается
    foreach ($kPrefixes as $p) if (!in_array(rtrim($p, '_'), DYNAMIC) && str_starts_with($upper, $p)) $kept = true;
    if (!$kept) $out[] = $name;
}
sort($out);
fwrite(STDERR, sprintf("справочник %d, к удалению %d\n", count($dict), count($out)));
echo implode("\n", $out), $out ? "\n" : '';
