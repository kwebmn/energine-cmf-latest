<?php
// Edit-mode smoke test: edit mode page, text block save. Restores original DB values.
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

// токен страницы (Csrf): у гостя — для входа, после входа — для правки
function token($html) {
    return preg_match('~<meta name="csrf-token" content="([^"]*)"~', (string)$html, $m) ? $m[1] : '';
}
[, $loginPage] = http("$B/login/");
http("$B/auth.php", ['csrf_token' => token($loginPage), 'user' => ['login' => 1, 'username' => $E['ADMIN_EMAIL'], 'password' => $E['ADMIN_PASSWORD']]]);
[, $home] = http("$B/");
$csrf = token($home);

// backups
$tbOrig = $pdo->query("SELECT tb_content FROM share_textblocks_translation WHERE tb_id = 59 AND lang_id = 1")->fetchColumn();
$xmlOrig = $pdo->query("SELECT smap_content_xml FROM share_sitemap WHERE smap_id = 80")->fetchColumn();

try {
    [$code, $body] = http("$B/", ['editMode' => 1, 'csrf_token' => $csrf]);
    check('edit mode page', $code == 200 && clean($body) && strpos($body, 'single/textBlock_1/') !== false, $body);
    preg_match("~new PageToolbar\('([^']+)'~", $body, $m);
    $panel = $m[1] ?? "$B/single/adminPanel/";

    // text block save with the same content
    [$code, $body] = http("$B/single/textBlock_1/save-text", ['data' => $tbOrig, 'ID' => 80, 'num' => 1, 'csrf_token' => $csrf]);
    $tbNow = $pdo->query("SELECT tb_content FROM share_textblocks_translation WHERE tb_id = 59 AND lang_id = 1")->fetchColumn();
    check('textblock save', $code == 200 && clean($body) && trim($tbNow) !== '', $body);

    [$code, $body] = http("$B/");
    check('page after textblock save', $code == 200 && clean($body) && strpos($body, 'Главная страница') !== false, $body);

    // save-text of the news feed: the field is taken from `num` — only a column of the translation table
    // (it went into the SQL as a column name: any text there was part of the query)
    [, $list] = http("$B/news/");
    preg_match('~href="([^"]*/(\d+)--[^"/]+/)"~', $list, $nm);
    [$code, $page] = http($nm[1] ?? "$B/news/", ['editMode' => 1, 'csrf_token' => $csrf]);
    preg_match('~<h3[^>]*class="nrgnEditor feed_name"[^>]*>~', $page, $h3);
    preg_match('~single_template="([^"]+)"~', $h3[0] ?? '', $st);
    $newsId = (int)($nm[2] ?? 0);
    $title = fn() => $pdo->query("SELECT news_title FROM apps_news_translation WHERE news_id = $newsId AND lang_id = 1")->fetchColumn();
    $titleOrig = $title();
    // every field of the news, all languages: a query that got through could change any of them
    $newsSnap = $pdo->query("SELECT * FROM apps_news_translation WHERE news_id = $newsId")->fetchAll(PDO::FETCH_ASSOC);
    $saveText = ($st[1] ?? '') . 'save-text?json';
    check('news page in edit mode has the editable title', $newsId && isset($st[1]), $h3[0] ?? $page);
    foreach (["news_title = 'claude-sql', news_text_rtf", 'news_id', 'lang_id', 'no_such_column'] as $num) {
        [$code, $body] = http($saveText, ['data' => 'claude-editing', 'ID' => $newsId, 'num' => $num, 'csrf_token' => $csrf]);
        $j = json_decode($body, true);
        check("save-text refuses num=$num", is_array($j) && empty($j['result']) && $title() === $titleOrig, $body);
    }
    [$code, $body] = http($saveText, ['data' => 'claude-editing-title', 'ID' => $newsId, 'num' => 'news_title', 'csrf_token' => $csrf]);
    $j = json_decode($body, true);
    check('save-text saves num=news_title', is_array($j) && !empty($j['result']) && $title() === 'claude-editing-title', $body);
} finally {
    foreach ($newsSnap ?? [] as $r) {
        $pdo->prepare("UPDATE apps_news_translation SET news_title = ?, news_announce_rtf = ?, news_text_rtf = ? WHERE news_id = ? AND lang_id = ?")
            ->execute([$r['news_title'], $r['news_announce_rtf'], $r['news_text_rtf'], $r['news_id'], $r['lang_id']]);
    }
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
