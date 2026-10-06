<?php
// JSONBuilder (данные гридов) на PHP 8.5: select-поле без значения (внешний ключ NULL — upl_pid хранилища в
// файловом репозитории, smap_pid корня дерева) собирается без предупреждения «Using null as an array offset»
// в журнале PHP; пустое значение, как и прежде, отдаётся пустой строкой, известное — подписью.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
require_once ROOT . '/core/modules/share/gears/Registry.php'; // функция E()
require_once ROOT . '/core/modules/share/gears/Utils.php';    // функция translate() — её зовёт конструктор FieldDescription
require_once ROOT . '/core/modules/share/gears/DocumentController.php'; // интерфейсы ITransformer, IBlock, IBuilder живут в файлах
require_once ROOT . '/core/modules/share/gears/ComponentManager.php';   // классов — автозагрузка их не находит
require_once ROOT . '/core/modules/share/components/Component.php';
\Energine\share\gears\Primitive::setConfig(include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php'));
defined('HTDOCS_DIR') || define('HTDOCS_DIR', WEB);

use Energine\share\gears\Data;
use Energine\share\gears\DataDescription;
use Energine\share\gears\FieldDescription;
use Energine\share\gears\JSONBuilder;

// любое предупреждение PHP при сборке — исключение (в т.ч. E_DEPRECATED, которое иначе ушло бы в журнал)
set_error_handler(function ($no, $str, $file, $line) { throw new ErrorException($str, 0, $no, $file, $line); });

$dd = new DataDescription();
$fd = new FieldDescription('upl_pid');
$fd->setType(FieldDescription::FIELD_TYPE_SELECT);
$fd->loadAvailableValues([['id' => 1, 'name' => 'Хранилище']], 'id', 'name');
$dd->addFieldDescription($fd);
$d = new Data();
$d->load([['upl_pid' => null], ['upl_pid' => 1]]);
$b = new JSONBuilder();
$b->setDataDescription($dd);
$b->setData($d);
$e = null;
try { $b->build(); } catch (Throwable $x) { $e = $x; }
restore_error_handler();
check('сборка JSON с NULL в select-поле — без предупреждений PHP', !$e, $e ? $e->getMessage() . ' @ ' . basename($e->getFile()) . ':' . $e->getLine() : '');
$json = $e ? [] : json_decode($b->getResult(), true);
check('NULL отдаётся пустой строкой, известное значение — подписью',
    ($json['data'][0]['upl_pid'] ?? 'x') === '' && ($json['data'][1]['upl_pid'] ?? null) === 'Хранилище',
    json_encode($json['data'] ?? null, JSON_UNESCAPED_UNICODE));
done('json-builder');
