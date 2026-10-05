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
done('config-extends');
