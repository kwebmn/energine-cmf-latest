<?php
// Opens admin edit forms, submits them back unchanged (like the browser serializes a form) and expects result=true.
$E = require __DIR__ . '/env.php';
$B = $E['BASE'];
$jar = __DIR__ . '/smoke-roundtrip-cookies.txt';
@unlink($jar);
$fail = 0;

function http($url, $post = null, $headers = []) {
    global $jar;
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEJAR => $jar, CURLOPT_COOKIEFILE => $jar,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_REFERER => $GLOBALS['B'] . '/login/']);
    if ($post !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $post);
    }
    $body = curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), $body];
}

// Browser-like form serialization (mootools Element.toQueryString)
function serializeForm($html) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $xp = new DOMXPath($doc);
    $pairs = [];
    foreach ($xp->query('//form//input[@name] | //form//select[@name] | //form//textarea[@name]') as $el) {
        $name = $el->getAttribute('name');
        if ($el->hasAttribute('disabled')) continue;
        switch ($el->nodeName) {
            case 'input':
                $type = strtolower($el->getAttribute('type') ?: 'text');
                if (in_array($type, ['submit', 'reset', 'file', 'button', 'image'])) continue 2;
                if (in_array($type, ['checkbox', 'radio']) && !$el->hasAttribute('checked')) continue 2;
                $pairs[] = [$name, $el->hasAttribute('value') ? $el->getAttribute('value') : ($type == 'checkbox' || $type == 'radio' ? 'on' : '')];
                break;
            case 'select':
                $selected = $xp->query('.//option[@selected]', $el);
                if (!$selected->length && !$el->hasAttribute('multiple')) $selected = $xp->query('.//option[1]', $el);
                foreach ($selected as $opt) $pairs[] = [$name, $opt->hasAttribute('value') ? $opt->getAttribute('value') : $opt->textContent];
                break;
            case 'textarea':
                $pairs[] = [$name, $el->textContent];
                break;
        }
    }
    return implode('&', array_map(fn($p) => rawurlencode($p[0]) . '=' . rawurlencode($p[1]), $pairs));
}

// вход несёт токен страницы входа (Csrf); формы правки приносят свой токен скрытым полем
[, $loginPage] = http("$B/login/");
$csrf = preg_match('~<meta name="csrf-token" content="([^"]*)"~', $loginPage, $m) ? $m[1] : '';
http("$B/auth.php", http_build_query(['csrf_token' => $csrf, 'user' => ['login' => 1, 'username' => $E['ADMIN_EMAIL'], 'password' => $E['ADMIN_PASSWORD']]]));

$editors = [
    'site settings'       => '/admin/settings/single/settings/1/edit/',
    'language'            => '/admin/translations/languages/single/langEditor/1/edit/',
    'role'                => '/admin/users/roles/single/roleEditor/1/edit/',
    'feedback recipient'  => '/admin/feedback-editor/recipients/single/feedbackRecipientsEditor/5/edit/',
    'page (division)'     => '/admin/structure/single/divEditor/3594/edit/',
    'user'                => '/admin/users/single/userEditor/22/edit/',
    'translation'         => '/admin/translations/single/transEditor/14/edit/',
    'news'                => '/admin/news-editor/single/newsRepo/1/edit/',
];
// права раздела сохраняются тем же запросом, что и форма; роундтрип не должен их менять
$pdo = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$rights = fn($id) => $pdo->query('SELECT CONCAT(group_id, ":", right_id) FROM share_access_level WHERE smap_id = ' . (int)$id . ' ORDER BY 1')
    ->fetchAll(PDO::FETCH_COLUMN);
$rightsBefore = $rights(3594);
foreach ($editors as $label => $path) {
    [$code, $html] = http($B . $path);
    if ($code != 200) { echo "FAIL $label: edit form HTTP $code\n"; $fail++; continue; }
    $data = serializeForm($html);
    $single = preg_replace('~(\d+/edit/)$~', '', $B . $path);
    [$code, $body] = http($single . 'save', $data, ['X-Request: JSON']);
    $j = json_decode($body, true);
    if ($code == 200 && is_array($j) && !empty($j['result'])) {
        echo "OK   $label save (", strlen($data), " bytes of form data)\n";
    } else {
        echo "FAIL $label save: HTTP $code ", substr(preg_replace('/\s+/', ' ', strip_tags($body)), 0, 300), "\n";
        $fail++;
    }
    if ($label === 'page (division)') {
        $after = $rights(3594);
        if ($rightsBefore && $after === $rightsBefore) {
            echo "OK   $label rights kept (", implode(' ', $after), ")\n";
        } else {
            echo "FAIL $label rights: before ", implode(' ', $rightsBefore), ", after ", implode(' ', $after), "\n";
            $fail++;
            // права возвращаются, чтобы провал теста не закрыл раздел
            $pdo->prepare('DELETE FROM share_access_level WHERE smap_id = 3594')->execute();
            $ins = $pdo->prepare('INSERT INTO share_access_level (smap_id, group_id, right_id) VALUES (3594, ?, ?)');
            foreach ($rightsBefore as $gr) $ins->execute(explode(':', $gr));
        }
    }
}
echo "== roundtrip failures: $fail\n";
