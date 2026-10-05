<?php
// Константы перевода, которые ничто не использует (этап «чистка»). Используемой считается константа:
//  - чьё имя встречается литералом в коде, шаблонах, конфигах и скриптах (core, site, setup, htdocs);
//  - собранная в коде из частей: FIELD_/TXT_ + имя колонки, поля, компонента или строкового значения из кода или
//    базы (права TXT_<right_const>, TXT_<right_name>), CONTENT_/LAYOUT_ + имя файла шаблона, CLASS_* (журнал),
//    HELP_<класс>_<состояние> (подсказки админки), ERR_WRONG_*, TXT_WEEKDAY_*, TXT_MONTH_*, *_ENUM_* (значения перечней), TXT_SECTION_SAMPLE_*;
// с запасом: при сомнении константа считается используемой.
//   php8.5 tests/tools/unused-constants.php          — список неиспользуемых (по строке), итог в конце
//   php8.5 tests/tools/unused-constants.php --sql    — то же как SQL-список для DELETE … IN (…)
require dirname(__DIR__) . '/testlib.php';

$used = [];
$words = [];
$it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(ROOT, FilesystemIterator::SKIP_DOTS));
foreach ($it as $f) {
    $p = $f->getPathname();
    if (!preg_match('~^' . preg_quote(ROOT, '~') . '/(core|site|setup|htdocs)/~', $p) || str_contains($p, '/jodit/')
        || !preg_match('~\.(php|xslt|xml|js|inc)$~', $p)) continue;
    $s = file_get_contents($p);
    preg_match_all('~\b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b~', $s, $m);
    foreach ($m[0] as $c) $used[$c] = 1;
    // имена полей, компонентов, файлов: строки и атрибуты из строчных букв, цифр и _
    preg_match_all('~["\']([a-zA-Z][a-zA-Z0-9_]{1,60})["\']~', $s, $m);
    foreach ($m[1] as $w) $words[strtoupper($w)] = 1;
}
foreach (q("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()")->fetchAll(PDO::FETCH_COLUMN) as $c) {
    $words[strtoupper($c)] = 1;
}
// строковые значения базы, похожие на имена (права, системные имена шаблонов писем …), кроме самих переводов и текстов
foreach (q("SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE()
    AND DATA_TYPE IN ('char','varchar') AND TABLE_NAME NOT IN ('share_lang_tags','share_lang_tags_translation')")->fetchAll() as $c) {
    foreach (q("SELECT DISTINCT `{$c['COLUMN_NAME']}` FROM `{$c['TABLE_NAME']}` LIMIT 500")->fetchAll(PDO::FETCH_COLUMN) as $v) {
        if (is_string($v) && preg_match('~^[A-Za-z][A-Za-z0-9_]{1,60}$~', $v)) $words[strtoupper($v)] = 1;
    }
}
foreach (array_merge(glob(ROOT . '/core/modules/*/templates/*/*.xml'), glob(ROOT . '/site/modules/*/templates/*/*.xml')) as $t) {
    if (preg_match('~/([a-z0-9_]+)\.(content|layout)\.xml$~', $t, $m)) $used[strtoupper($m[2] . '_' . $m[1])] = 1;
}
$prefixes = ['CLASS_', 'ERR_WRONG_', 'TXT_WEEKDAY_', 'TXT_MONTH_', 'TXT_SECTION_SAMPLE_', 'HELP_'];
$unused = [];
foreach (q('SELECT ltag_name FROM share_lang_tags ORDER BY ltag_name')->fetchAll(PDO::FETCH_COLUMN) as $c) {
    if (isset($used[$c])) continue;
    foreach ($prefixes as $p) if (str_starts_with($c, $p)) continue 2;
    // FIELD_<колонка>_ENUM_<значение> — подписи значений поля-перечня (FieldDescription)
    if (str_contains($c, '_ENUM_')) continue;
    if (preg_match('~^(FIELD|TXT)_(.+)$~', $c, $m) && isset($words[$m[2]])) continue;
    $unused[] = $c;
}
if (in_array('--sql', $argv)) {
    echo implode(",\n", array_map(fn($c) => "    '$c'", $unused)), "\n";
    exit(0);
}
foreach ($unused as $c) echo "$c\n";
echo "== unused constants: " . count($unused) . " of " . scalar('SELECT COUNT(*) FROM share_lang_tags') . "\n";
