<?php
// Запросы к базе на страницу (надёжность, этап 4): при отладке XML страницы (?debug) несёт document/@queries —
// число запросов и список <queries><query> — и бюджет не растёт незаметно: гость — главная, администратор — грид
// пользователей. Бюджеты — верхняя граница после этапа 4 (переводы и схема одним запросом); на площадке без
// отладки набор пропускается (атрибут только при site.debug).
require __DIR__ . '/testlib.php';

$BUDGET = ['guest /' => 35, 'admin /admin/users/' => 70];
function queriesOf(string $url): ?array {
    [$c, $b] = http($url . (str_contains($url, '?') ? '&' : '?') . 'debug');
    if ($c != 200 || !str_starts_with(ltrim($b), '<?xml')) {
        return null;
    }
    $x = @simplexml_load_string($b);
    if (!$x || !isset($x['queries'])) {
        return ['count' => -1, 'list' => []];
    }
    return ['count' => (int)$x['queries'], 'list' => array_map('strval', iterator_to_array($x->queries->query ?? new ArrayIterator([]), false))];
}
logout();
$home = queriesOf('/');
if ($home === null) {
    echo "SKIP отладка выключена: ?debug не отдаёт XML, число запросов не видно\n";
    done('queries');
}
check('гость, главная: XML страницы несёт document/@queries и список запросов', $home['count'] > 0 && count($home['list']) === $home['count'],
    json_encode(['count' => $home['count'], 'list' => count($home['list'])]));
check('гость, главная: не больше ' . $BUDGET['guest /'] . ' запросов (сейчас ' . $home['count'] . ')', $home['count'] > 0 && $home['count'] <= $BUDGET['guest /'],
    implode(' | ', array_slice($home['list'], 0, 8)));
login();
$users = queriesOf('/admin/users/');
check('администратор, пользователи: не больше ' . $BUDGET['admin /admin/users/'] . ' запросов (сейчас ' . ($users['count'] ?? -1) . ')',
    $users && $users['count'] > 0 && $users['count'] <= $BUDGET['admin /admin/users/'], implode(' | ', array_slice($users['list'] ?? [], 0, 8)));
// число запросов не зависит от повтора (нет утечки состояния между запросами)
$again = queriesOf('/admin/users/');
check('повторный запрос — то же число запросов', $again && $users && abs($again['count'] - $users['count']) <= 1, ($again['count'] ?? -1) . ' vs ' . ($users['count'] ?? -1));
logout();
echo "queries: guest / = {$home['count']}, admin /admin/users/ = " . ($users['count'] ?? -1) . "\n";
done('queries');
