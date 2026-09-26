<?php require __DIR__ . '/testlib.php'; login();
[$c, $j, $raw] = json('/admin/form-builder/single/formEditor/' . (int)$argv[1] . '/delete/');
check('delete form ' . $argv[1], $c == 200 && !empty($j['result']), $raw); done('delete');
