<?php
// Edit-mode smoke test: text block save, layout manager endpoints, content XML save. Restores original DB values.
$E = require __DIR__ . '/env.php';
$B = $E['BASE'];
$jar = __DIR__ . '/smoke-editing-cookies.txt';
@unlink($jar);
$pdo = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$fail = 0;

function http($url, $post = null, $headers = []) {
    global $jar;
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEJAR => $jar, CURLOPT_COOKIEFILE => $jar,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_REFERER => $GLOBALS['B'] . '/login/']);
    if ($post !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, is_array($post) ? http_build_query($post) : $post);
    }
    $body = curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), $body];
}
function check($label, $cond, $detail = '') {
    global $fail;
    echo ($cond ? 'OK   ' : 'FAIL ') . $label . ($cond ? '' : ': ' . substr(preg_replace('/\s+/', ' ', $detail), 0, 300)) . PHP_EOL;
    if (!$cond) $fail++;
}
function clean($body) {
    return !preg_match('/Fatal error|Warning: |Notice: |Deprecated: |<title>Errors<\/title>|object\([A-Za-z\\\\]+Exception\)/', $body);
}

http("$B/login/");
http("$B/auth.php", ['user' => ['login' => 1, 'username' => $E['ADMIN_EMAIL'], 'password' => $E['ADMIN_PASSWORD']]]);

// backups
$tbOrig = $pdo->query("SELECT tb_content FROM share_textblocks_translation WHERE tb_id = 59 AND lang_id = 1")->fetchColumn();
$xmlOrig = $pdo->query("SELECT smap_content_xml FROM share_sitemap WHERE smap_id = 80")->fetchColumn();

try {
    [$code, $body] = http("$B/", ['editMode' => 1]);
    check('edit mode page', $code == 200 && clean($body) && strpos($body, 'single/textBlock_1/') !== false, $body);
    preg_match("~new PageToolbar\('([^']+)'~", $body, $m);
    $panel = $m[1] ?? "$B/single/adminPanel/";

    // text block save with the same content
    [$code, $body] = http("$B/single/textBlock_1/save-text", ['data' => $tbOrig, 'ID' => 80, 'num' => 1]);
    $tbNow = $pdo->query("SELECT tb_content FROM share_textblocks_translation WHERE tb_id = 59 AND lang_id = 1")->fetchColumn();
    check('textblock save', $code == 200 && clean($body) && trim($tbNow) !== '', $body);

    // layout manager endpoints
    [$code, $body] = http($panel . 'get-template-info/', null, ['X-Request: JSON']);
    $j = json_decode($body, true);
    check('get-template-info', $code == 200 && !empty($j['result']), $body);

    [$code, $body] = http($panel . 'widgets/');
    check('widgets list', $code == 200 && clean($body), $body);

    $widgetXml = $pdo->query("SELECT widget_xml FROM share_widgets WHERE widget_id = 1")->fetchColumn();
    [$code, $body] = http($panel . 'widgets/build-widget/', ['xml' => $widgetXml]);
    check('build widget', $code == 200 && clean($body) && strpos($body, '<div') !== false, $body);

    // ModalBox posts the widget container XML as modalBoxData
    $doc = new DOMDocument();
    $doc->loadXML($xmlOrig);
    $container = (new DOMXPath($doc))->query("//component[@name='topNews']/..")->item(0);
    [$code, $body] = http($panel . 'widgets/edit-params/topNews/', ['modalBoxData' => $doc->saveXML($container)]);
    check('widget edit params', $code == 200 && clean($body), $body);

    [$code, $body] = http($panel . 'widgets/save-content/', ['xml' => $xmlOrig], ['X-Request: JSON']);
    $j = json_decode($body, true);
    $xmlNow = $pdo->query("SELECT smap_content_xml FROM share_sitemap WHERE smap_id = 80")->fetchColumn();
    check('save content xml', $code == 200 && !empty($j['result']) && strpos((string)$xmlNow, 'textBlock_1') !== false, $body);

    [$code, $body] = http("$B/");
    check('page after content save', $code == 200 && clean($body) && strpos($body, 'Главная страница') !== false, $body);
} finally {
    $st = $pdo->prepare("UPDATE share_textblocks_translation SET tb_content = ? WHERE tb_id = 59 AND lang_id = 1");
    $st->execute([$tbOrig]);
    $st = $pdo->prepare("UPDATE share_sitemap SET smap_content_xml = ? WHERE smap_id = 80");
    $st->execute([$xmlOrig]);
    $same = $pdo->query("SELECT tb_content FROM share_textblocks_translation WHERE tb_id = 59 AND lang_id = 1")->fetchColumn() === $tbOrig
        && $pdo->query("SELECT smap_content_xml FROM share_sitemap WHERE smap_id = 80")->fetchColumn() === $xmlOrig;
    check('originals restored', $same);
}
echo "== editing failures: $fail\n";
exit($fail ? 1 : 0);
