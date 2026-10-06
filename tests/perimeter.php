<?php
// Периметр (надёжность, этап 1):
//  1. ошибки PHP не показывают посетителю сервер: index.php и DocumentController ловят \Throwable; display_errors
//     включается только при отладке (ini.func.php); ресайзер — свой (ImageResizer, этап 5): ни timthumb, ни его конфига;
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
$entry = $src('htdocs/resizer/timthumb.php');
check('ресайзер — свой (ImageResizer): ни кода timthumb, ни его конфига (в репозитории и в web/)', str_contains($entry, 'ImageResizer')
    && !preg_match('~class\s+timthumb|TimThumb by|ALLOW_EXTERNAL~i', $entry) && !file_exists(ROOT . '/htdocs/resizer/timthumb-config.php')
    && !file_exists(WEB . '/resizer/timthumb-config.php'));
$ed = $src('core/modules/share/gears/ErrorDocument.php');
check('ErrorDocument: вне отладки предупреждения PHP (SystemException ERR_DEVELOPER) скрыты, как и прочие ошибки',
    preg_match("~site\\.debug'\\)\\s*&&[^{]*ERR_DEVELOPER~s", $ed));
check('DocumentController: ошибка PHP на странице — ответ 500, а не 200', preg_match('~setStatus\\(500\\)~', $src('core/modules/share/gears/DocumentController.php')));
check('копии в web/ совпадают с репозиторием (index.php, resizer)', file_get_contents(WEB . '/index.php') === $src('htdocs/index.php')
    && file_get_contents(WEB . '/resizer/timthumb.php') === $src('htdocs/resizer/timthumb.php'));

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
    'листалка: список номеров страниц' => ['/admin/translations/single/transEditor/get-data/page-1,2/', [404]],
    'перемещение страницы: список номеров' => ['/admin/structure/single/divEditor/1,2/up/', [404]],
];
foreach ($cases as $label => [$url, $codes]) {
    [$c, $j, $raw] = json($url, '');
    check("$label — " . implode('/', $codes) . ', без текста ошибки SQL', in_array($c, $codes) && !preg_match($leak, $raw), "HTTP $c " . substr($raw, 0, 160));
}
// свойства раздела: languageID не число
$page = (int)scalar("SELECT q.smap_id FROM share_sitemap q JOIN share_sitemap i ON i.smap_id = q.smap_pid WHERE q.smap_segment = 'quick-start' AND i.smap_segment = 'info'");
[$c, $j, $raw] = json('/admin/structure/single/divEditor/get-node-data/', http_build_query(['id' => $page, 'languageID' => '1 OR 1=1']));
// подставное значение приводится к числу (1) — обычный ответ для языка 1 или отказ; главное — без текста ошибки SQL
$name1 = scalar('SELECT smap_name FROM share_sitemap_translation WHERE smap_id = ? AND lang_id = 1', [$page]);
check('свойства раздела с подставным languageID — число 1: данные языка 1, без текста ошибки SQL', is_array($j) && !preg_match($leak, $raw)
    && ($j['data']['smap_name'] ?? null) === $name1, "HTTP $c " . substr($raw, 0, 160));
// обычная сортировка по-прежнему работает
[$c, $j, $raw] = json('/admin/users/single/userEditor/get-data/u_name-asc/', '');
check('обычная сортировка грида работает', $c == 200 && is_array($j) && !empty($j['data']), "HTTP $c " . substr($raw, 0, 120));
logout();
// 4. окна редактора, встроенные в компоненты (дерево разделов, библиотека файлов, менеджер картинок), — только
//    редактору: у гостя через публичную форму (регистрация) ни карты сайта, ни списка пользователей, ни файлов
logout();
foreach (['page-tree/list/' => 'divtree|gridContainer', 'page-tree/get-data/' => '"smap_id"|smap_segment', 'page-tree/user/get-data/' => 'u_name|u_fullname',
          'file-library/' => 'gridContainer|upl_path', 'imagemanager/' => 'upl_width|image_manager|imageManager'] as $tail => $marker) {
    [$c, $b] = http('/register/single/regForm/' . $tail);
    check("гость: /register/single/regForm/$tail — без данных ($c)", in_array($c, [403, 404]) || ($c == 200 && !preg_match("~$marker~", $b)),
        "HTTP $c " . substr(preg_replace('/\s+/', ' ', strip_tags($b)), 0, 120));
}
login();
[$c, $b] = http('/info/quick-start/single/textBlock_1/page-tree/list/');
check('администратор: дерево разделов для ссылки открывается', $c == 200 && str_contains($b, 'divtree'), "HTTP $c");
logout();

done('perimeter');
