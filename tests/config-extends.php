<?php
// Наследование конфигов компонентов (этап 4): <configuration extends="Базовый.component.xml"> — состояния базового,
// с заменой одноимённых, добавлением новых в конец и удалением <state name="…" remove="1"/>; цепочка из нескольких
// звеньев; цикл — ошибка разработчика. Порядок состояний — как у базового (от него зависят веса адресов).
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
foreach (['DocumentController', 'ComponentManager', 'Utils'] as $g) require_once ROOT . "/core/modules/share/gears/$g.php";
use Energine\share\gears\ComponentConfig;

$dir = sys_get_temp_dir() . '/claude-cfg-' . getmypid();
mkdir($dir);
register_shutdown_function(fn() => exec('rm -rf ' . escapeshellarg($dir)));
$put = fn($n, $x) => file_put_contents("$dir/$n", '<?xml version="1.0" encoding="UTF-8"?>' . $x);
$put('A.xml', '<configuration><state name="main"><a/></state><state name="edit"><b/></state><state name="save"><c/></state></configuration>');
$put('B.xml', '<configuration extends="A.xml"><state name="edit"><b2/></state><state name="extra"><d/></state><state name="save" remove="1"/></configuration>');
$put('C.xml', '<configuration extends="B.xml"><state name="main"><a3/></state></configuration>');
$put('L1.xml', '<configuration extends="L2.xml"/>');
$put('L2.xml', '<configuration extends="L1.xml"/>');
$resolve = fn($name) => is_file("$dir/$name") ? "$dir/$name" : false;
$states = fn($x) => array_map(fn($s) => (string)$s['name'] . ':' . $s->children()[0]?->getName(), iterator_to_array($x->state, false));

$e = null;
try {
    $b = ComponentConfig::loadXml("$dir/B.xml", $resolve);
    check('наследование: замена на месте, новое — в конец, remove убирает', $states($b) === ['main:a', 'edit:b2', 'extra:d'], implode(' ', $states($b)));
    $c = ComponentConfig::loadXml("$dir/C.xml", $resolve);
    check('цепочка из двух звеньев', $states($c) === ['main:a3', 'edit:b2', 'extra:d'], implode(' ', $states($c)));
    check('атрибута extends в итоге нет', !isset($c['extends']));
} catch (\Throwable $x) { $e = $x; }
check('наследование работает без исключений', $e === null, $e ? $e->getMessage() : '');
$e = null;
try { ComponentConfig::loadXml("$dir/L1.xml", $resolve); } catch (\Throwable $x) { $e = $x; }
check('цикл extends — ERR_DEV_CONFIG_EXTENDS_LOOP', $e && str_contains($e->getMessage(), 'ERR_DEV_CONFIG_EXTENDS_LOOP'), $e ? $e->getMessage() : 'исключения нет');

// поиск базового (ComponentConfig::baseResolver): рядом с файлом (не он сам), затем обычный поиск, затем модули ядра;
// конфиг сайта с тем же именем, что у ядра, наследует ядро, а не себя
mkdir("$dir/site"); mkdir("$dir/core"); mkdir("$dir/core2");
file_put_contents("$dir/core/Foo.xml", '<?xml version="1.0"?><configuration><state name="main"><a/></state></configuration>');
file_put_contents("$dir/site/Foo.xml", '<?xml version="1.0"?><configuration extends="Foo.xml"><state name="more"><m/></state></configuration>');
file_put_contents("$dir/core2/Other.xml", '<?xml version="1.0"?><configuration><state name="main"><o/></state></configuration>');
file_put_contents("$dir/site/Bar.xml", '<?xml version="1.0"?><configuration extends="Other.xml"/>');
// обычный поиск (как getConfigPath): сначала сайт, затем ядро модуля компонента (core)
$lookup = fn($name) => is_file("$dir/site/$name") ? "$dir/site/$name" : (is_file("$dir/core/$name") ? "$dir/core/$name" : false);
$e = null;
try {
    $r = ComponentConfig::loadXml("$dir/site/Foo.xml", ComponentConfig::baseResolver($lookup, ["$dir/core", "$dir/core2"]));
    check('конфиг сайта с именем ядра наследует ядро, а не себя', $states($r) === ['main:a', 'more:m'], implode(' ', $states($r)));
    $r = ComponentConfig::loadXml("$dir/site/Bar.xml", ComponentConfig::baseResolver($lookup, ["$dir/core", "$dir/core2"]));
    check('базовый из другого модуля ядра находится', $states($r) === ['main:o'], implode(' ', $states($r)));
} catch (\Throwable $x) { $e = $x; }
check('поиск базового без исключений', $e === null, $e ? $e->getMessage() : '');

// переведённые на extends конфиги ядра: объединённый результат совпадает с прежним полным файлом (ревизия 343ec644):
// те же состояния в том же порядке и с тем же содержимым (C14N); файл — не больше 3/4 прежнего
$coreResolve = fn($name) => is_file($f = ROOT . '/core/modules/share/config/' . $name) ? $f : false;
$canon = function (\SimpleXMLElement $x) {
    $out = [];
    foreach ($x->state as $st) { $d = dom_import_simplexml($st); $out[] = (string)$st['name'] . '=' . preg_replace('~>\s+<~', '><', $d->C14N()); }
    return $out;
};
foreach (['FileRepositorySelect', 'SiteDivisionEditor'] as $n) {
    $file = ROOT . "/core/modules/share/config/$n.component.xml";
    $old = shell_exec('cd ' . escapeshellarg(ROOT) . " && git show 343ec644:core/modules/share/config/$n.component.xml");
    $merged = ComponentConfig::loadXml($file, $coreResolve);
    $orig = simplexml_load_string($old);
    check("$n: extends, результат = прежний полный конфиг (состояния, порядок, содержимое)", str_contains(file_get_contents($file), 'extends=')
        && $canon($merged) === $canon($orig), implode(' ', array_map(fn($x) => strtok($x, '='), $canon($merged))));
    check("$n: файл заметно короче прежнего (не больше 3/4)", strlen(file_get_contents($file)) * 4 <= strlen($old) * 3, strlen(file_get_contents($file)) . ' / ' . strlen($old));
}
done('config-extends');
