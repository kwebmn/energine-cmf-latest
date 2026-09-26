<?php
// Ищет пароли из локальных конфигов (база, администратор) в файлах или в индексе git.
// php8.5 .githooks/secret-scan.php [--config=ФАЙЛ]... (--staged | ПУТЬ...)
// Выход: 0 — чисто, 1 — найдено (печатаются только имена файлов), 2 — ошибка запуска.
$root = dirname(__DIR__);
$configs = [];
$paths = [];
$staged = false;
foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--config=')) $configs[] = substr($arg, 9);
    elseif ($arg === '--staged') $staged = true;
    else $paths[] = $arg;
}
if (!$configs) {
    $configs[] = getenv('ENERGINE_CONFIG') ?: dirname($root, 2) . '/web/system.config.php';
}
$secrets = [];
foreach ($configs as $file) {
    if (!is_file($file)) continue;
    if (!defined('ROOT_DIR')) define('ROOT_DIR', $root);
    $c = include $file;
    $secrets[] = $c['database']['password'] ?? '';
}
if (is_file($local = $root . '/tests/local.php')) {
    $secrets[] = (include $local)['admin_password'] ?? '';
}
$secrets = array_values(array_filter($secrets, fn($s) => strlen($s) >= 6));
if (!$secrets) {
    fwrite(STDERR, "secret-scan: локальных конфигов нет, проверять нечего\n");
    exit(0);
}
if ($staged) {
    exec('git -C ' . escapeshellarg($root) . ' diff --cached --name-only --diff-filter=ACMR', $paths, $rc);
    if ($rc) exit(2);
}
$found = 0;
foreach ($paths as $path) {
    $body = $staged
        ? shell_exec('git -C ' . escapeshellarg($root) . ' show ' . escapeshellarg(':' . $path))
        : (is_file($path) ? file_get_contents($path) : '');
    foreach ($secrets as $s) {
        if ($body !== null && str_contains((string)$body, $s)) {
            echo $path, "\n";
            $found = 1;
            break;
        }
    }
}
exit($found);
