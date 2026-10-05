<?php
// Вызов несуществующего метода у класса с DBWorker (компоненты, построители, сохранение …) — исключение
// BadMethodCallException, а не тихий false: опечатка в имени метода видна сразу. translate() и dateToString()
// по-прежнему доступны как методы.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
$o = new class { use \Energine\share\gears\DBWorker; };
$e = null;
try { $o->noSuchMethodHere(1); } catch (\Throwable $x) { $e = $x; }
check('неизвестный метод — BadMethodCallException с именем метода', $e instanceof \BadMethodCallException && str_contains($e->getMessage(), 'noSuchMethodHere'),
    $e ? get_class($e) . ': ' . $e->getMessage() : 'исключения нет');
$src = file_get_contents(ROOT . '/core/modules/share/gears/DBWorker.php');
check('translate и dateToString по-прежнему вызываются через DBWorker', str_contains($src, "'translate'") && str_contains($src, "'dateToString'"));
done('dbworker-call');
