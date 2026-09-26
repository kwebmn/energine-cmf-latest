<?php
// Отпечаток базы площадки по таблицам: строки в порядке сортировки, md5 по всем колонкам,
// кроме времени импорта и значений, которые меняются от прогона к прогону.
// Сравнение установки с нуля и переведённой базы:
//   php8.5 tests/tools/fingerprint.php > before.txt; … ; php8.5 tests/tools/fingerprint.php > after.txt; diff before.txt after.txt
$E = require dirname(__DIR__) . '/env.php';
$p = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
// журнал и сессии живут своей жизнью
$skipTables = ['share_session', 'share_action_log'];
// даты демо-контента считаются от момента импорта; пароль администратора случайный;
// телефон нормализуется при первом сохранении формы пользователя (smoke-roundtrip)
$skipCols = ['feed_date', 'news_date', 'vote_date', 'smap_last_mod', 'upl_publication_date', 'u_password', 'u_phone'];
$tables = $p->query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' ORDER BY 1")->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $t) {
    if (in_array($t, $skipTables)) continue;
    $st = $p->prepare('SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION');
    $st->execute([$t]);
    $use = array_values(array_diff($st->fetchAll(PDO::FETCH_COLUMN), $skipCols));
    $rows = $p->query('SELECT ' . implode(', ', array_map(fn($c) => "`$c`", $use)) . " FROM `$t`")->fetchAll(PDO::FETCH_NUM);
    $lines = array_map(fn($r) => json_encode($r, JSON_UNESCAPED_UNICODE), $rows);
    sort($lines);
    printf("%s %d %s\n", $t, count($lines), md5(implode("\n", $lines)));
}
