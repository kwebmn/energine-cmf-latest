<?php
// Checks that the repository refuses files the web server would execute, and still accepts images.
// Everything it manages to upload is removed again.
require __DIR__ . '/testlib.php';

const TEMP_DIR = WEB . '/uploads/temp/';
const ENDPOINT = '/single/textBlock_1/file-library/upload-temp/?json';

function upload($name, $content, $mime) {
    $tmp = tempnam(sys_get_temp_dir(), 'up');
    file_put_contents($tmp, $content);
    $ch = curl_init(BASE . ENDPOINT);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_COOKIEJAR      => $GLOBALS['jar'],
        CURLOPT_COOKIEFILE     => $GLOBALS['jar'],
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => ['key' => 'upl_path', 'upl_path' => new CURLFile($tmp, $mime, $name)],
        CURLOPT_REFERER        => BASE . '/',
        CURLOPT_TIMEOUT        => 60,
        CURLOPT_HTTPHEADER     => ['X-CSRF-Token: ' . csrfToken()],
    ]);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    unlink($tmp);
    return [$code, (string)$body];
}

login();

// 1. a PHP script must be refused and must not appear on disk
[$code, $body] = upload('claude-probe.php', "<?php echo 'executed';", 'application/x-php');
$landed = file_exists(TEMP_DIR . 'claude-probe.php');
// отказ должен прийти от проверки файла (JSON с error), а не от чего-то ещё до неё (например, токена)
$refusedByCheck = fn($body) => ($j = json_decode($body, true)) && !empty($j['error']) && !empty($j['error_message']);
check('.php отвергнут проверкой файла', $refusedByCheck($body), $body);
check('.php не попал на диск', !$landed, TEMP_DIR . 'claude-probe.php');
if ($landed) unlink(TEMP_DIR . 'claude-probe.php');

// the same file is not reachable by URL either
[$c2] = http('/uploads/temp/claude-probe.php');
check('.php недоступен по URL (404)', $c2 === 404, 'HTTP ' . $c2);

// 2. double extension: the last one is what the web server looks at
[, $body3] = upload('claude-probe.jpg.php', "<?php echo 'executed';", 'image/jpeg');
$landed3 = file_exists(TEMP_DIR . 'claude-probe.jpg.php');
check('.jpg.php отвергнут проверкой файла', !$landed3 && $refusedByCheck($body3), $body3);
if ($landed3) unlink(TEMP_DIR . 'claude-probe.jpg.php');

// 3. a real image still uploads (no regression)
$png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
[$code4, $body4] = upload('claude-probe.png', $png, 'image/png');
$json = json_decode($body4, true);
$ok = is_array($json) && empty($json['error']) && !empty($json['tmp_name']);
check('.png принят', $ok, $body4);
if ($ok) {
    $path = WEB . '/' . ltrim($json['tmp_name'], '/');
    check('.png лежит на диске', file_exists($path), $path);
    @unlink($path);            // очистка: временный файл теста
}

// nothing of ours may stay behind
$left = array_diff(scandir(TEMP_DIR), ['.', '..', 'castings.ep', 'readme.txt']);
check('временный каталог чист', !$left, implode(', ', $left));

done('smoke-upload');
