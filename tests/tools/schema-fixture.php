<?php
// Снимок описания схемы, которое отдаёт DBStructureInfo::getTableMeta() по всем таблицам базы площадки (тип, длина,
// nullable, default, ключ, индекс, options, tableName). Этап 4 переписывает чтение схемы с SHOW CREATE TABLE на
// information_schema — снимок доказывает, что массив тот же.
//   php8.5 tests/tools/schema-fixture.php capture   — tests/fixtures/schema-info.json (нынешним кодом)
//   php8.5 tests/tools/schema-fixture.php compare   — отличия нынешнего кода от снимка; выход 1, если есть
// Снимок пересобирается при законном изменении схемы (переход sql/cut/stage*.sql) — вместе с ним в коммит.
require dirname(__DIR__) . '/testlib.php';
require ROOT . '/vendor/autoload.php';
require_once ROOT . '/core/modules/share/gears/Registry.php'; // функция E() — не класс, автозагрузка её не найдёт

use Energine\share\gears\Db;
use Energine\share\gears\DBStructureInfo;
use Energine\share\gears\Primitive;

[, $cmd] = $argv + [null, null];
$fixture = dirname(__DIR__) . '/fixtures/schema-info.json';
if (!in_array($cmd, ['capture', 'compare'], true)) { fwrite(STDERR, "capture | compare\n"); exit(2); }
// ядро для DBStructureInfo: конфиг площадки (E()->getCache() читает site.cache/site.debug), константы путей
Primitive::setConfig(include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php'));
defined('HTDOCS_DIR') || define('HTDOCS_DIR', WEB);
$info = new DBStructureInfo(new Db(pdo()));
$current = [];
foreach (q('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() ORDER BY TABLE_NAME')->fetchAll(PDO::FETCH_COLUMN) as $t) {
    $current[$t] = $info->getTableMeta($t);
}
$current['__tableExists'] = ['share_sitemap' => $info->tableExists('share_sitemap'), 'share_sitemap_translation' => $info->tableExists('share_sitemap_translation'),
    'no_such_table_claude' => $info->tableExists('no_such_table_claude'), 'share_textblocks_translation' => $info->tableExists('share_textblocks_translation')];
if ($cmd === 'capture') {
    @mkdir(dirname($fixture), 0755, true);
    file_put_contents($fixture, json_encode($current, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n");
    echo 'снято: ', count($current) - 1, " таблиц → $fixture\n";
    exit(0);
}
$expected = json_decode((string)@file_get_contents($fixture), true);
if (!is_array($expected)) { echo "FAIL нет снимка $fixture — php8.5 tests/tools/schema-fixture.php capture\n"; exit(1); }
$diff = 0;
foreach (array_unique(array_merge(array_keys($expected), array_keys($current))) as $t) {
    $a = $expected[$t] ?? null;
    $b = $current[$t] ?? null;
    if ($a === $b) continue;
    $diff++;
    echo "FAIL $t:\n";
    foreach (array_unique(array_merge(array_keys((array)$a), array_keys((array)$b))) as $col) {
        if (($a[$col] ?? null) !== ($b[$col] ?? null)) {
            echo "  $col: было ", json_encode($a[$col] ?? null, JSON_UNESCAPED_UNICODE), " стало ", json_encode($b[$col] ?? null, JSON_UNESCAPED_UNICODE), "\n";
        }
    }
}
echo $diff ? "== schema-info: таблиц с отличиями $diff\n" : "OK   схема по information_schema совпадает со снимком (" . (count($expected) - 1) . " таблиц)\n== schema-info: таблиц с отличиями 0\n";
exit($diff ? 1 : 0);
