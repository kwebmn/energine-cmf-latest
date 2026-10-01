<?php
// Отпечаток базы площадки по таблицам: число строк, md5 строк в порядке сортировки по всем колонкам,
// кроме времени импорта и значений, которые меняются от прогона к прогону, и md5 схемы
// (SHOW CREATE TABLE без счётчика AUTO_INCREMENT): колонки, индексы и внешние ключи тоже сверяются.
// Сравнение установки с нуля и переведённой базы:
//   php8.5 tests/tools/fingerprint.php > before.txt; … ; php8.5 tests/tools/fingerprint.php > after.txt; diff before.txt after.txt
// Установка с нуля против базы площадки — tests/tools/fresh-check.sh.
// FP_SOCKET, FP_DB, FP_USER — другая база через сокет (временный экземпляр fresh-check.sh), иначе база площадки
if ($socket = getenv('FP_SOCKET')) {
    $p = new PDO('mysql:unix_socket=' . $socket . ';dbname=' . getenv('FP_DB') . ';charset=utf8', getenv('FP_USER') ?: 'root', '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} else {
    $E = require dirname(__DIR__) . '/env.php';
    $p = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
}
// журнал и сессии живут своей жизнью
$skipTables = ['share_session', 'share_action_log'];
// даты демо-контента считаются от момента импорта; пароль администратора случайный;
// телефон нормализуется при первом сохранении формы пользователя (smoke-roundtrip)
$skipCols = ['vote_date', 'smap_last_mod', 'upl_publication_date', 'u_password', 'u_phone'];
// справочник переводов сверяется по имени константы: суррогатный ltag_id зависит от того, сколько переводов
// успели создать и удалить тесты на этой базе, а кроме переводов на него ничего не ссылается
$byName = [
    'share_lang_tags' => 'SELECT `ltag_name` FROM `share_lang_tags`',
    'share_lang_tags_translation' => 'SELECT t.`ltag_name`, tr.`lang_id`, tr.`ltag_value_rtf` FROM `share_lang_tags_translation` tr'
        . ' JOIN `share_lang_tags` t USING (`ltag_id`)',
    // пользователи — по логину: номер администратора зависит от порядка установки (установщик создаёт его
    // раньше демо-посетителей), кроме групп пользователей на u_id ссылаются только журнал и сессии
    'user_user_groups' => 'SELECT u.`u_name`, ug.`group_id` FROM `user_user_groups` ug JOIN `user_users` u USING (`u_id`)',
];
$skipColsByTable = ['user_users' => ['u_id']];
$tables = $p->query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE' ORDER BY 1")->fetchAll(PDO::FETCH_COLUMN);
foreach ($tables as $t) {
    if (in_array($t, $skipTables)) continue;
    $st = $p->prepare('SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION');
    $st->execute([$t]);
    $use = array_values(array_diff($st->fetchAll(PDO::FETCH_COLUMN), $skipCols, $skipColsByTable[$t] ?? []));
    $rows = $p->query($byName[$t] ?? 'SELECT ' . implode(', ', array_map(fn($c) => "`$c`", $use)) . " FROM `$t`")->fetchAll(PDO::FETCH_NUM);
    $lines = array_map(fn($r) => json_encode($r, JSON_UNESCAPED_UNICODE), $rows);
    sort($lines);
    // FP_ROWS=таблица,таблица — для разбора различий вывести сами строки этих таблиц
    if (in_array($t, explode(',', (string)getenv('FP_ROWS')), true)) {
        foreach ($lines as $l) echo "$t\t$l\n";
        continue;
    }
    $schema = preg_replace('/ AUTO_INCREMENT=\d+/', '', $p->query("SHOW CREATE TABLE `$t`")->fetch(PDO::FETCH_NUM)[1]);
    printf("%s %d %s %s\n", $t, count($lines), md5(implode("\n", $lines)), md5($schema));
}
