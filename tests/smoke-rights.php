<?php
// Права без сайтов: группа с правом правки раздела новостей (не администраторы) видит все новости в редакторе;
// форма группы — без строки с названием сайта, её сохранение не меняет права группы.
// Временные группа и пользователь создаются здесь и удаляются в конце, в том числе после провала.
$E = require __DIR__ . '/env.php';
$B = $E['BASE'];
$fail = 0;
function check($label, $ok, $detail = '') {
    global $fail;
    echo ($ok ? 'OK   ' : 'FAIL '), $label, ($ok || $detail === '' ? '' : ": $detail"), "\n";
    if (!$ok) $fail++;
}
function http($jar, $url, $post = null, $headers = []) {
    global $B;
    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEJAR => $jar, CURLOPT_COOKIEFILE => $jar,
        CURLOPT_HTTPHEADER => $headers, CURLOPT_REFERER => $B . '/login/']);
    if ($post !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $post);
    }
    $body = curl_exec($ch);
    return [curl_getinfo($ch, CURLINFO_HTTP_CODE), (string)$body];
}
function token($html) {
    return preg_match('~<meta name="csrf-token" content="([^"]*)"~', $html, $m) ? $m[1] : '';
}
function login($jar, $email, $password) {
    global $B;
    [, $page] = http($jar, "$B/login/");
    http($jar, "$B/auth.php", http_build_query(['csrf_token' => token($page),
        'user' => ['login' => 1, 'username' => $email, 'password' => $password]]));
}
// строки новостей первой страницы редактора новостей
function newsRows($jar) {
    global $B;
    [$code, $page] = http($jar, "$B/admin/news-editor/");
    [, $body] = http($jar, "$B/admin/news-editor/single/newsRepo/get-data/page-1", '',
        ['X-Request: JSON', 'X-CSRF-Token: ' . token($page)]);
    $j = json_decode($body, true);
    return [$code, is_array($j) && !empty($j['result']) ? count($j['data'] ?? []) : -1];
}
// поля формы, как их отправляет браузер (как в smoke-roundtrip.php)
function formFields($html) {
    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $html);
    libxml_clear_errors();
    $xp = new DOMXPath($doc);
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
            $sel = $xp->query('.//option[@selected]', $el);
            if (!$sel->length && !$el->hasAttribute('multiple')) $sel = $xp->query('.//option[1]', $el);
            foreach ($sel as $opt) $pairs[] = [$name, $opt->getAttribute('value')];
        } else {
            $pairs[] = [$name, $el->textContent];
        }
    }
    return [$pairs, $xp];
}

$pdo = new PDO("mysql:host={$E['DB_HOST']};dbname={$E['DB_NAME']};charset=utf8", $E['DB_USER'], $E['MYSQL_PWD'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
$q = fn($sql, $args = []) => tap($pdo->prepare($sql), fn($st) => $st->execute($args));
function tap($v, $f) { $f($v); return $v; }
$mark = 'claude-rights-' . bin2hex(random_bytes(3));
$email = "$mark@example.org";
$password = bin2hex(random_bytes(12));
$adminJar = tempnam(sys_get_temp_dir(), 'rights');
$userJar = tempnam(sys_get_temp_dir(), 'rights');
$gid = $uid = null;
try {
    // страницы: корень, админка, редактор новостей
    $root = (int)$pdo->query('SELECT smap_id FROM share_sitemap WHERE smap_pid IS NULL')->fetchColumn();
    $admin = (int)$pdo->query("SELECT smap_id FROM share_sitemap WHERE smap_pid = $root AND smap_segment = 'admin'")->fetchColumn();
    $news = (int)$pdo->query("SELECT smap_id FROM share_sitemap WHERE smap_pid = $admin AND smap_segment = 'news-editor'")->fetchColumn();
    check('страницы админки и редактора новостей найдены', $root && $admin && $news, "$root $admin $news");

    // временная группа: чтение корня и админки, правка раздела новостей; пользователь в ней
    $q('INSERT INTO user_groups (group_name) VALUES (?)', [$mark]);
    $gid = (int)$pdo->lastInsertId();
    foreach ([$root => 1, $admin => 1, $news => 2] as $smap => $right) {
        $q('INSERT INTO share_access_level (smap_id, group_id, right_id) VALUES (?, ?, ?)', [$smap, $gid, $right]);
    }
    $q('INSERT INTO user_users (u_name, u_password, u_fullname, u_is_active) VALUES (?, ?, ?, 1)',
        [$email, password_hash($password, PASSWORD_DEFAULT), 'Claude rights']);
    $uid = (int)$pdo->lastInsertId();
    $q('INSERT INTO user_user_groups (u_id, group_id) VALUES (?, ?)', [$uid, $gid]);

    login($adminJar, $E['ADMIN_EMAIL'], $E['ADMIN_PASSWORD']);
    [, $adminRows] = newsRows($adminJar);
    check('администратор видит новости', $adminRows > 0, "$adminRows строк");
    login($userJar, $email, $password);
    [$code, $userRows] = newsRows($userJar);
    check('группа с правом правки раздела новостей видит все новости', $code == 200 && $userRows === $adminRows,
        "HTTP $code, строк $userRows, у администратора $adminRows");

    // форма группы: заголовок таблицы прав — «Все разделы», не название сайта; сохранение не меняет права
    $rights = fn() => $pdo->query("SELECT CONCAT(smap_id, ':', right_id) FROM share_access_level WHERE group_id = $gid ORDER BY 1")
        ->fetchAll(PDO::FETCH_COLUMN);
    $before = $rights();
    $single = "$B/admin/users/roles/single/roleEditor/";
    [$code, $form] = http($adminJar, $single . "$gid/edit/");
    [$pairs, $xp] = formFields($form);
    $heads = array_map(fn($td) => trim($td->textContent), iterator_to_array($xp->query('//tr[contains(@class, "section_name")]/td[1]')));
    $siteName = (string)$pdo->query('SELECT site_name FROM share_sites_translation WHERE lang_id = 1')->fetchColumn();
    check('форма группы: заголовок таблицы прав — «Все разделы»', $code == 200 && $heads === ['Все разделы'],
        "HTTP $code, заголовки " . json_encode($heads, JSON_UNESCAPED_UNICODE) . ", сайт «{$siteName}»");
    [$code, $body] = http($adminJar, $single . 'save/', implode('&', array_map(fn($p) => rawurlencode($p[0]) . '=' . rawurlencode($p[1]), $pairs)),
        ['X-Request: JSON']);
    $j = json_decode($body, true);
    check('форма группы сохраняется', $code == 200 && !empty($j['result']), "HTTP $code " . substr($body, 0, 200));
    check('права группы после сохранения те же', $rights() === $before, implode(' ', $rights()) . ' / ' . implode(' ', $before));
} finally {
    if ($uid) {
        $q('DELETE FROM share_session WHERE u_id = ?', [$uid]);
        $q('DELETE FROM user_users WHERE u_id = ?', [$uid]);
    }
    if ($gid) {
        $q('DELETE FROM share_access_level WHERE group_id = ?', [$gid]);
        $q('DELETE FROM user_groups WHERE group_id = ?', [$gid]);
    }
    @unlink($adminJar);
    @unlink($userJar);
}
echo "== rights failures: $fail\n";
exit($fail ? 1 : 0);
