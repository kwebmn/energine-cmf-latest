<?php
// Периметр (надёжность, этап 1):
//  1. ошибки PHP не показывают посетителю сервер: index.php и DocumentController ловят \Throwable; display_errors
//     включается только при отладке (ini.func.php); у timthumb выключены внешние источники и вывод ошибок;
//  2. ?struct (XML структуры страницы) — только при отладке: гость получает обычную страницу;
//  3. данные адреса и запроса не попадают в SQL строкой: заполнители адресов по типам ([int] — только число),
//     поле и направление сортировки грида — только известные, иначе 404 или обычный ответ, без текста ошибки SQL.
require __DIR__ . '/testlib.php';

$leak = '/SQLSTATE|syntax error|PDOException|You have an error in your SQL|\/var\/www|\/private\/energine|Stack trace/i';
$src = fn($p) => file_get_contents(ROOT . '/' . $p);

// 1. статически
check('index.php ловит \Throwable', preg_match('~catch\s*\(\s*\\\\?Throwable~', $src('htdocs/index.php')));
check('DocumentController::run ловит \Throwable', preg_match('~catch\s*\(\s*\\\\?Throwable~', $src('core/modules/share/gears/DocumentController.php')));
check('ini.func.php: display_errors только при отладке', !preg_match("~ini_set\('display_errors',\s*1\)~", $src('core/modules/share/gears/ini.func.php'))
    && preg_match("~display_errors~", $src('core/modules/share/gears/ini.func.php')));
$tt = $src('htdocs/resizer/timthumb-config.php');
check('timthumb: внешние источники и вывод ошибок выключены', preg_match("~ALLOW_EXTERNAL',\s*false~i", $tt) && preg_match("~DISPLAY_ERROR_MESSAGES',\s*false~i", $tt));
check('копии в web/ совпадают с репозиторием (index.php, resizer)', file_get_contents(WEB . '/index.php') === $src('htdocs/index.php')
    && file_get_contents(WEB . '/resizer/timthumb-config.php') === $tt);

// 2. ?struct — как ?debug: только при включённой отладке (на рабочем сайте она выключена). Статически — в коде есть
//    условие site.debug; на площадке с выключенной отладкой гость получает обычную страницу
check('?struct выдаётся только при site.debug (DocumentController::getViewMode)',
    preg_match("~TRANSFORM_STRUCTURE_XML\]\)\s*&&\s*\\\$this->getConfigValue\('site\.debug'\)~", $src('core/modules/share/gears/DocumentController.php')));
logout();
[$cd, $bd] = http('/?debug');
if (!str_starts_with(ltrim($bd), '<?xml')) {
    [$c, $b] = http('/?struct');
    check('отладка выключена: гость /?struct — обычная HTML-страница', $c == 200 && !str_contains($b, '<structure>'), "HTTP $c " . substr($b, 0, 80));
} else {
    echo "SKIP отладка на площадке включена: ?struct и ?debug доступны, как задумано для стенда\n";
}

// 3. администратор: подставные значения в адресах
login();
$cases = [
    'сортировка: поле со скобкой' => ['/admin/users/single/userEditor/get-data/u_name)-asc/', [200, 404]],
    'сортировка: неизвестное направление' => ['/admin/users/single/userEditor/get-data/u_name-evil/', [200, 404]],
    'сортировка: неизвестное поле' => ['/admin/users/single/userEditor/get-data/no_such_field-asc/', [200, 404]],
    'файл: удаление с нечисловым номером' => ['/admin/users/single/adminPanel/file-library/1%20OR%201%3D1/delete/', [404]],
    'файл: копирование с нечисловым номером' => ['/admin/users/single/adminPanel/file-library/1%20OR%201%3D1/copy/', [404]],
    'страница: нечисловой номер в правке' => ['/admin/structure/single/divEditor/1%20OR%201%3D1/edit/', [404]],
    'листалка: нечисловой номер страницы' => ['/admin/translations/single/transEditor/get-data/page-x/', [404]],
];
foreach ($cases as $label => [$url, $codes]) {
    [$c, $j, $raw] = json($url, '');
    check("$label — " . implode('/', $codes) . ', без текста ошибки SQL', in_array($c, $codes) && !preg_match($leak, $raw), "HTTP $c " . substr($raw, 0, 160));
}
// свойства раздела: languageID не число
$page = (int)scalar("SELECT q.smap_id FROM share_sitemap q JOIN share_sitemap i ON i.smap_id = q.smap_pid WHERE q.smap_segment = 'quick-start' AND i.smap_segment = 'info'");
[$c, $j, $raw] = json('/admin/structure/single/divEditor/get-node-data/', http_build_query(['id' => $page, 'languageID' => '1 OR 1=1']));
// подставное значение приводится к числу (1) — обычный ответ для языка 1 или отказ; главное — без текста ошибки SQL
check('свойства раздела с подставным languageID — без текста ошибки SQL', is_array($j) && !preg_match($leak, $raw) && (empty($j['result']) || !empty($j['data'])), "HTTP $c " . substr($raw, 0, 160));
// обычная сортировка по-прежнему работает
[$c, $j, $raw] = json('/admin/users/single/userEditor/get-data/u_name-asc/', '');
check('обычная сортировка грида работает', $c == 200 && is_array($j) && !empty($j['data']), "HTTP $c " . substr($raw, 0, 120));
logout();
done('perimeter');
