<?php
// Модули ядра (этап 9): каждый скрипт ядра и сайта, кроме Jodit, — ES-модуль (есть export); имя, которое
// экспортирует один модуль, а пользуется им другой, импортировано этим другим.
// Запуск: php8.5 tests/tools/module-imports.php [корень проекта]. Печатает нарушения; выход 0 — нарушений нет.
$root = rtrim($argv[1] ?? dirname(__DIR__, 2), '/');
$files = array_merge(glob("$root/core/modules/*/scripts/*.js") ?: [], glob("$root/site/modules/*/scripts/*.js") ?: []);
if (!$files) {
    fwrite(STDERR, "скрипты ядра не найдены\n");
    exit(2);
}
// код без комментариев и содержимого строк: имена в них не считаются
$code = function ($file) {
    $src = file_get_contents($file);
    $src = preg_replace('~/\*.*?\*/~s', ' ', $src);
    $src = preg_replace('~(?<![:\\\\])//[^\n]*~', ' ', $src);
    return preg_replace(['~\'(?:\\\\.|[^\'\\\\\n])*\'~', '~"(?:\\\\.|[^"\\\\\n])*"~', '~`(?:\\\\.|[^`\\\\])*`~s'], ["''", '""', '``'], $src);
};
$rel = fn($f) => substr($f, strlen($root) + 1);
$exports = [];
$bad = [];
foreach ($files as $f) {
    $c = $code($f);
    if (!preg_match('~^export\s~m', $c)) {
        $bad[] = $rel($f) . ': не модуль (нет export)';
    }
    preg_match_all('~^export\s+(?:class|const|function)\s+(\w+)~m', $c, $m);
    foreach ($m[1] as $name) {
        $exports[$name] = $f;
    }
}
foreach ($files as $f) {
    $c = $code($f);
    preg_match_all('~^import\s*\{([^}]*)\}\s*from~m', $c, $m);
    $imported = array_filter(array_map('trim', explode(',', implode(',', $m[1]))));
    foreach ($exports as $name => $src) {
        if ($src !== $f && preg_match('~(?<![\w.$])' . preg_quote($name, '~') . '\b~', $c) && !in_array($name, $imported, true)) {
            $bad[] = $rel($f) . ": $name не импортирован";
        }
    }
}
echo $bad ? implode("\n", $bad) . "\n" : '';
exit($bad ? 1 : 0);
