<?php
// Настройки тестов. Адрес, база и пути берутся из конфига площадки (web/system.config.php),
// учётные данные администратора и почтовый ящик — из tests/local.php (не в git).
// php8.5 env.php --shell печатает то же самое как export-строки для bash.
$root = dirname(__DIR__);
if (!defined('ROOT_DIR')) define('ROOT_DIR', $root);
// стенд (tests/tools/stand.sh) подменяет каталог web, конфиг, учётные данные и адрес; без переменных — площадка
$web = getenv('ENERGINE_WEB') ?: dirname($root, 2) . '/web';
$configFile = getenv('ENERGINE_CONFIG') ?: $web . '/system.config.php';
$localFile = getenv('ENERGINE_LOCAL') ?: __DIR__ . '/local.php';
foreach ([$configFile => 'конфиг площадки', $localFile => 'tests/local.php (образец — local.php.example)'] as $f => $what) {
    if (!is_file($f)) {
        fwrite(STDERR, "env.php: нет файла $f — $what\n");
        exit(2);
    }
}
$config = include $configFile;
$local = include $localFile;
$db = $config['database'];
$mailbox = $local['mailbox'];
$env = [
    'BASE' => getenv('ENERGINE_BASE') ?: 'https://' . $config['site']['domain'],
    'ROOT' => $root,
    'WEB' => $web,
    'LOG' => $local['log'] ?? '/var/log/ispconfig/httpd/' . $config['site']['domain'] . '/error.log',
    'DB_HOST' => $db['host'],
    'DB_NAME' => $db['db'],
    'DB_USER' => $db['username'],
    'MYSQL_PWD' => $db['password'],
    'ADMIN_EMAIL' => $local['admin_email'],
    'ADMIN_PASSWORD' => $local['admin_password'],
    'MAILBOX' => $mailbox,
    'MAILBOX_FILE' => '/var/mail/' . strstr($mailbox, '@', true),
    'SITE_USER' => posix_getpwuid(fileowner($root))['name'],
];
$env['B'] = $env['BASE'];
if (PHP_SAPI === 'cli' && realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (in_array('--shell', $argv, true)) {
        foreach ($env as $k => $v) echo 'export ', $k, '=', escapeshellarg((string)$v), "\n";
    }
    exit(0);
}
return $env;
