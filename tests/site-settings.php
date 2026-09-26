<?php
// «Настройки сайта» (admin/settings/): единственная запись share_sites правится формой, изменения видит посетитель.
//  - страница — 200, грид одной записи; добавить, удалить, переставить сайт нельзя (адресов этих действий нет);
//  - форма: название, ключевые слова и описание по языкам, site_meta_robots, вкладка свойств;
//  - новое название (ru) — в шапке главной; NOINDEX — robots.txt закрывает сайт, google-sitemap — 404;
//  - сохранение без токена — 422, запись та же.
// Исходные значения возвращаются в конце, в том числе после провала.
$E = require __DIR__ . '/env.php';
$B = $E['BASE'];
$jar = tempnam(sys_get_temp_dir(), 'settings');
$fail = 0;
function check($label, $ok, $detail = '') {
    global $fail;
    echo ($ok ? 'OK   ' : 'FAIL '), $label, ($ok || $detail === '' ? '' : ": $detail"), "\n";
    if (!$ok) $fail++;
}
function http($url, $post = null, $headers = []) {
    global $jar, $B;
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEJAR => $jar, CURLOPT_COOKIEFILE => $jar,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_REFERER => $B . '/admin/settings/']);
    if ($post !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $post);
    }
    $body = curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), $body];
}
function xpath($html) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    return new DOMXPath($doc);
}
// поля формы, как их отправляет браузер (как в smoke-roundtrip.php)
function formFields($html) {
    $xp = xpath($html);
    $pairs = [];
    foreach ($xp->query('//form//input[@name] | //form//select[@name] | //form//textarea[@name]') as $el) {
        if ($el->hasAttribute('disabled')) continue;
        $name = $el->getAttribute('name');
        if ($el->nodeName === 'input') {
            $type = strtolower($el->getAttribute('type') ?: 'text');
            if (in_array($type, ['submit', 'reset', 'file', 'button', 'image'])) continue;
            if (in_array($type, ['checkbox', 'radio']) && !$el->hasAttribute('checked')) continue;
            $pairs[] = [$name, $el->getAttribute('value')];
        } elseif ($el->nodeName === 'select') {
            foreach ($xp->query('.//option[@selected]', $el) as $opt) $pairs[] = [$name, $opt->getAttribute('value')];
        } else {
            $pairs[] = [$name, $el->textContent];
        }
    }
    return $pairs;
}
function encode($pairs) {
    return implode('&', array_map(fn($p) => rawurlencode($p[0]) . '=' . rawurlencode($p[1]), $pairs));
}
// пары формы с заменой: значение поля $name — $value (для SET: список значений или пусто)
function with($pairs, $name, $values) {
    $out = array_values(array_filter($pairs, fn($p) => $p[0] !== $name && $p[0] !== $name . '[]'));
    foreach ((array)$values as $v) $out[] = [$name . (is_array($values) ? '[]' : ''), $v];
    return $out;
}

$pdo = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$site = $pdo->query('SELECT * FROM share_sites')->fetchAll(PDO::FETCH_ASSOC);
$names = $pdo->query('SELECT lang_id, site_name FROM share_sites_translation ORDER BY lang_id')->fetchAll(PDO::FETCH_KEY_PAIR);
$robotsBefore = $site[0]['site_meta_robots'] ?? null;
$restore = function () use ($pdo, $site, $names, $robotsBefore) {
    $pdo->prepare('UPDATE share_sites SET site_meta_robots = ? WHERE site_id = ?')->execute([$robotsBefore, $site[0]['site_id']]);
    $st = $pdo->prepare('UPDATE share_sites_translation SET site_name = ? WHERE lang_id = ? AND site_id = ?');
    foreach ($names as $lang => $name) $st->execute([$name, $lang, $site[0]['site_id']]);
};

try {
    check('в базе один сайт', count($site) === 1, count($site) . ' записей');
    $id = (int)$site[0]['site_id'];

    [, $loginPage] = http("$B/login/");
    $csrf = preg_match('~<meta name="csrf-token" content="([^"]*)"~', $loginPage, $m) ? $m[1] : '';
    http("$B/auth.php", http_build_query(['csrf_token' => $csrf, 'user' => ['login' => 1, 'username' => $E['ADMIN_EMAIL'],
        'password' => $E['ADMIN_PASSWORD']]]));

    [$code, $html] = http("$B/admin/settings/");
    check('admin/settings/ — 200', $code == 200, "HTTP $code");
    // запросы грида (POST) несут токен сессии из страницы
    $tok = preg_match('~<meta name="csrf-token" content="([^"]*)"~', (string)$html, $m) ? $m[1] : '';
    $single = "$B/admin/settings/single/settings/";
    [$code, $body] = http($single . 'get-data/', '', ['X-Request: JSON', "X-CSRF-Token: $tok"]);
    $j = json_decode((string)$body, true);
    check('грид — одна запись', $code == 200 && is_array($j) && count($j['data'] ?? []) === 1,
        "HTTP $code " . substr((string)$body, 0, 200));
    foreach (['add/' => 'добавление', "$id/delete/" => 'удаление', "$id/up/" => 'перемещение'] as $path => $what) {
        [$code] = http($single . $path);
        check("$what сайта — адреса нет", $code == 404, "HTTP $code");
    }

    [$code, $form] = http($single . "$id/edit/");
    check('форма правки — 200', $code == 200, "HTTP $code");
    $pairs = formFields($form);
    $fieldNames = array_unique(array_map(fn($p) => preg_replace('/\[\]$/', '', $p[0]), $pairs));
    $xp = xpath($form);
    foreach ($names as $lang => $name) {
        foreach (['site_name', 'site_meta_keywords', 'site_meta_description'] as $f) {
            $n = "share_sites_translation[$lang][$f]";
            check("поле $n", $xp->query("//form//*[@name='$n']")->length === 1);
        }
    }
    check('поле site_meta_robots', $xp->query("//form//*[@name='share_sites[site_meta_robots]' or @name='share_sites[site_meta_robots][]']")->length > 0);
    // из записи сайта форма правит только site_meta_robots (номер записи — скрытое поле)
    $formNames = array_map(fn($el) => preg_replace('/\[\]$/', '', $el->getAttribute('name')),
        iterator_to_array($xp->query('//form//input[@name] | //form//select[@name] | //form//textarea[@name]')));
    $siteFields = array_values(array_unique(array_filter($formNames, fn($n) => str_starts_with($n, 'share_sites['))));
    sort($siteFields);
    check('поля записи сайта в форме — только номер и site_meta_robots',
        $siteFields === ['share_sites[site_id]', 'share_sites[site_meta_robots]'], json_encode($siteFields));
    check('вкладка свойств сайта', str_contains($form, "$id/properties/"));
    [$code, $props] = http($single . "$id/properties/");
    check('свойства сайта открываются — 200', $code == 200, "HTTP $code");

    // название: сохранённое видно посетителю в шапке главной
    $ru = array_key_first($names);
    $newName = 'Claude тест настроек ' . bin2hex(random_bytes(3));
    [$code, $body] = http($single . 'save/', encode(with($pairs, "share_sites_translation[$ru][site_name]", $newName)), ['X-Request: JSON']);
    $j = json_decode((string)$body, true);
    check('сохранение названия — result', $code == 200 && !empty($j['result']), "HTTP $code " . substr((string)$body, 0, 200));
    [, $home] = http("$B/");
    check('новое название — в шапке главной', str_contains($home, htmlspecialchars($newName)));

    // NOINDEX сайта закрывает robots.txt и google-sitemap. /robots.txt на этом хостинге — статический файл ISPConfig
    // в web/ (User-agent: *), страница robots.txt сайта за ним не видна: её ответ берётся по адресу с языком
    $robotsUrl = "$B/ua/robots.txt";
    [, $robots] = http($robotsUrl);
    check('до NOINDEX robots.txt открыт (Allow: /)', str_contains($robots, 'Allow: /'), json_encode(substr($robots, 0, 200), JSON_UNESCAPED_UNICODE));
    $robotsField = $xp->query("//form//*[@name='share_sites[site_meta_robots][]']")->length ? ['NOINDEX'] : 'NOINDEX';
    [$code, $body] = http($single . 'save/', encode(with(with($pairs, "share_sites_translation[$ru][site_name]", $names[$ru]),
        'share_sites[site_meta_robots]', $robotsField)), ['X-Request: JSON']);
    $j = json_decode((string)$body, true);
    check('сохранение NOINDEX — result', $code == 200 && !empty($j['result']), "HTTP $code " . substr((string)$body, 0, 200));
    [, $robots] = http($robotsUrl);
    check('NOINDEX: robots.txt — Disallow: /', str_contains($robots, 'Disallow: /'), substr($robots, 0, 80));
    [$code] = http("$B/google-sitemap/");
    check('NOINDEX: google-sitemap — 404', $code == 404, "HTTP $code");

    // без токена — отказ 422, запись та же
    $restore();
    $noToken = array_values(array_filter(with($pairs, "share_sites_translation[$ru][site_name]", 'Claude без токена'),
        fn($p) => $p[0] !== 'csrf_token'));
    [$code] = http($single . 'save/', encode($noToken), ['X-Request: JSON']);
    $now = $pdo->query("SELECT site_name FROM share_sites_translation WHERE lang_id = $ru")->fetchColumn();
    check('сохранение без токена — 422, название то же', $code == 422 && $now === $names[$ru], "HTTP $code, «{$now}»");

} finally {
    $restore();
    @unlink($jar);
}
echo "== site-settings failures: $fail\n";
exit($fail ? 1 : 0);
