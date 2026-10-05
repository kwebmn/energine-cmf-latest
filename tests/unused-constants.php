<?php
// В справочнике переводов нет констант, которые ничто не использует (tests/tools/unused-constants.php).
require __DIR__ . '/testlib.php';
exec('php8.5 ' . escapeshellarg(__DIR__ . '/tools/unused-constants.php'), $out, $rc);
$last = end($out);
check('неиспользуемых констант перевода нет', $rc === 0 && preg_match('~unused constants: 0 ~', $last), $last . ' — ' . implode(' ', array_slice($out, 0, 10)));
done('unused-constants');
