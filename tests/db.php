<?php
// Db (надёжность, этап 4): небольшой типизированный слой над PDO для нового кода — запросы только с параметрами «?»,
// имена таблиц и колонок через quoteName, insert/update/delete, транзакция с откатом при исключении (вложенная —
// одна внешняя), счётчик запросов. QAL наследует Db — прежний API без изменений. Проверяется на живой базе без
// следов: записи делаются внутри транзакции, которая откатывается.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';

use Energine\share\gears\Db;

if (!class_exists(Db::class)) {
    check('класс Energine\share\gears\Db есть', false);
    done('db');
}
$db = new Db(pdo());
$n0 = $db->queryCount();

// 1. чтение с параметрами
$rows = $db->rows('SELECT lang_id, lang_abbr FROM share_languages WHERE lang_id IN (?, ?) ORDER BY lang_id', [1, 2]);
check('rows: строки с параметрами', count($rows) === 2 && $rows[0]['lang_abbr'] === 'ru' && $rows[1]['lang_abbr'] === 'ua', json_encode($rows));
$row = $db->row('SELECT lang_id, lang_abbr FROM share_languages WHERE lang_abbr = ?', ['ua']);
check('row: одна строка или null', is_array($row) && (int)$row['lang_id'] === 2 && $row['lang_abbr'] === 'ua' && $db->row('SELECT 1 FROM share_languages WHERE lang_id = ?', [999]) === null, json_encode($row));
check('scalar: значение или false без строки', (int)$db->scalar('SELECT COUNT(*) FROM share_languages') >= 2
    && $db->scalar('SELECT lang_abbr FROM share_languages WHERE lang_id = ?', [999]) === false);
check('column: список значений', $db->column('SELECT lang_abbr FROM share_languages ORDER BY lang_id') === ['ru', 'ua']);
check('queryCount растёт с каждым запросом', $db->queryCount() === $n0 + 6, $db->queryCount() - $n0);
// журнал (?debug) — текст запроса с «?» и число параметров, без значений: в XML не должны попадать ID сессии и т. п.
$db->logQueries(true);
$db->scalar('SELECT ? AS v', ['claude-secret-7']);
$log = $db->queryLog();
$db->logQueries(false);
check('журнал запросов: текст с «?» и число параметров, значений нет', $log && str_contains((string)end($log), 'SELECT ? AS v')
    && !str_contains(implode("\n", $log), 'claude-secret-7'), (string)end($log) ?: 'журнал пуст');

// 2. имена
check('quoteName: таблица и колонка в обратных кавычках', $db->quoteName('share_languages') === '`share_languages`' && $db->quoteName('db1.t2') === '`db1`.`t2`');
$e = null;
try { $db->quoteName('a b; DROP'); } catch (\Throwable $x) { $e = $x; }
check('quoteName: не идентификатор — исключение', $e instanceof \InvalidArgumentException, $e ? get_class($e) : 'нет исключения');

// 3. запись внутри откатываемой транзакции: insert отдаёт id, update/delete — число строк
$tb = (int)scalar('SELECT MIN(tb_id) FROM share_textblocks');
pdo()->beginTransaction();
try {
    $id = $db->insert('share_textblocks_history', ['tb_id' => $tb, 'lang_id' => 1, 'tbh_content' => '<p>db test</p>']);
    check('insert: id новой строки', $id > 0 && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_id = ?', [$id]) === 1, (string)$id);
    check('update: число изменённых строк', $db->update('share_textblocks_history', ['tbh_content' => '<p>db test 2</p>'], ['tbh_id' => $id]) === 1
        && scalar('SELECT tbh_content FROM share_textblocks_history WHERE tbh_id = ?', [$id]) === '<p>db test 2</p>');
    check('update по условию без совпадений — 0', $db->update('share_textblocks_history', ['tbh_content' => 'x'], ['tbh_id' => $id, 'lang_id' => 999]) === 0);
    check('exec: число строк', $db->exec('UPDATE share_textblocks_history SET tbh_content = ? WHERE tbh_id = ?', ['<p>db test 3</p>', $id]) === 1);
    check('delete: число удалённых строк', $db->delete('share_textblocks_history', ['tbh_id' => $id]) === 1
        && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_id = ?', [$id]) === 0);
    // вложенная транзакция — одна внешняя: внутри неё запись видна, откат внешней уносит всё
    $inner = $db->transaction(fn() => $db->transaction(fn() => $db->insert('share_textblocks_history', ['tb_id' => $tb, 'lang_id' => 1, 'tbh_content' => '<p>nested</p>'])));
    check('transaction: вложенная внутри внешней — результат отдаётся, строка есть', $inner > 0 && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_id = ?', [$inner]) === 1);
} finally {
    pdo()->rollBack();
}
check('откат внешней транзакции убрал всё', (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_content LIKE ?', ['<p>db test%']) === 0
    && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_content = ?', ['<p>nested</p>']) === 0);

// 4. transaction: исключение внутри — откат и то же исключение наружу; без исключения — результат
$e = null;
try {
    $db->transaction(function () use ($db, $tb) {
        $db->insert('share_textblocks_history', ['tb_id' => $tb, 'lang_id' => 1, 'tbh_content' => '<p>will roll back</p>']);
        throw new \RuntimeException('стоп');
    });
} catch (\Throwable $x) { $e = $x; }
check('transaction: исключение — откат, исключение то же', $e instanceof \RuntimeException && $e->getMessage() === 'стоп'
    && (int)scalar('SELECT COUNT(*) FROM share_textblocks_history WHERE tbh_content = ?', ['<p>will roll back</p>']) === 0 && !pdo()->inTransaction(), $e ? get_class($e) : 'нет исключения');
check('transaction: результат функции', $db->transaction(fn() => 42) === 42);

// 5. вложенность общая у transaction() и beginTransaction/commit/rollback (API QAL): транзакция PDO одна — внешняя.
// Отдельное соединение — без внешней транзакции теста.
$db2 = new Db(new PDO("mysql:host={$GLOBALS['E']['DB_HOST']};dbname={$GLOBALS['E']['DB_NAME']};charset=utf8", $GLOBALS['E']['DB_USER'], $GLOBALS['E']['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]));
$pdo2 = $db2->getPDO();
$attempt = function (callable $fn) { try { return $fn(); } catch (\Throwable $x) { return $x; } };
// не $fail: так зовётся счётчик провалов testlib в глобальной области
$why = fn($r) => is_object($r) ? get_class($r) . ': ' . $r->getMessage() : var_export($r, true);
// (а) пара beginTransaction/commit внутри transaction(): не открывает вторую транзакцию и не закрывает внешнюю раньше
$r = $attempt(fn() => $db2->transaction(function (Db $d) use ($pdo2) { $d->beginTransaction(); $d->commit(); return $pdo2->inTransaction(); }));
check('beginTransaction/commit внутри transaction() — внешняя транзакция открыта до конца, потом закрыта', $r === true && !$pdo2->inTransaction(), $why($r));
// (б) transaction() внутри beginTransaction(): вложенная не фиксирует, фиксирует внешний commit
$r = $attempt(function () use ($db2, $pdo2) { $db2->beginTransaction(); $db2->transaction(fn() => 1); $open = $pdo2->inTransaction(); $db2->commit(); return $open && !$pdo2->inTransaction(); });
check('transaction() внутри beginTransaction() — фиксирует внешний commit', $r === true, $why($r));
// (в) исключение во вложенной — откат всей транзакции; внешний commit после этого не падает
$r = $attempt(function () use ($db2, $pdo2) {
    $db2->beginTransaction();
    try { $db2->transaction(function () { throw new \RuntimeException('внутри'); }); } catch (\RuntimeException $x) {}
    $rolledBack = !$pdo2->inTransaction();
    return [$rolledBack, $db2->commit()];
});
check('исключение во вложенной — откат всей транзакции, внешний commit без ошибки', $r === [true, true], $why($r));
// (г) транзакцию закрыли мимо нас (DDL в MySQL фиксирует сам) — commit не падает
$r = $attempt(fn() => $db2->transaction(function () use ($pdo2) { $pdo2->commit(); return 'ok'; }));
check('транзакция закрыта неявно (как DDL) — transaction() не падает на commit', $r === 'ok' && !$pdo2->inTransaction(), $why($r));
// (д) insert в таблицу без автоинкремента — 0 (а не id предыдущей вставки), строка записана; всё откатывается
$r = $attempt(function () use ($db2) {
    $db2->beginTransaction();
    try {
        $tag = $db2->insert('share_lang_tags', ['ltag_name' => 'CLAUDE_DB_TEST_TAG']);
        $zero = $db2->insert('share_lang_tags_translation', ['ltag_id' => $tag, 'lang_id' => 1, 'ltag_value_rtf' => 'проверка']);
        return [$tag > 0, $zero, (int)$db2->scalar('SELECT COUNT(*) FROM share_lang_tags_translation WHERE ltag_id = ? AND lang_id = ?', [$tag, 1])];
    } finally {
        $db2->rollback();
    }
});
check('insert в таблицу без автоинкремента — 0, строка записана', $r === [true, 0, 1], $why($r));
check('rollback убрал тестовую константу, транзакции нет', (int)scalar("SELECT COUNT(*) FROM share_lang_tags WHERE ltag_name = 'CLAUDE_DB_TEST_TAG'") === 0 && !$pdo2->inTransaction());
done('db');
