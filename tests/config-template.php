<?php
// Шаблон конфига площадки без лишнего (этап «чистка»): нет ключей project, site.useTimer, site.asXML, site.vars,
// размеры превью по умолчанию не заданы; код эти ключи не читает (старый конфиг площадки с ними продолжает работать).
require __DIR__ . '/testlib.php';
$cfg = require ROOT . '/configs/system.config.default.php';
check('в шаблоне нет project, site.useTimer, site.asXML, site.vars', !isset($cfg['project']) && !array_intersect(['useTimer', 'asXML', 'vars'],
    array_keys($cfg['site'] ?? [])), implode(' ', array_keys($cfg['site'] ?? [])));
check('размеры превью по умолчанию не заданы', empty($cfg['thumbnails']), json_encode($cfg['thumbnails'] ?? null));
$hits = [];
foreach (['core', 'site', 'setup', 'htdocs'] as $d) {
    exec('grep -rnE ' . escapeshellarg("site\\.(useTimer|asXML|vars)") . ' --include=*.php ' . escapeshellarg(ROOT . "/$d"), $hits);
}
check('код не читает site.useTimer, site.asXML, site.vars', !$hits, implode(' | ', $hits));
done('config-template');
