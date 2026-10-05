<?php
// Константы площадки для PHPStan (phpstan.neon → bootstrapFiles): на сайте их задаёт htdocs/bootstrap.php из конфига,
// анализатору достаточно типов. vendor/autoload.php сюда подключать нельзя: интерфейсы объявлены в файлах классов,
// и автозагрузка даёт «Cannot redeclare interface».
define('HTDOCS_DIR', dirname(__DIR__, 2) . '/htdocs');
define('ROOT_DIR', dirname(__DIR__, 2));
define('CORE_DIR', ROOT_DIR . '/core');
define('SITE_DIR', ROOT_DIR . '/site');
define('CORE_REL_DIR', '../private/energine/core');
define('SITE_REL_DIR', '../private/energine/site');
define('MODULES', 'modules');
define('DEBUG', false);
define('CHARSET', 'UTF-8');
