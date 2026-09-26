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

http("$B/login/");
http("$B/auth.php", http_build_query(['user' => ['login' => 1, 'username' => $E['ADMIN_EMAIL'], 'password' => $E['ADMIN_PASSWORD']]]));

$editors = [
    'site'                => '/admin/structure/sites/single/siteEditor/1/edit/',
    'language'            => '/admin/translations/languages/single/langEditor/1/edit/',
    'role'                => '/admin/users/roles/single/roleEditor/1/edit/',
    'widget'              => '/admin/widgets/single/widgetsRepository/1/edit/',
    'poll'                => '/admin/polls/single/voteEditor/1/edit/',
    'feedback recipient'  => '/admin/feedback-editor/recipients/single/feedbackRecipientsEditor/5/edit/',
    'form (builder)'      => '/admin/form-builder/single/formEditor/5/edit/',
    'page (division)'     => '/admin/structure/single/divEditor/3594/edit/',
    'user'                => '/admin/users/single/userEditor/22/edit/',
    'translation'         => '/admin/translations/single/transEditor/14/edit/',
    'news'                => '/admin/news-editor/single/newsRepo/1/edit/',
];
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
}
echo "== roundtrip failures: $fail\n";
