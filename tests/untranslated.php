<?php
// Все константы, которые использует код и конфиги, переведены: setup untranslated сообщает «все … переведены».
require __DIR__ . '/testlib.php';
$owner = posix_getpwuid(fileowner(WEB))['name'];
$out = (string)shell_exec('cd ' . escapeshellarg(WEB) . ' && runuser -u ' . escapeshellarg($owner) . ' -- php8.5 index.php setup untranslated 2>&1');
$missing = array_values(array_filter(explode("\n", $out), fn($l) => preg_match('~^[A-Z][A-Z0-9_-]+: ~', $l)));
check('setup untranslated: непереведённых констант нет', str_contains($out, 'все языковые константы переведены') && !$missing,
    implode(' | ', array_map(fn($l) => strtok($l, ':'), $missing)) ?: substr($out, -300));
done('untranslated');
