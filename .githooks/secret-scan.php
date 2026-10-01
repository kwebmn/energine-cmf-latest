<?php
// Ищет пароли из локальных конфигов (база, администратор) в файлах или в индексе git.
// php8.5 .githooks/secret-scan.php [--config=ФАЙЛ]... (--staged | ПУТЬ...)
// Выход: 0 — чисто, 1 — найдено (печатаются только имена файлов), 2 — проверку выполнить не удалось.
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

function readConfig(string $file): array {
    try {
        $c = include $file;
    } catch (\Throwable $e) {
        fwrite(STDERR, "secret-scan: не читается $file: {$e->getMessage()}\n");
        exit(2);
    }
    return is_array($c) ? $c : [];
}

// git с именами файлов как есть (не-ASCII без кавычек и восьмеричных кодов) и кодом возврата
function git(string $root, string ...$args): array {
    $cmd = 'git -C ' . escapeshellarg($root) . ' -c core.quotePath=false '
        . implode(' ', array_map('escapeshellarg', $args)) . ' 2>/dev/null';
    $p = proc_open($cmd, [1 => ['pipe', 'w']], $pipes);
    if (!is_resource($p)) return ['', 1];
    $out = stream_get_contents($pipes[1]);
    fclose($pipes[1]);
    return [$out, proc_close($p)];
}

$secrets = [];
foreach ($configs as $file) {
    if (!is_file($file)) continue;
    if (!defined('ROOT_DIR')) define('ROOT_DIR', $root);
    $secrets[] = readConfig($file)['database']['password'] ?? '';
}
// учётные данные тестов — как в tests/env.php: стенд (tests/tools/stand.sh) задаёт свои
if (is_file($local = getenv('ENERGINE_LOCAL') ?: $root . '/tests/local.php')) {
    $secrets[] = readConfig($local)['admin_password'] ?? '';
}
$secrets = array_values(array_filter($secrets, fn($s) => strlen((string)$s) >= 6));
if (!$secrets) {
    fwrite(STDERR, "secret-scan: локальных конфигов нет, проверять нечего\n");
    exit(0);
}
if ($staged) {
    [$list, $rc] = git($root, 'diff', '--cached', '--name-only', '-z', '--diff-filter=ACMRT');
    if ($rc !== 0) {
        fwrite(STDERR, "secret-scan: git не отдал список файлов индекса\n");
        exit(2);
    }
    $paths = array_values(array_filter(explode("\0", $list), 'strlen'));
}
$found = 0;
foreach ($paths as $path) {
    if ($staged) {
        [$body, $rc] = git($root, 'show', ':' . $path);
        if ($rc !== 0) {
            fwrite(STDERR, "secret-scan: не удалось прочитать из индекса $path\n");
            exit(2);
        }
    } else {
        $body = is_file($path) ? (string)file_get_contents($path) : '';
    }
    foreach ($secrets as $s) {
        if (str_contains($body, (string)$s)) {
            echo $path, "\n";
            $found = 1;
            break;
        }
    }
}
exit($found);
