<?php
// Запросы к базе на страницу (надёжность, этап 4): при отладке XML страницы (?debug) несёт document/@queries —
// число запросов и список <queries><query> — и бюджет не растёт незаметно: гость — главная, администратор — грид
// пользователей. Бюджеты — с запасом над измеренным после этапа 4 (переводы языка одним запросом, схема базы тремя;
// при отладке файловый кэш схемы выключен, потому она в счёте): гость 15, администратор 19. На площадке без отладки
// набор пропускается (атрибут только при site.debug).
require __DIR__ . '/testlib.php';

$BUDGET = ['guest /' => 20, 'admin /admin/users/' => 30];
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
// время блоков (надёжность 6, по образцу ?speed xSight): <timings> — на каждый компонент время запуска и сборки (мс)
// и число запросов к базе; сумма запросов компонентов не больше запросов страницы
[$c, $b] = http('/?debug');
$x = str_starts_with(ltrim($b), '<?xml') ? @simplexml_load_string($b) : null;
$timings = $x && isset($x->timings) ? iterator_to_array($x->timings->timing ?? new ArrayIterator([]), false) : [];
$num = fn($v) => is_numeric((string)$v) && (float)$v >= 0;
$ok = count($timings) >= 3;
$sum = 0;
foreach ($timings as $t) {
    $ok = $ok && (string)$t['name'] !== '' && $num($t['run']) && $num($t['build']) && ctype_digit((string)$t['queries']);
    $sum += (int)$t['queries'];
}
check('?debug: <timings> — у каждого компонента (элемент timing) имя, время запуска и сборки, число запросов', $ok,
    'компонентов: ' . count($timings) . ($timings ? ' | ' . $timings[0]->asXML() : ''));
check('сумма запросов компонентов не больше запросов страницы', $x && $timings && $sum <= (int)$x['queries'], "$sum из " . ($x['queries'] ?? '?'));
$classes = array_map(fn($t) => (string)$t['class'], $timings);
check('в <timings> — сами компоненты (есть текстовый блок), а не контейнеры', (bool)preg_grep('~TextBlock$~', $classes)
    && !preg_grep('~ComponentContainer$~', $classes), implode(', ', array_unique($classes)));
echo "queries: guest / = {$home['count']}, admin /admin/users/ = " . ($users['count'] ?? -1) . "\n";
done('queries');
