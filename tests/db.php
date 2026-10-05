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
done('db');
