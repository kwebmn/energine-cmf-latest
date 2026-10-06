<?php
// Реестр без магии (надёжность, этап 4): у Registry нет __get/__set/__isset/__unset и @property-докблоков, объекты
// ядра берутся типизированными методами — getUtils(), getUserGroup(), getFileRepoInfo(), getErrorDocument(),
// getPageStructureDocument() (к прежним getDB(), getLanguage(), getResponse() …): IDE и PHPStan видят типы, опечатка
// в имени — ошибка, а не новый пустой объект в реестре. Статически: в core, site, setup и tests не осталось обращений
// вида E()->Имя (htdocs — исходники web/index.php и web/auth.php).
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
require_once ROOT . '/core/modules/share/gears/Registry.php'; // функция E()
\Energine\share\gears\Primitive::setConfig(include (getenv('ENERGINE_CONFIG') ?: WEB . '/system.config.php'));
defined('HTDOCS_DIR') || define('HTDOCS_DIR', WEB);

use Energine\share\gears\Registry;
use Energine\share\gears\Utils;

$r = new ReflectionClass(Registry::class);
foreach (['__get', '__set', '__isset', '__unset'] as $m) {
    check("у Registry нет $m()", !$r->hasMethod($m));
}
check('у Registry нет @property-докблоков', !preg_match('~@property~', (string)$r->getDocComment()));
$getters = [
    'getUtils' => 'Energine\share\gears\Utils',
    'getUserGroup' => 'Energine\share\gears\UserGroup',
    'getFileRepoInfo' => 'Energine\share\gears\FileRepoInfo',
    'getErrorDocument' => 'Energine\share\gears\ErrorDocument',
    'getPageStructureDocument' => 'Energine\share\gears\PageStructureDocument',
];
foreach ($getters as $m => $class) {
    $type = $r->hasMethod($m) ? (string)$r->getMethod($m)->getReturnType() : '—';
    check("Registry::$m(): $class", $type === $class, "тип возврата: $type");
}
$utils = $r->hasMethod('getUtils') ? E()->getUtils() : null;
check('E()->getUtils() — тот же экземпляр Utils при повторном вызове', $utils instanceof Utils && $utils === E()->getUtils());

// статически: обращений E()->Имя (магия __get) не осталось — ни в ядре, ни в сайте, ни в setup, ни в тестах
$bad = [];
foreach (['core', 'htdocs', 'site', 'setup', 'tests'] as $dir) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(ROOT . "/$dir", FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        $path = (string)$file;
        if (substr($path, -4) !== '.php' || str_contains($path, '/node_modules/')) continue;
        foreach (explode("\n", (string)file_get_contents($path)) as $i => $line) {
            if (preg_match('~E\(\)->[A-Z]\w*~', $line, $m)) {
                $bad[] = substr($path, strlen(ROOT) + 1) . ':' . ($i + 1) . ' ' . $m[0];
            }
        }
    }
}
check('обращений E()->Имя не осталось (core, htdocs, site, setup, tests)', !$bad,
    count($bad) . ': ' . implode(' | ', array_slice($bad, 0, 6)) . (count($bad) > 6 ? ' …' : ''));
done('registry');
