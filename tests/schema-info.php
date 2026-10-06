<?php
// Схема таблиц (надёжность, этап 4): описание колонок, которое отдаёт DBStructureInfo (теперь из information_schema),
// совпадает со снимком tests/fixtures/schema-info.json, снятым прежним разбором SHOW CREATE TABLE. Изменилась схема
// законно (переход sql/cut/stage*.sql) — пересобрать снимок: php8.5 tests/tools/schema-fixture.php capture.
passthru('php8.5 ' . escapeshellarg(__DIR__ . '/tools/schema-fixture.php') . ' compare', $code);
exit($code ? 1 : 0);
