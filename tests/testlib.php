<?php
// Shared helpers for HTTP-level tests; the site, database and credentials come from env.php
$E = require __DIR__ . '/env.php';
define('BASE', $E['BASE']);
define('WEB', $E['WEB']);
define('ROOT', $E['ROOT']);
define('MAILBOX', $E['MAILBOX']);
define('MAILBOX_FILE', $E['MAILBOX_FILE']);
define('DB_NAME', $E['DB_NAME']);
define('SITE_USER', $E['SITE_USER']);
$GLOBALS['fail'] = 0;
$GLOBALS['jar'] = sys_get_temp_dir() . '/energine-test-' . getmypid() . '.cookies';

function pdo() {
    static $pdo;
    return $pdo ??= new PDO("mysql:host={$GLOBALS['E']['DB_HOST']};dbname={$GLOBALS['E']['DB_NAME']};charset=utf8", $GLOBALS['E']['DB_USER'], $GLOBALS['E']['MYSQL_PWD'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]);
}
function q($sql, $args = []) { $st = pdo()->prepare($sql); $st->execute($args); return $st; }
function scalar($sql, $args = []) { return q($sql, $args)->fetchColumn(); }

// POST без заголовка X-CSRF-Token получает токен текущего посетителя (csrfToken);
// пустой заголовок 'X-CSRF-Token: ' — отправить без токена
function http($url, $post = null, $headers = [], $referer = null) {
    if ($post !== null && !preg_grep('/^X-CSRF-Token:/i', $headers)) {
        $headers[] = 'X-CSRF-Token: ' . csrfToken();
    }
    $ch = curl_init(str_starts_with($url, 'http') ? $url : BASE . $url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEJAR => $GLOBALS['jar'], CURLOPT_COOKIEFILE => $GLOBALS['jar'],
        CURLOPT_HTTPHEADER => $headers, CURLOPT_REFERER => $referer ?? BASE . '/', CURLOPT_TIMEOUT => 120]);
    if ($post !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, is_array($post) ? http_build_query($post) : $post);
    }
    $body = curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), (string)$body];
}
// значение cookie из банки curl (формат Netscape, строки HttpOnly начинаются с #HttpOnly_)
function cookie($name) {
    foreach (@file($GLOBALS['jar'], FILE_IGNORE_NEW_LINES) ?: [] as $line) {
        $f = explode("\t", $line);
        if (count($f) == 7 && $f[5] === $name) return $f[6];
    }
    return null;
}
// токен CSRF текущего посетителя со страницы; берётся заново, когда сменились сессия или cookie гостя
function csrfToken() {
    static $cache = [];
    $key = cookie('NRGNSID') . '|' . cookie('nrgn_csrf');
    if (!array_key_exists($key, $cache)) {
        [, $html] = http('/');
        $key = cookie('NRGNSID') . '|' . cookie('nrgn_csrf');
        $cache[$key] = preg_match('~<meta name="csrf-token" content="([^"]*)"~', $html, $m) ? $m[1] : '';
    }
    return $cache[$key];
}
function json($url, $post = '') { [$c, $b] = http($url, $post, ['X-Request: JSON']); return [$c, json_decode($b, true), $b]; }
// значение константы интерфейса из справочника (тексты сообщений переведены)
function translation($const, $lang = 1) {
    return scalar('SELECT tt.ltag_value_rtf FROM share_lang_tags t JOIN share_lang_tags_translation tt USING(ltag_id) WHERE t.ltag_name = ? AND tt.lang_id = ?', [$const, $lang]);
}
function login() {
    @unlink($GLOBALS['jar']);
    http('/login/');
    http('/auth.php', ['user' => ['login' => 1, 'username' => $GLOBALS['E']['ADMIN_EMAIL'], 'password' => $GLOBALS['E']['ADMIN_PASSWORD']]], [], BASE . '/login/');
}
function logout() { http('/auth.php', ['user' => ['logout' => 1]]); }
function clean($body) {
    return !preg_match('/Fatal error|Warning: |Notice: |Deprecated: |<title>Errors<\/title>|object\([A-Za-z\\\\]+Exception\)/', $body);
}
function check($label, $cond, $detail = '') {
    echo ($cond ? 'OK   ' : 'FAIL ') . $label . ($cond ? '' : ': ' . substr(preg_replace('/\s+/', ' ', strip_tags((string)$detail)), 0, 400)) . PHP_EOL;
    if (!$cond) $GLOBALS['fail']++;
    return $cond;
}
function done($name) { echo "== $name failures: {$GLOBALS['fail']}\n"; @unlink($GLOBALS['jar']); exit($GLOBALS['fail'] ? 1 : 0); }

// Browser-like form serialization; $set overrides values by field name (all occurrences replaced by one pair)
function formData($html, array $set = []) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $xp = new DOMXPath($doc);
    $pairs = [];
    foreach ($xp->query('//form//input[@name] | //form//select[@name] | //form//textarea[@name]') as $el) {
        $name = $el->getAttribute('name');
        if ($el->hasAttribute('disabled') || array_key_exists($name, $set)) continue;
        switch ($el->nodeName) {
            case 'input':
                $type = strtolower($el->getAttribute('type') ?: 'text');
                if (in_array($type, ['submit', 'reset', 'file', 'button', 'image'])) continue 2;
                if (in_array($type, ['checkbox', 'radio']) && !$el->hasAttribute('checked')) continue 2;
                $pairs[] = [$name, $el->hasAttribute('value') ? $el->getAttribute('value') : 'on'];
                break;
            case 'select':
                $sel = $xp->query('.//option[@selected]', $el);
                if (!$sel->length && !$el->hasAttribute('multiple')) $sel = $xp->query('.//option[1]', $el);
                foreach ($sel as $o) $pairs[] = [$name, $o->hasAttribute('value') ? $o->getAttribute('value') : $o->textContent];
                break;
            case 'textarea':
                $pairs[] = [$name, $el->textContent];
                break;
        }
    }
    foreach ($set as $name => $value) {
        foreach ((array)$value as $v) $pairs[] = [$name, $v];
    }
    return implode('&', array_map(fn($p) => rawurlencode($p[0]) . '=' . rawurlencode($p[1]), $pairs));
}
function singleTemplate($html, $contains = '') {
    preg_match_all('~single_template="([^"]+)"~', $html, $m);
    foreach (array_unique($m[1]) as $s) if ($contains === '' || str_contains($s, $contains)) return $s;
    return null;
}
