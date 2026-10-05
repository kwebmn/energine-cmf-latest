<?php
// У каждого состояния из конфигов компонентов (*.component.xml) есть метод (<состояние>State или <состояние>) у
// класса компонента, который этот конфиг использует; Component::run() не ищет методы через __call — объявленное, но
// не написанное состояние даёт ошибку разработчика ERR_DEV_NO_ACTION, а не страницу ошибки 500.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
// интерфейсы (IBlock, ITransformer …) объявлены в файлах классов, а не в своих: подключаются так же, как в работе
foreach (['DocumentController', 'ComponentManager', 'Utils'] as $g) require_once ROOT . "/core/modules/share/gears/$g.php";

// конфиги, имя которых не совпадает с классом: кто их подключает (param config)
const USED_BY = [
    'FileRepositoryModal' => 'Energine\share\components\FileRepository',   // DivisionEditor::fileLibrary
    'FileRepositorySelect' => 'Energine\share\components\FileRepository',  // DataSet::fileLibrary
    'ChildDivisions' => 'Energine\share\components\PageList',              // admin_childs.content.xml
    'MainMenu' => 'Energine\share\components\PageList',                    // default.layout.xml
    'SiteDivisionEditor' => 'Energine\share\components\DivisionEditor',    // site_div_editor.content.xml
];
$missing = [];
foreach (array_merge(glob(ROOT . '/core/modules/*/config/*.component.xml'), glob(ROOT . '/site/modules/*/config/*.component.xml')) as $f) {
    $name = basename($f, '.component.xml');
    preg_match('~/modules/([a-z]+)/config/~', $f, $m);
    $class = USED_BY[$name] ?? 'Energine\\' . $m[1] . '\\components\\' . $name;
    if (!class_exists($class)) { $missing[] = "$name: нет класса $class"; continue; }
    foreach (simplexml_load_file($f)->xpath('/configuration/state/@name') as $s) {
        $s = (string)$s;
        if (!method_exists($class, $s . 'State') && !method_exists($class, $s)) $missing[] = "$name: $s";
    }
}
// состояния, которые регистрирует код (DataSetConfig, GridConfig) — у DataSet и Grid
foreach (['DataSetConfig' => 'Energine\share\components\DataSet', 'GridConfig' => 'Energine\share\components\Grid'] as $cfg => $class) {
    preg_match_all("~registerState\('(\w+)'~", file_get_contents(ROOT . "/core/modules/share/gears/$cfg.php"), $m);
    foreach ($m[1] as $s) if (!method_exists($class, $s . 'State') && !method_exists($class, $s)) $missing[] = "$cfg: $s";
}
check('у каждого состояния конфигов компонентов есть метод', !$missing, implode('; ', $missing));
$src = file_get_contents(ROOT . '/core/modules/share/components/Component.php');
check('Component::run() не ищет состояние через __call (is_callable)', !preg_match('~is_callable\(\[\$this, \$state~', $src));
done('component-states');
