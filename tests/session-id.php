<?php
// Идентификаторы сессий уникальны и непредсказуемы.
// UserSession::createIdentifier() возвращал sha1(time() + rand(0, 10000)): около 10 тысяч
// вариантов на окно в несколько часов. При частых входах идентификаторы повторялись
// («Duplicate entry … for key 'session_native_id'», вход срывался), а сессию администратора
// можно было подобрать перебором, зная примерное время входа.
require dirname(__DIR__) . '/vendor/autoload.php';

use Energine\share\gears\UserSession;

$fail = 0;
function check($label, $ok, $detail = '') {
    global $fail;
    echo ($ok ? 'OK   ' : 'FAIL '), $label, ($ok || $detail === '' ? '' : ": $detail"), "\n";
    if (!$ok) $fail++;
}

$ids = [];
for ($i = 0; $i < 2000; $i++) $ids[] = UserSession::createIdentifier();

$bad = array_filter($ids, fn($id) => !preg_match('/^[0-9a-f]{40}$/', $id));
check('40 hex characters (fits share_session.session_native_id char(40))', !$bad, implode(', ', array_slice($bad, 0, 3)));

$dups = count($ids) - count(array_unique($ids));
check('2000 identifiers in a row are all different', $dups == 0, "$dups repeats");

// всё, что можно получить из времени создания и rand(0, 10000)
$t = time();
$guess = [];
for ($k = -60; $k <= 10060; $k++) $guess[sha1((string)($t + $k))] = true;
$guessed = count(array_filter($ids, fn($id) => isset($guess[$id])));
check('identifiers cannot be derived from the creation time', $guessed == 0, "$guessed of 2000 guessed");

echo "== session-id failures: $fail\n";
exit($fail ? 1 : 0);
