<?php
// Адрес страницы — один (надёжность, этап 5): адрес страницы без «/» на конце отвечает 301 на адрес со слешем
// (прежде — та же страница с кодом 200, дубль для поисковиков); другое имя хоста плюс нет слеша — одна переадресация на
// site.domain. Не трогаются: POST, запросы JSON админки, «файлы» (точка в последнем сегменте), корень. Строка запроса
// сохраняется как была.
require __DIR__ . '/testlib.php';
require ROOT . '/vendor/autoload.php';
require_once ROOT . '/core/modules/share/gears/Registry.php'; // функция E()

use Energine\share\gears\SiteManager;

// 1. чистая функция (консоль): SiteManager::canonicalURL(method, scheme, host, port, requestUri, json, domain)
$exists = method_exists(SiteManager::class, 'canonicalURL');
check('SiteManager::canonicalURL есть', $exists);
if ($exists) {
    $d = 'simple.energine.org';
    $c = fn($uri, $method = 'GET', $json = false, $host = 'simple.energine.org', $port = 443, $scheme = 'https', $domain = null)
        => SiteManager::canonicalURL($method, $scheme, $host, $port, $uri, $json, $domain ?? $d);
    $cases = [
        ['страница без слеша → со слешем', $c('/info/quick-start'), 'https://simple.energine.org/info/quick-start/'],
        ['строка запроса сохраняется как была', $c('/info/quick-start?x=1&y=%D0%B0'), 'https://simple.energine.org/info/quick-start/?x=1&y=%D0%B0'],
        ['HEAD — так же', $c('/info', 'HEAD'), 'https://simple.energine.org/info/'],
        ['второй язык', $c('/ua'), 'https://simple.energine.org/ua/'],
        ['адрес со слешем — без переадресации', $c('/info/quick-start/'), null],
        ['корень — без переадресации', $c('/'), null],
        ['корень со строкой запроса — без переадресации', $c('/?debug'), null],
        ['POST — без переадресации', $c('/info/quick-start', 'POST'), null],
        ['запрос JSON — без переадресации', $c('/admin/users/single/userEditor/get-data', 'GET', true), null],
        ['«файл» robots.txt — как есть', $c('/robots.txt'), null],
        ['«файл» в uploads — как есть', $c('/uploads/public/a.jpg'), null],
        ['index.php — как есть', $c('/index.php?x=1'), null],
        ['другое имя хоста и нет слеша — одна переадресация на site.domain со слешем', $c('/info', 'GET', false, 'www.example.org'), 'https://simple.energine.org/info/'],
        ['другое имя хоста со слешем — только хост', $c('/info/?a=1', 'GET', false, 'www.example.org'), 'https://simple.energine.org/info/?a=1'],
        ['другое имя хоста, POST — без переадресации (как прежде)', $c('/info', 'POST', false, 'www.example.org'), null],
        ['другое имя хоста, JSON — только хост (как прежде), путь как есть', $c('/x/get-data', 'GET', true, 'www.example.org'), 'https://simple.energine.org/x/get-data'],
        ['порт из site.domain: тот же — без переадресации хоста', $c('/info/', 'GET', false, 'localhost', 8080, 'http', 'localhost:8080'), null],
        ['порт из site.domain: другой — на site.domain', $c('/info/', 'GET', false, 'localhost', 8081, 'http', 'localhost:8080'), 'http://localhost:8080/info/'],
        ['пустой путь запроса — корень', $c(''), null],
    ];
    foreach ($cases as [$label, $got, $want]) {
        check("canonicalURL: $label", $got === $want, var_export($got, true) . ' ≠ ' . var_export($want, true));
    }
}

// 2. через nginx и ядро
function head301(string $path, string $method = 'GET', array $headers = []): array {
    $ch = curl_init(BASE . $path);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_HEADER => true, CURLOPT_NOBODY => $method === 'HEAD',
        CURLOPT_CUSTOMREQUEST => $method, CURLOPT_HTTPHEADER => $headers, CURLOPT_TIMEOUT => 60]);
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POSTFIELDS, 'a=1');
    }
    $raw = (string)curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $location = preg_match('~^Location:\s*(\S+)~mi', $raw, $m) ? $m[1] : '';
    return [$code, $location];
}
$base = rtrim(BASE, '/');
[$code, $loc] = head301('/info/quick-start');
check('GET /info/quick-start → 301 на /info/quick-start/', $code === 301 && $loc === $base . '/info/quick-start/', "$code $loc");
[$code, $loc] = head301('/info/quick-start?x=1');
check('строка запроса идёт в переадресацию', $code === 301 && $loc === $base . '/info/quick-start/?x=1', "$code $loc");
[$code, $loc] = head301('/info/quick-start', 'HEAD');
check('HEAD → 301', $code === 301 && $loc === $base . '/info/quick-start/', "$code $loc");
[$code] = head301('/info/quick-start/');
check('адрес со слешем — 200', $code === 200, (string)$code);
[$code] = head301('/');
check('корень — 200', $code === 200, (string)$code);
[$code] = head301('/info/quick-start', 'POST');
check('POST без слеша — не 301', $code !== 301, (string)$code);
[$code] = head301('/info/quick-start', 'GET', ['X-Request: JSON']);
check('GET с X-Request: JSON — не 301', $code !== 301, (string)$code);
[$code] = head301('/info/quick-start/nofile.txt');
check('«файл» с точкой — не 301', $code !== 301, (string)$code);
if ((int)scalar("SELECT lang_is_active FROM share_languages WHERE lang_abbr = 'ua'") === 1) {
    [$code, $loc] = head301('/ua/info');
    check('второй язык: /ua/info → 301 на /ua/info/', $code === 301 && $loc === $base . '/ua/info/', "$code $loc");
} else {
    echo "SKIP второй язык закрыт — /ua/ не проверяется\n";
}
done('urls');
